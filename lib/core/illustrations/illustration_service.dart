import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_downloader.dart';
import 'package:miko_hero/core/illustrations/illustration_store.dart';
import 'package:miko_hero/core/illustrations/reference_photo.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// How often one illustration job is polled while the PC draws pages.
const defaultIllustrationPollInterval = Duration(seconds: 3);

/// Longest the app waits for one whole illustration job.
///
/// One page takes minutes on a home GPU, so a ten-page book is a long wait by
/// design; the bound exists only so a PC that stops answering cannot leave a
/// dialog running forever.
const defaultIllustrationJobTimeout = Duration(minutes: 45);

/// Stage of the picture run a waiting parent is looking at.
enum IllustrationStage {
  /// The child's reference photo is on its way to the PC.
  sendingPhoto,

  /// The request to draw the pages is being sent.
  submitting,

  /// Accepted and waiting for the PC's renderer to pick it up.
  queued,

  /// The PC is drawing pages right now.
  drawing,

  /// Finished pages are being copied onto this device.
  downloading,
}

/// One progress snapshot of a picture run, carrying counts and never prose.
class IllustrationProgress {
  /// Creates one stage snapshot with the counts the PC last reported.
  const IllustrationProgress(
    this.stage, {
    this.pageCount = 0,
    this.completedPageCount = 0,
    this.failedPageCount = 0,
    this.queuePosition,
  });

  /// What the run is doing right now.
  final IllustrationStage stage;

  /// Pages this run set out to draw, zero before the PC has said.
  final int pageCount;

  /// Pages whose picture already exists on the PC.
  final int completedPageCount;

  /// Pages the PC tried and could not draw.
  final int failedPageCount;

  /// Place in line, present only while the job is still queued.
  final int? queuePosition;
}

/// Everything one finished picture run produced.
class IllustrationOutcome {
  /// Creates the report one completed, failed, or cancelled run leaves behind.
  const IllustrationOutcome({
    required this.status,
    required this.pageCount,
    required this.completedPageCount,
    required this.failedPageCount,
    required this.savedIllustrationIds,
    required this.fetchFailureCount,
    required this.photoSkipped,
  });

  /// State the PC's job ended in.
  final BridgeIllustrationJobStatus status;

  /// Pages this run set out to draw.
  final int pageCount;

  /// Pages whose picture exists on the PC now.
  final int completedPageCount;

  /// Pages the PC tried and could not draw.
  final int failedPageCount;

  /// Identities whose bytes were newly written into the local cache.
  final List<String> savedIllustrationIds;

  /// Finished pictures that could not be copied onto this device.
  final int fetchFailureCount;

  /// Whether the child's photo was left out, so faces are not their own.
  final bool photoSkipped;

  /// Whether every page of the book now has a picture on the PC.
  bool get drewEveryPage =>
      status == BridgeIllustrationJobStatus.completed && failedPageCount == 0;

  /// Whether the run produced no picture at all.
  bool get drewNothing => completedPageCount == 0;

  /// Whether there was nothing left to draw: every page already had its
  /// picture on the PC before this run, so ending with zero new pages is a
  /// success, not a failure.
  bool get wasAlreadyDone =>
      status == BridgeIllustrationJobStatus.completed && pageCount == 0;
}

/// Draws one bridge story's page images on the paired family PC.
///
/// The run is deliberately forgiving about everything except the PC itself: a
/// photo that cannot be used is skipped, a page the PC fails on is reported and
/// the rest are still fetched, and cancelling keeps the pictures that were
/// already finished. Only an unreachable, refusing, or silent PC throws.
class IllustrationService {
  /// Creates a run bound to one paired client and this device's image cache.
  IllustrationService({
    required this.client,
    required this.store,
    required this.currentTime,
    this.onProgress,
    this.pollInterval = defaultIllustrationPollInterval,
    this.jobTimeout = defaultIllustrationJobTimeout,
  });

  /// Typed HTTP boundary to the PC bridge.
  final BridgeClient client;

  /// Local per-illustration image cache the finished pages land in.
  final IllustrationStore store;

  /// Clock the job timeout is measured against.
  final DateTime Function() currentTime;

  /// Optional sink for waiting-dialog progress; never carries story text.
  final void Function(IllustrationProgress progress)? onProgress;

  /// Delay between two polls of the same job.
  final Duration pollInterval;

  /// Bound on the complete wait for one job.
  final Duration jobTimeout;

  String? _activeJobId;

  /// Uploads the photo, queues the drawing, waits for it, and fetches pages.
  Future<IllustrationOutcome> illustrate({
    required StoryBook story,
    required ChildProfile? profile,
  }) async {
    final storyId = BridgeStoryProvenance.storyIdOf(story);
    if (storyId == null) {
      throw ArgumentError.value(story.id, 'story', 'Not a PC library story.');
    }
    final photoSkipped = await _sendReferencePhoto(profile);
    _report(const IllustrationProgress(IllustrationStage.submitting));
    final request = story.content.request;
    final submission = await client.illustrateStory(
      storyId,
      illustrationStyle: request.presentation.style.name,
      genderContext: request.gender.isSpecified ? request.gender.name : null,
    );
    _activeJobId = submission.jobId;
    try {
      _report(
        IllustrationProgress(
          IllustrationStage.queued,
          pageCount: submission.pageCount,
          queuePosition: submission.queuePosition,
        ),
      );
      final job = await _awaitTerminalJob(submission.jobId);
      _report(
        IllustrationProgress(
          IllustrationStage.downloading,
          pageCount: job.pageCount,
          completedPageCount: job.completedPageCount,
          failedPageCount: job.failedPageCount,
        ),
      );
      final fetched = await IllustrationDownloader(
        client: client,
        store: store,
      ).download(BridgeStoryProvenance.illustrationIdsOf(story));
      return IllustrationOutcome(
        status: job.status,
        pageCount: job.pageCount,
        completedPageCount: job.completedPageCount,
        failedPageCount: job.failedPageCount,
        savedIllustrationIds: fetched.savedIllustrationIds,
        fetchFailureCount: fetched.failureCount,
        photoSkipped: photoSkipped,
      );
    } finally {
      _activeJobId = null;
    }
  }

  /// Tells the PC to stop drawing the job this run is waiting on.
  ///
  /// The waiting poll then observes `cancelled`, and the pages that were
  /// already drawn are still downloaded, so stopping never throws work away.
  Future<void> cancelActiveRun() async {
    final jobId = _activeJobId;
    if (jobId == null) return;
    await client.cancelIllustrationJob(jobId);
  }

  /// Sends the child's photo and reports whether it had to be left out.
  Future<bool> _sendReferencePhoto(ChildProfile? profile) async {
    if (profile == null) return false;
    final photo = readReferencePhoto(profile.photoBase64);
    if (photo == null) return profile.photoBase64.isNotEmpty;
    _report(const IllustrationProgress(IllustrationStage.sendingPhoto));
    try {
      await client.uploadProfilePhoto(
        profileId: profile.id,
        bytes: photo.bytes,
        contentType: photo.contentType,
      );
      return false;
    } on Exception {
      // Face likeness is a bonus, not the point: the book still gets drawn.
      return true;
    }
  }

  /// Polls one job until it stops running or the bound elapses.
  Future<BridgeIllustrationJob> _awaitTerminalJob(String jobId) async {
    final deadline = currentTime().add(jobTimeout);
    while (true) {
      await Future<void>.delayed(pollInterval);
      final job = await client.readIllustrationJob(jobId);
      _reportJob(job);
      if (!job.isRunning) return job;
      if (currentTime().isAfter(deadline)) {
        throw const BridgeException(BridgeFailure.timedOut);
      }
    }
  }

  /// Translates one polled job into the stage the waiting dialog shows.
  void _reportJob(BridgeIllustrationJob job) {
    switch (job.status) {
      case BridgeIllustrationJobStatus.queued:
        _report(
          IllustrationProgress(
            IllustrationStage.queued,
            pageCount: job.pageCount,
            completedPageCount: job.completedPageCount,
            failedPageCount: job.failedPageCount,
            queuePosition: job.queuePosition,
          ),
        );
      case BridgeIllustrationJobStatus.rendering:
        _report(
          IllustrationProgress(
            IllustrationStage.drawing,
            pageCount: job.pageCount,
            completedPageCount: job.completedPageCount,
            failedPageCount: job.failedPageCount,
          ),
        );
      case BridgeIllustrationJobStatus.completed:
      case BridgeIllustrationJobStatus.failed:
      case BridgeIllustrationJobStatus.cancelled:
        break;
    }
  }

  /// Publishes one progress snapshot when a listener asked for them.
  void _report(IllustrationProgress progress) => onProgress?.call(progress);
}
