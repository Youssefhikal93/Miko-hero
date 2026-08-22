import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/illustrations/illustration_service.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

/// Exposes the picture run a parent started, or null when none is open.
final illustrateStoryControllerProvider =
    NotifierProvider<IllustrateStoryController, IllustrateStoryRun?>(
      IllustrateStoryController.new,
    );

/// One picture run exactly as the waiting dialog needs to see it.
///
/// Deliberately three states in one value — running, finished, failed — so a
/// dialog can never render a combination the run is not actually in.
class IllustrateStoryRun {
  /// Creates one immutable snapshot of a picture run.
  const IllustrateStoryRun({
    required this.storyId,
    this.progress,
    this.outcome,
    this.failure,
    this.isCancelling = false,
  });

  /// Local identity of the story whose pictures are being made.
  final String storyId;

  /// Latest stage the PC reported, absent until the first one arrives.
  final IllustrationProgress? progress;

  /// Report of the finished run, absent while it is still going.
  final IllustrationOutcome? outcome;

  /// Failure that ended the run, absent unless the PC could not be used.
  final Object? failure;

  /// Whether the parent asked to stop and the PC has not answered yet.
  final bool isCancelling;

  /// Whether the PC is still working on this run.
  bool get isRunning => outcome == null && failure == null;

  /// Returns the run with a newly reported stage.
  IllustrateStoryRun withProgress(IllustrationProgress reported) {
    return IllustrateStoryRun(
      storyId: storyId,
      progress: reported,
      isCancelling: isCancelling,
    );
  }

  /// Returns the run with the parent's stop request recorded.
  IllustrateStoryRun cancelling() {
    return IllustrateStoryRun(
      storyId: storyId,
      progress: progress,
      isCancelling: true,
    );
  }
}

/// Owns the one picture run this device may have going at a time.
///
/// Nothing here is persisted: a run describes what the PC is doing right now,
/// and everything it produces is written by the image cache and the master
/// library instead. Restarting the app therefore loses no artwork — the pages
/// the PC finished are still on the PC, and the next run or sync fetches them.
class IllustrateStoryController extends Notifier<IllustrateStoryRun?> {
  IllustrationService? _service;

  @override
  /// Starts every session with no picture run open.
  IllustrateStoryRun? build() => null;

  /// Uploads the photo, asks the PC to draw, and caches the finished pages.
  ///
  /// A second call while a run is open is ignored rather than queueing another:
  /// the PC draws one job at a time, and two runs on one story would only make
  /// it repeat work it has already skipped.
  Future<void> illustrate(StoryBook story) async {
    final current = state;
    if (current != null && current.isRunning) return;
    state = IllustrateStoryRun(storyId: story.id);
    try {
      final connection = await ref.read(aiConnectionControllerProvider.future);
      final appState = await ref.read(appControllerProvider.future);
      final service = IllustrationService(
        client: bridgeClientFor(connection, ref.read(bridgeHttpClientProvider)),
        store: ref.read(illustrationStoreProvider),
        currentTime: ref.read(illustrationClockProvider),
        pollInterval: ref.read(illustrationPollIntervalProvider),
        onProgress: (progress) => _report(story.id, progress),
      );
      _service = service;
      final outcome = await service.illustrate(
        story: story,
        profile: appState.profileById(story.content.request.profileId),
      );
      invalidateCachedIllustrations(ref, outcome.savedIllustrationIds);
      state = IllustrateStoryRun(storyId: story.id, outcome: outcome);
    } on Exception catch (error) {
      state = IllustrateStoryRun(storyId: story.id, failure: error);
    } finally {
      _service = null;
    }
  }

  /// Asks the PC to stop drawing the run that is open.
  ///
  /// The waiting poll then sees `cancelled` and the pages already drawn are
  /// still fetched, so stopping costs the family only the unfinished pictures.
  Future<void> cancel() async {
    final current = state;
    final service = _service;
    if (current == null || !current.isRunning || service == null) return;
    state = current.cancelling();
    try {
      await service.cancelActiveRun();
    } on Exception {
      // A PC that refused the stop keeps drawing; the poll reports what
      // actually happened, so nothing here should claim it stopped.
    }
  }

  /// Clears a finished run once the parent closed its dialog.
  void dismiss() {
    if (state?.isRunning ?? false) return;
    state = null;
  }

  /// Publishes one stage, ignoring a report from a run already replaced.
  void _report(String storyId, IllustrationProgress progress) {
    final current = state;
    if (current == null || current.storyId != storyId) return;
    if (!current.isRunning) return;
    state = current.withProgress(progress);
  }
}
