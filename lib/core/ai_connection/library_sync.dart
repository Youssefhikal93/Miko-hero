import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/ai_connection/bridge_sync_models.dart';
import 'package:miko_hero/core/ai_connection/library_sync_state.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Theme and moral stored for a story whose parent inputs stayed on the PC.
///
/// The master library keeps titles, prose, and scenes but not the parent's
/// original theme and moral, and the story model requires both. A neutral dash
/// records "not known on this device" instead of inventing prose or writing an
/// English sentence into a family's Arabic, Swedish, or Somali library. It
/// never reaches a screen: those two fields appear only while reviewing a
/// draft, and a synced story arrives approved.
const syncedStoryPromptPlaceholder = '—';

/// One child the PC has stories for whom this device holds no profile.
class LibrarySyncPendingProfile {
  /// Creates one pending-profile entry of a sync result.
  const LibrarySyncPendingProfile({
    required this.profileId,
    required this.displayName,
    required this.storyCount,
  });

  /// Master-library profile identity a local profile has to carry.
  final String profileId;

  /// Name the PC has for this child, so the parent knows who is waiting.
  final String displayName;

  /// How many stories are waiting for that profile to exist here.
  final int storyCount;
}

/// What one completed synchronization changed, in parent-facing terms.
class LibrarySyncResult {
  /// Creates the short report the AI connection card shows.
  const LibrarySyncResult({
    required this.syncedAtUtc,
    required this.addedCount,
    required this.updatedCount,
    required this.removedCount,
    this.pendingProfiles = const <LibrarySyncPendingProfile>[],
  });

  /// Manifest generation time this device reported as applied.
  final DateTime syncedAtUtc;

  /// Stories downloaded onto this device for the first time.
  final int addedCount;

  /// Stories already here whose copy on the PC had changed.
  final int updatedCount;

  /// Local copies dropped because the PC recorded them as deleted.
  final int removedCount;

  /// Children whose stories cannot be placed until a profile exists here.
  final List<LibrarySyncPendingProfile> pendingProfiles;

  /// Whether the PC library and this device already agreed on everything.
  bool get changedNothing =>
      addedCount == 0 && updatedCount == 0 && removedCount == 0;
}

/// Everything one synchronization produced, ready to be persisted at once.
///
/// The service itself never writes: a failure anywhere before this value
/// exists leaves the device exactly as it was, which is what makes an
/// interrupted sync safe to simply run again.
class LibrarySyncOutcome {
  /// Creates one all-or-nothing synchronization outcome.
  const LibrarySyncOutcome({
    required this.downloadedStories,
    required this.removedStoryIds,
    required this.syncState,
    required this.result,
  });

  /// Books that were downloaded, each already carrying its local identity.
  final List<StoryBook> downloadedStories;

  /// Local identities to drop because the PC recorded them as deleted.
  final List<String> removedStoryIds;

  /// Synchronization record to persist together with the library.
  final LibrarySyncState syncState;

  /// Short parent-facing report of the same outcome.
  final LibrarySyncResult result;
}

/// Builds the newest-first library that replaces the current one.
///
/// Applied against the library as it is at persistence time, not as it was
/// when the sync started, so a story generated while the PC was answering is
/// never dropped. A downloaded story whose child profile disappeared in the
/// meantime is left out rather than stored as an orphan the next launch would
/// refuse to read.
List<StoryBook> mergeSyncedLibrary({
  required List<StoryBook> localStories,
  required List<StoryBook> downloadedStories,
  required Set<String> removedStoryIds,
  required Set<String> localProfileIds,
}) {
  final downloadedById = <String, StoryBook>{
    for (final story in downloadedStories)
      if (localProfileIds.contains(story.content.request.profileId))
        story.id: story,
  };
  final stories = <StoryBook>[];
  for (final story in localStories) {
    if (removedStoryIds.contains(story.id)) continue;
    stories.add(downloadedById.remove(story.id) ?? story);
  }
  stories.addAll(downloadedById.values);
  stories.sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return List<StoryBook>.unmodifiable(stories);
}

/// Downloads the family's stories from the PC master library onto this device.
///
/// One sync is a manifest, then the downloads that manifest justifies, then
/// the report back to the PC. Nothing is written locally until all three
/// succeed, and stories are matched by their master-library identity, so
/// running a sync twice cannot create a second copy of anything.
class LibrarySync {
  /// Creates a synchronization bound to one configured and paired client.
  const LibrarySync({required this.client});

  /// Typed HTTP boundary to the PC bridge.
  final BridgeClient client;

  /// Applies one manifest to the supplied local library and reports the result.
  Future<LibrarySyncOutcome> synchronize({
    required LibrarySyncState syncState,
    required List<StoryBook> localStories,
    required List<ChildProfile> localProfiles,
  }) async {
    final manifest = await client.readSyncManifest();
    final localByBridgeId = _localStoriesByBridgeId(localStories);
    final deletedIds = manifest.deletedStoryIds;
    final removedStoryIds = <String>[];
    for (final story in localStories) {
      final bridgeId = BridgeStoryProvenance.storyIdOf(story) ?? story.id;
      if (deletedIds.contains(bridgeId)) removedStoryIds.add(story.id);
    }
    var nextState = syncState.withoutStories(deletedIds);

    final downloadedStories = <StoryBook>[];
    var addedCount = 0;
    final pendingCounts = <String, int>{};
    for (final entry in manifest.stories) {
      if (deletedIds.contains(entry.id) || nextState.isDeclined(entry.id)) {
        continue;
      }
      final profile = _profileById(localProfiles, entry.profileId);
      if (profile == null) {
        pendingCounts.update(
          entry.profileId,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        continue;
      }
      final localStory = localByBridgeId[entry.id];
      if (localStory != null && removedStoryIds.contains(localStory.id)) {
        continue;
      }
      if (localStory != null && nextState.versionOf(entry.id) == null) {
        // This device generated the story: the book is already here, prose and
        // all, and it may still be a draft awaiting review on this device.
        // Recording the version adopts it without transferring anything and
        // without overriding a parent decision that has not been made yet.
        nextState = nextState.withStoryVersion(entry.id, entry.updatedAtUtc);
        continue;
      }
      if (localStory != null &&
          nextState.versionOf(entry.id) == entry.updatedAtUtc) {
        continue;
      }
      final download = await client.readSyncStory(entry.id);
      downloadedStories.add(
        _storyBook(
          download: download,
          entry: entry,
          profile: profile,
          localStory: localStory,
        ),
      );
      if (localStory == null) addedCount++;
      nextState = nextState.withStoryVersion(entry.id, entry.updatedAtUtc);
    }

    final reportedMoment = await client.completeSync(
      manifestGeneratedAtUtc: manifest.generatedAtUtc,
    );
    return LibrarySyncOutcome(
      downloadedStories: List<StoryBook>.unmodifiable(downloadedStories),
      removedStoryIds: List<String>.unmodifiable(removedStoryIds),
      syncState: nextState.withLastSyncedAt(reportedMoment),
      result: LibrarySyncResult(
        syncedAtUtc: reportedMoment,
        addedCount: addedCount,
        updatedCount: downloadedStories.length - addedCount,
        removedCount: removedStoryIds.length,
        pendingProfiles: _pendingProfiles(manifest, pendingCounts),
      ),
    );
  }

  /// Indexes the local library by master-library identity where one exists.
  Map<String, StoryBook> _localStoriesByBridgeId(List<StoryBook> stories) {
    final indexed = <String, StoryBook>{};
    for (final story in stories) {
      final bridgeId = BridgeStoryProvenance.storyIdOf(story);
      if (bridgeId != null) indexed[bridgeId] = story;
    }
    return indexed;
  }

  /// Names every child whose stories are waiting for a local profile.
  List<LibrarySyncPendingProfile> _pendingProfiles(
    BridgeSyncManifest manifest,
    Map<String, int> pendingCounts,
  ) {
    final pending = pendingCounts.entries
        .map(
          (entry) => LibrarySyncPendingProfile(
            profileId: entry.key,
            displayName: manifest.displayNameForProfile(entry.key) ?? entry.key,
            storyCount: entry.value,
          ),
        )
        .toList();
    pending.sort(
      (left, right) => left.displayName.compareTo(right.displayName),
    );
    return List<LibrarySyncPendingProfile>.unmodifiable(pending);
  }

  /// Converts one downloaded story into a local book on a child's shelf.
  ///
  /// Downloaded stories arrive approved: only a completed generation reaches
  /// the master library, and the parent on the generating device reviewed it
  /// before it was saved there, so a synced story is already parent-approved
  /// content. Page scenes are rebuilt through [BridgeStoryProvenance] so the
  /// master-library story and illustration identities survive locally for the
  /// illustration milestone. A book that is already here keeps its local
  /// identity, creation time, favourite marker, collections, and the theme and
  /// moral the parent originally typed on this device.
  StoryBook _storyBook({
    required BridgeSyncStoryDownload download,
    required BridgeSyncStory entry,
    required ChildProfile profile,
    required StoryBook? localStory,
  }) {
    final story = download.story;
    if (story.id != entry.id || download.profileId != entry.profileId) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    final pages = <StoryPage>[];
    for (final (index, page) in story.pages.indexed) {
      if (page.pageNumber != index + 1) {
        throw const BridgeException(BridgeFailure.invalidResponse);
      }
      pages.add(
        StoryPage(
          number: page.pageNumber,
          text: page.text,
          sceneDescription: BridgeStoryProvenance(
            scene: page.illustrationScene,
            storyId: story.id,
            illustrationId: page.illustrationId,
          ).toSceneDescription(),
        ),
      );
    }
    final localRequest = localStory?.content.request;
    return StoryBook(
      id: localStory?.id ?? story.id,
      createdAt:
          localStory?.createdAt ?? story.createdAtUtc ?? entry.createdAtUtc,
      content: StoryContent(
        title: story.title,
        request: StoryRequest(
          hero:
              localRequest?.hero ??
              StoryHero(
                profileId: download.profileId,
                name: profile.name,
                gender: profile.gender,
              ),
          prompt:
              localRequest?.prompt ??
              const StoryPrompt(
                theme: syncedStoryPromptPlaceholder,
                moral: syncedStoryPromptPlaceholder,
                preferences: ChildStoryPreferences(),
              ),
          presentation: StoryPresentation(
            language: _storyLanguage(story.languageCode),
            length: _storyLength(pages.length),
            style:
                localRequest?.presentation.style ??
                IllustrationStyle.pictureBook,
          ),
        ),
        pages: List<StoryPage>.unmodifiable(pages),
      ),
      reviewStatus: StoryReviewStatus.approved,
      isFavorite: localStory?.isFavorite ?? false,
      collections: localStory?.collections ?? const <String>[],
    );
  }

  /// Refuses a story written in a language this build cannot present.
  AppLanguage _storyLanguage(String languageCode) {
    try {
      return AppLanguage.requireCode(languageCode);
    } on FormatException {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
  }

  /// Refuses a page count no story length in this build describes.
  StoryLength _storyLength(int pageCount) {
    for (final length in StoryLength.values) {
      if (length.pageCount == pageCount) return length;
    }
    throw const BridgeException(BridgeFailure.invalidResponse);
  }

  /// Resolves the local child a downloaded story belongs to, if it exists.
  ChildProfile? _profileById(List<ChildProfile> profiles, String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }
}
