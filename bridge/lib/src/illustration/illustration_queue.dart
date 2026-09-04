import 'dart:async';

import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_errors.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_job.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_renderer.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:uuid/uuid.dart';

/// Runs illustration jobs strictly one at a time, and never while a story is
/// being written.
///
/// It stands in the same line as the story queue — [JobQueue] gives both of
/// them FIFO admission, positions, cancellation and a single worker — and
/// differs in the two ways that come from what it renders. It takes a turn at
/// the [GpuGate] for each individual page rather than for a whole job, so a
/// story that was queued behind a ten-page book waits for one page instead of
/// ten; and a page that fails does not fail the book, it just marks its own
/// row `failed` and lets the remaining pages carry on. What has to be freed
/// between turns is the gate's decision, not this queue's.
///
/// A job with a reference photo runs one extra render before its first page:
/// the photo is redrawn as a storybook portrait, and that portrait — never the
/// photo — is what the pages use as their face reference. It takes a turn of
/// its own, on the same terms as a page.
class IllustrationQueue
    extends JobQueue<IllustrationJob, IllustrationRenderPlan> {
  /// Creates a queue.
  ///
  /// [client] is the ComfyUI seam replaced by tests, [gate] is the shared
  /// one-GPU lock (pass the same instance as the story queue), and [log]
  /// receives content-free progress lines.
  factory IllustrationQueue({
    required BridgeConfig config,
    required MasterLibrary library,
    ComfyUiClient client = const IoComfyUiClient(),
    GpuGate? gate,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
    JobLogSink? log,
    Duration? pollInterval,
  }) {
    // The queue and its renderer read and write the same rows, so they share
    // one repository rather than each building an equivalent copy.
    final repository = IllustrationRepository(library: library);
    return IllustrationQueue._(
      repository: repository,
      renderer: IllustrationRenderer(
        config: config,
        library: library,
        client: client,
        repository: repository,
        photoStore: ProfilePhotoStore(library: library),
        clock: clock,
        pollInterval: pollInterval,
      ),
      gate: gate ?? GpuGate(),
      uuid: uuid,
      clock: clock,
      log: log,
    );
  }

  IllustrationQueue._({
    required this._repository,
    required this._renderer,
    required this._gate,
    required this._uuid,
    super.clock,
    super.log,
  }) : super(
         jobLabel: 'illustration job',
         unknownJobMessage: 'Unknown illustration job.',
       );

  final IllustrationRepository _repository;
  final IllustrationRenderer _renderer;
  final GpuGate _gate;
  final Uuid _uuid;

  /// This queue's identity at the gate.
  ///
  /// One constant for every instance: there is one ComfyUI process, and the
  /// gate compares tenants by identity to tell a handover from another turn
  /// of the same tenant.
  static const GpuTenant _tenant = _ComfyUiTenant();

  /// Queues every page of [storyId] that still needs an image.
  ///
  /// Returns `null` when no such story exists, so the caller can answer a
  /// typed `404`. Pages that are already `completed` are skipped, which is
  /// what makes a second call after a partial failure cheap. A story whose
  /// pages are all done still produces a job — one that finishes
  /// immediately with a page count of zero.
  IllustrationJob? enqueue({
    required String deviceId,
    required String storyId,
    required StoryIllustrationStyle style,
    required StoryGenderContext? gender,
  }) {
    final targets = _repository.readTargets(storyId);
    if (targets == null) {
      return null;
    }
    final now = nowUtc();
    final job = IllustrationJob(
      id: _uuid.v4(),
      deviceId: deviceId,
      storyId: storyId,
      pageCount: targets.pending.length,
      status: IllustrationJobStatus.queued,
      createdAtUtc: now,
      updatedAtUtc: now,
      progress: targets.pending.isEmpty
          ? 'Every page already has a picture.'
          : 'Waiting for the local renderer.',
    );
    return admit(
      job,
      IllustrationRenderPlan(targets: targets, style: style, gender: gender),
      logFields: <String>['pages=${job.pageCount}'],
    );
  }

  @override
  IllustrationJob markCancelled(IllustrationJob current) {
    // The running job stops after the page it is currently rendering:
    // interrupting mid-image would waste the minute already spent on it and
    // leave ComfyUI holding the card.
    return current.copyWith(
      status: IllustrationJobStatus.cancelled,
      updatedAtUtc: nowUtc(),
      progress: 'Cancelled.',
    );
  }

  /// Renders the book one page at a time, one GPU lease per page.
  ///
  /// Nothing here fails the whole job except a renderer that is unusable
  /// before any page was attempted, or a book where every single page failed:
  /// a page that fails marks its own row and the rest carry on.
  @override
  Future<void> runJob(
    IllustrationJob job,
    IllustrationRenderPlan plan,
    CancellationToken token,
  ) async {
    final jobId = job.id;
    final start = nowUtc();
    final pages = plan.targets.pending;

    if (token.isCancelled) {
      _settleCancelled(jobId, start);
      return;
    }
    if (pages.isEmpty) {
      _finish(jobId, start, progress: 'Every page already has a picture.');
      return;
    }
    if (!await _renderer.isComfyUiReachable()) {
      // Not one page's fault: leave every row exactly as it was so the next
      // attempt still sees them as work to do rather than as failures.
      _fail(
        jobId,
        const IllustrationFailure(
          code: IllustrationFailureCode.comfyUiUnavailable,
          message: 'The local ComfyUI server could not be reached.',
        ),
        start,
      );
      return;
    }
    if (!await _renderer.isFaceDetailAvailable()) {
      // Same reasoning as an unreachable renderer, and the same treatment:
      // the configuration is wrong, not the pages, so no row is touched and
      // the parent gets one error naming what to install or turn off.
      _fail(
        jobId,
        const IllustrationFailure(
          code: IllustrationFailureCode.missingCustomNode,
          message:
              'Face detailing is switched on, but this ComfyUI does not have '
              'the Impact Pack nodes it needs. Install ComfyUI-Impact-Pack '
              'and its face detector model, or set '
              '"illustration.faceDetail.enabled" to false.',
        ),
        start,
      );
      return;
    }

    final ReferencePhotoUpload? photo = await _renderer.uploadReferencePhoto(
      plan.targets.profileId,
    );
    String? referenceImageName;
    if (photo != null) {
      if (token.isCancelled) {
        _settleCancelled(jobId, start);
        return;
      }
      // Stage one, once per job: redraw the photo as a storybook portrait so
      // the face adapter reads a drawing rather than a photograph. It is a
      // full render on the same card, so it takes the same turn at the gate a
      // page takes — a story must never be generated alongside it.
      _transition(
        jobId,
        status: IllustrationJobStatus.rendering,
        // Named for what the parent sees, not for the pass: the wait is real
        // and reporting "waiting for the renderer" through it would be a lie.
        progress: 'Drawing the hero.',
      );
      referenceImageName = await _gate.run(_tenant, () {
        return _renderer.renderStylizedReference(
          storyId: plan.targets.storyId,
          profileId: plan.targets.profileId,
          photo: photo,
          style: plan.style,
          gender: plan.gender,
        );
      });
    }
    logJob(
      jobId,
      'rendering pages=${pages.length} '
      'photo=${photo == null ? 'no' : 'yes'} '
      'reference=${referenceImageName == null ? 'no' : 'stylized'}',
    );

    var completed = 0;
    var failed = 0;
    for (var index = 0; index < pages.length; index++) {
      if (token.isCancelled) {
        _settleCancelled(jobId, start, completed: completed, failed: failed);
        return;
      }
      final target = pages[index];
      _transition(
        jobId,
        status: IllustrationJobStatus.rendering,
        progress: 'Rendering page ${index + 1} of ${pages.length}.',
        completedPageCount: completed,
        failedPageCount: failed,
      );
      // One turn per page: the story queue may slip in between pages, but
      // never alongside one.
      await _gate.run(_tenant, () async {
        try {
          await _renderer.renderPage(
            target: target,
            storyId: plan.targets.storyId,
            style: plan.style,
            gender: plan.gender,
            referenceImageName: referenceImageName,
          );
          completed++;
          logJob(jobId, 'page=${target.pageIndex} rendered');
        } on IllustrationException catch (error) {
          failed++;
          _markFailed(jobId, plan.targets.storyId, target.illustrationId);
          logJob(
            jobId,
            'page=${target.pageIndex} error=${error.code.wireCode}',
          );
        } catch (_) {
          failed++;
          _markFailed(jobId, plan.targets.storyId, target.illustrationId);
          // Details are dropped on purpose: they can quote scene text.
          logJob(
            jobId,
            'page=${target.pageIndex} '
            'error=${IllustrationFailureCode.internalError.wireCode}',
          );
        }
      });
    }

    if (token.isCancelled) {
      _settleCancelled(jobId, start, completed: completed, failed: failed);
      return;
    }
    if (completed == 0) {
      _fail(
        jobId,
        const IllustrationFailure(
          code: IllustrationFailureCode.comfyUiFailed,
          message: 'No page of this story could be illustrated.',
        ),
        start,
        completed: completed,
        failed: failed,
      );
      return;
    }
    _finish(
      jobId,
      start,
      progress: failed == 0
          ? 'All $completed pages illustrated.'
          : '$completed of ${pages.length} pages illustrated.',
      completed: completed,
      failed: failed,
    );
  }

  void _markFailed(String jobId, String storyId, String illustrationId) {
    try {
      _repository.markStatus(
        illustrationId: illustrationId,
        storyId: storyId,
        status: failedIllustrationStatus,
        nowUtc: nowUtc(),
      );
    } on Exception catch (_) {
      // The page already failed; a bookkeeping failure on top of it must not
      // take the remaining pages down with it.
      logJob(jobId, 'status write failed');
    }
  }

  void _transition(
    String jobId, {
    required IllustrationJobStatus status,
    required String progress,
    int? completedPageCount,
    int? failedPageCount,
  }) {
    updateJob(
      jobId,
      (current) => current.copyWith(
        status: status,
        progress: progress,
        updatedAtUtc: nowUtc(),
        completedPageCount: completedPageCount,
        failedPageCount: failedPageCount,
      ),
    );
  }

  void _finish(
    String jobId,
    DateTime start, {
    required String progress,
    int completed = 0,
    int failed = 0,
  }) {
    final current = requireJob(jobId);
    if (current.isTerminal) {
      // Cancelled while this worker was between awaits. Cancellation is the
      // decision the parent made; it must not be overwritten by an outcome.
      _settleCancelled(jobId, start, completed: completed, failed: failed);
      return;
    }
    storeJob(
      current.copyWith(
        status: IllustrationJobStatus.completed,
        progress: progress,
        updatedAtUtc: nowUtc(),
        completedPageCount: completed,
        failedPageCount: failed,
      ),
    );
    logJob(
      jobId,
      'completed pages=$completed failed=$failed in ${elapsedMs(start)} ms',
    );
    settleIfTerminal(jobId);
  }

  void _fail(
    String jobId,
    IllustrationFailure failure,
    DateTime start, {
    int completed = 0,
    int failed = 0,
  }) {
    final current = requireJob(jobId);
    if (current.isTerminal) {
      _settleCancelled(jobId, start, completed: completed, failed: failed);
      return;
    }
    storeJob(
      current.copyWith(
        status: IllustrationJobStatus.failed,
        progress: 'Illustration failed.',
        updatedAtUtc: nowUtc(),
        completedPageCount: completed,
        failedPageCount: failed,
        failure: failure,
      ),
    );
    logJob(
      jobId,
      'failed code=${failure.code.wireCode} after ${elapsedMs(start)} ms',
    );
    settleIfTerminal(jobId);
  }

  /// Records how far a cancelled job got and settles it.
  ///
  /// The snapshot is already `cancelled` — [JobQueue.cancel] wrote it — but
  /// the counts are the worker's, and they are what tell the parent how many
  /// pages of the book were drawn before it stopped.
  void _settleCancelled(
    String jobId,
    DateTime start, {
    int completed = 0,
    int failed = 0,
  }) {
    storeJob(
      requireJob(
        jobId,
      ).copyWith(completedPageCount: completed, failedPageCount: failed),
    );
    logJob(jobId, 'stopped pages=$completed after ${elapsedMs(start)} ms');
    settleIfTerminal(jobId);
  }
}

/// The renderer's claim on the GPU, as the gate sees it.
///
/// Eviction does nothing, deliberately. ComfyUI keeps its checkpoint resident
/// between renders, and the bridge has no way to ask it to let go that can be
/// verified on this machine — so the card behaves exactly as it did before the
/// gate learned to evict, and nothing has been quietly changed on a guess.
///
/// This is the one place that changes when the bridge does learn to free it:
/// a free call belongs in [evict], not in the queue's page loop, so that the
/// gate keeps deciding *when* — after the last page, never between two of
/// them.
class _ComfyUiTenant implements GpuTenant {
  const _ComfyUiTenant();

  @override
  String get name => 'comfyui';

  @override
  Future<void> evict() async {
    // Nothing to free yet; see the class doc for why that is on purpose.
  }
}

/// Everything one queued illustration job needs, kept out of its snapshot.
///
/// The queue holds this beside the job and hands it to the worker; the scene
/// descriptions in here are story content and must never be serialized into
/// a job status response.
class IllustrationRenderPlan {
  /// Creates a plan for one job.
  const IllustrationRenderPlan({
    required this.targets,
    required this.style,
    required this.gender,
  });

  /// The story and the pages of it that still need an image.
  final StoryIllustrationTargets targets;

  /// Look the whole book is drawn in.
  final StoryIllustrationStyle style;

  /// How the hero is described, when the parent said.
  final StoryGenderContext? gender;
}
