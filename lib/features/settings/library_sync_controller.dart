import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/ai_connection/bridge_sync_models.dart';
import 'package:miko_hero/core/ai_connection/library_sync.dart';
import 'package:miko_hero/core/ai_connection/library_sync_state.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';

/// Exposes synchronization state and the two kinds of story deletion.
final librarySyncControllerProvider =
    AsyncNotifierProvider<LibrarySyncController, LibrarySyncSnapshot>(
      LibrarySyncController.new,
    );

/// The stored synchronization record plus what the last run reported.
///
/// The record is persisted; the result and the failure are not, because they
/// describe one run rather than what this device holds.
class LibrarySyncSnapshot {
  /// Creates one immutable synchronization snapshot.
  const LibrarySyncSnapshot({
    required this.syncState,
    this.lastResult,
    this.lastFailure,
    this.isSyncing = false,
  });

  /// What this device has already taken from the PC master library.
  final LibrarySyncState syncState;

  /// Report of the last completed sync, absent until one completes.
  final LibrarySyncResult? lastResult;

  /// Failure of the last attempt, kept so the card can localize it.
  final Object? lastFailure;

  /// Whether a sync is running right now.
  final bool isSyncing;

  /// Manifest time of the last completed sync, absent until there is one.
  DateTime? get lastSyncedAtUtc => syncState.lastSyncedAtUtc;

  /// Whether the parent removed bridge stories from this device on purpose.
  bool get hasDeclinedStories => syncState.declinedStoryIds.isNotEmpty;

  /// How many bridge stories sync is currently told to leave alone.
  int get declinedStoryCount => syncState.declinedStoryIds.length;

  /// Returns the snapshot with a run in progress and the last failure cleared.
  LibrarySyncSnapshot running() {
    return LibrarySyncSnapshot(
      syncState: syncState,
      lastResult: lastResult,
      isSyncing: true,
    );
  }

  /// Returns the snapshot after one completed run.
  LibrarySyncSnapshot completed(
    LibrarySyncState savedState,
    LibrarySyncResult result,
  ) {
    return LibrarySyncSnapshot(syncState: savedState, lastResult: result);
  }

  /// Returns the snapshot after a run that changed nothing on this device.
  LibrarySyncSnapshot failed(Object failure) {
    return LibrarySyncSnapshot(
      syncState: syncState,
      lastResult: lastResult,
      lastFailure: failure,
    );
  }

  /// Returns the snapshot with a newly persisted synchronization record.
  LibrarySyncSnapshot withSyncState(LibrarySyncState savedState) {
    return LibrarySyncSnapshot(
      syncState: savedState,
      lastResult: lastResult,
      lastFailure: lastFailure,
      isSyncing: isSyncing,
    );
  }
}

/// Owns synchronization with the PC and both parent-gated deletion kinds.
///
/// Every command here is a transaction: the PC is asked first where the PC has
/// to agree, local storage is written next, and only a persisted change is
/// published. A failure therefore leaves the device exactly as it was.
class LibrarySyncController extends AsyncNotifier<LibrarySyncSnapshot> {
  Future<LibrarySyncResult>? _running;
  bool _hasSyncedAfterStart = false;

  @override
  /// Loads the stored synchronization record before any screen renders.
  Future<LibrarySyncSnapshot> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    return LibrarySyncSnapshot(
      syncState: await repository.readLibrarySyncState(),
    );
  }

  /// Runs one synchronization on the parent's explicit request.
  ///
  /// Two callers that overlap share the run in flight instead of asking the PC
  /// for the same manifest twice.
  Future<LibrarySyncResult> syncNow() {
    final running = _running;
    if (running != null) return running;
    final started = _synchronize();
    _running = started;
    started.whenComplete(() {
      if (identical(_running, started)) _running = null;
    }).ignore();
    return started;
  }

  /// Runs the one automatic synchronization that follows an app start.
  ///
  /// Only for a family that chose Local AI and paired this device, and only
  /// once per launch. A failure is recorded for the AI connection card instead
  /// of thrown, because nothing the parent did is waiting on it.
  Future<void> syncAfterAppStart() async {
    if (_hasSyncedAfterStart) return;
    _hasSyncedAfterStart = true;
    final connection = await ref.read(aiConnectionControllerProvider.future);
    if (!connection.usesLocalAi || !connection.isPaired) return;
    try {
      await syncNow();
    } on Exception {
      // Already recorded in the snapshot; an automatic sync stays silent.
    }
  }

  /// Removes one story's offline copy from this device only.
  ///
  /// The master library keeps it, and no bridge call is made: freeing space on
  /// a tablet is not a family decision. The bridge identity is remembered so
  /// the next sync does not simply download it again.
  Future<void> removeFromThisDevice(String storyId) async {
    final current = await future;
    final story = _requireStory(storyId);
    final bridgeId = BridgeStoryProvenance.storyIdOf(story);
    if (bridgeId == null) throw const UnknownEntityException('bridge story');
    await ref.read(storyControllerProvider).deleteStory(storyId);
    await _forgetCachedIllustrations(story);
    await _saveSyncState(current.syncState.withDeclinedStory(bridgeId));
  }

  /// Deletes one story on the PC and therefore on every paired device.
  ///
  /// Requires the PC: without it the typed bridge failure surfaces and nothing
  /// is removed locally, because a local-only delete would silently disagree
  /// with what the parent asked for. No local tombstone is needed once it
  /// succeeds — the PC's deletion record reaches every device.
  Future<BridgeStoryDeletion> deleteEverywhere(String storyId) async {
    final current = await future;
    final story = _requireStory(storyId);
    final bridgeId = BridgeStoryProvenance.storyIdOf(story);
    if (bridgeId == null) throw const UnknownEntityException('bridge story');
    final connection = await ref.read(aiConnectionControllerProvider.future);
    final client = bridgeClientFor(
      connection,
      ref.read(bridgeHttpClientProvider),
    );
    final deletion = await client.deleteStoryEverywhere(bridgeId);
    await ref.read(storyControllerProvider).deleteStory(storyId);
    await _forgetCachedIllustrations(story);
    await _saveSyncState(current.syncState.withoutStories(<String>{bridgeId}));
    return deletion;
  }

  /// Lets the next sync download the stories this device declined.
  Future<void> allowRemovedStoriesAgain() async {
    final current = await future;
    if (!current.hasDeclinedStories) return;
    await _saveSyncState(current.syncState.withoutDeclinedStories());
  }

  /// Fetches the manifest, downloads what it justifies, and reports back.
  Future<LibrarySyncResult> _synchronize() async {
    final current = await future;
    state = AsyncData(current.running());
    try {
      final appState = await ref.read(appControllerProvider.future);
      final connection = await ref.read(aiConnectionControllerProvider.future);
      final outcome =
          await LibrarySync(
            client: bridgeClientFor(
              connection,
              ref.read(bridgeHttpClientProvider),
            ),
            store: ref.read(illustrationStoreProvider),
          ).synchronize(
            syncState: current.syncState,
            localStories: appState.stories,
            localProfiles: appState.profiles,
          );
      await _applyOutcome(outcome);
      state = AsyncData(current.completed(outcome.syncState, outcome.result));
      return outcome.result;
    } catch (error, stackTrace) {
      state = AsyncData(current.failed(error));
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Persists one synchronization outcome as a single library transaction.
  Future<void> _applyOutcome(LibrarySyncOutcome outcome) async {
    final current = _currentState;
    final removedStoryIds = outcome.removedStoryIds.toSet();
    final savedStories = mergeSyncedLibrary(
      localStories: current.stories,
      downloadedStories: outcome.downloadedStories,
      removedStoryIds: removedStoryIds,
      localProfileIds: current.profiles.map((profile) => profile.id).toSet(),
    );
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveStories(savedStories);
    await repository.saveLibrarySyncState(outcome.syncState);
    ref
        .read(appControllerProvider.notifier)
        .commit(current.withStories(savedStories));
    for (final storyId in outcome.removedStoryIds) {
      await ref.read(profileControllerProvider).forgetFinishedStory(storyId);
    }
    for (final story in current.stories) {
      if (removedStoryIds.contains(story.id)) {
        await _forgetCachedIllustrations(story);
      }
    }
    invalidateCachedIllustrations(ref, outcome.savedIllustrationIds);
  }

  /// Drops one story's cached page images and repaints anything showing them.
  ///
  /// A cache miss is not a failure worth surfacing: the story is already gone
  /// from this device either way, and the leftover file would be replaced or
  /// cleared the next time the family asks for anything.
  Future<void> _forgetCachedIllustrations(StoryBook story) async {
    final illustrationIds = BridgeStoryProvenance.illustrationIdsOf(story);
    if (illustrationIds.isEmpty) return;
    try {
      await ref.read(illustrationStoreProvider).removeForStory(illustrationIds);
    } on Exception {
      // The book is gone regardless, so an unwritable or unavailable cache is
      // not worth failing a deletion the parent already asked for.
    }
    invalidateCachedIllustrations(ref, illustrationIds);
  }

  /// Persists the synchronization record and publishes it once stored.
  Future<void> _saveSyncState(LibrarySyncState savedState) async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveLibrarySyncState(savedState);
    state = AsyncData(state.requireValue.withSyncState(savedState));
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return ref.read(appControllerProvider).requireValue;
  }

  /// Rejects a deletion command for a story another screen already removed.
  StoryBook _requireStory(String storyId) {
    for (final story in _currentState.stories) {
      if (story.id == storyId) return story;
    }
    throw const UnknownEntityException('story');
  }
}
