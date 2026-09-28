import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/core/storage/library_store.dart';
import 'package:miko_hero/core/storage/library_transaction.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the one order every family change now follows: persist, publish.
///
/// The guarantees checked here are the ones six controllers each used to uphold
/// by hand: a refused write leaves the screen on what the device really holds,
/// a shelf is stored newest first whatever the caller returned, and a snapshot
/// that would not survive loading is refused before anything is written.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a store that refuses the write publishes nothing', () async {
    final store = _RecordingStore(failing: true);
    final container = await _familyContainer(
      store,
      stories: <StoryBook>[_story('story-moon', DateTime.utc(2026, 8, 18))],
    );
    final before = container.read(appControllerProvider).requireValue;

    await expectLater(
      container
          .read(libraryTransactionProvider)
          .mutateStories((stories) => const <StoryBook>[]),
      throwsA(isA<StateError>()),
    );

    final after = container.read(appControllerProvider).requireValue;
    expect(identical(after, before), isTrue, reason: 'nothing was published');
    expect(after.stories.single.id, 'story-moon');
    expect(store.savedStories, isNull, reason: 'the write did not complete');
  });

  test('a shelf handed back out of order is stored newest first', () async {
    final store = _RecordingStore();
    final container = await _familyContainer(store);
    final older = _story('story-older', DateTime.utc(2026, 1, 1));
    final newer = _story('story-newer', DateTime.utc(2026, 9, 1));

    await container
        .read(libraryTransactionProvider)
        .mutateStories((stories) => <StoryBook>[older, newer]);

    expect(store.savedStories!.map((story) => story.id).toList(), <String>[
      'story-newer',
      'story-older',
    ]);
    expect(
      container
          .read(appControllerProvider)
          .requireValue
          .stories
          .map((story) => story.id)
          .toList(),
      <String>['story-newer', 'story-older'],
    );
  });

  test('updating a story this device no longer has writes nothing', () async {
    final store = _RecordingStore();
    final container = await _familyContainer(store);

    await expectLater(
      container
          .read(libraryTransactionProvider)
          .updateStory('story-gone', (story) => story.withFavorite(true)),
      throwsA(isA<UnknownEntityException>()),
    );

    expect(store.savedStories, isNull);
  });

  test('a story for a child who does not exist is refused', () async {
    final store = _RecordingStore();
    final container = await _familyContainer(store);
    final orphan = _story(
      'story-orphan',
      DateTime.utc(2026, 5, 5),
      profileId: 'no-such-child',
    );

    await expectLater(
      container
          .read(libraryTransactionProvider)
          .mutateStories((stories) => <StoryBook>[orphan]),
      throwsA(isA<FormatException>()),
    );

    expect(store.savedStories, isNull, reason: 'refused before any write');
    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
  });

  test('activating a child writes the identity, not every profile', () async {
    final store = _RecordingStore();
    final container = await _familyContainer(store);

    await container
        .read(libraryTransactionProvider)
        .mutateProfiles((profiles) => profiles, activeProfileId: 'miko');

    expect(store.savedProfiles, isNull, reason: 'no photo was rewritten');
    expect(store.savedActiveProfileId, 'miko');
    expect(
      container.read(appControllerProvider).requireValue.activeProfileId,
      'miko',
    );
  });
}

/// A store that records what it was asked to write, or refuses every write.
class _RecordingStore implements LibraryStore {
  _RecordingStore({this.failing = false});

  final bool failing;
  List<StoryBook>? savedStories;
  List<ChildProfile>? savedProfiles;
  String? savedActiveProfileId;

  @override
  Future<void> saveStories(List<StoryBook> stories) async {
    _refuseWhenFailing();
    savedStories = stories;
  }

  @override
  Future<void> saveProfiles(List<ChildProfile> profiles) async {
    _refuseWhenFailing();
    savedProfiles = profiles;
  }

  @override
  Future<void> saveActiveProfileId(String profileId) async {
    _refuseWhenFailing();
    savedActiveProfileId = profileId;
  }

  @override
  Future<void> saveLocale(Locale locale) async => _refuseWhenFailing();

  @override
  Future<void> replaceState(AppState restoredState) async {
    _refuseWhenFailing();
  }

  @override
  Future<void> clearAll() async => _refuseWhenFailing();

  /// Stands in for a full disk or a revoked profile directory.
  void _refuseWhenFailing() {
    if (failing) throw StateError('The device refused the write.');
  }
}

/// Opens a container over one saved child, writing through the given store.
Future<ProviderContainer> _familyContainer(
  LibraryStore store, {
  List<StoryBook> stories = const <StoryBook>[],
}) async {
  final repository = await LocalRepository.open();
  await repository.saveProfiles(const <ChildProfile>[
    ChildProfile(
      id: 'miko',
      name: 'Miko',
      legacyAge: 8,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
    ),
  ]);
  await repository.saveStories(stories);
  final container = ProviderContainer(
    overrides: [libraryStoreProvider.overrideWith((ref) async => store)],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  return container;
}

/// Builds one saved book belonging to the container's only child.
StoryBook _story(String id, DateTime createdAt, {String profileId = 'miko'}) {
  return StoryBook(
    id: id,
    createdAt: createdAt,
    content: StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
        hero: StoryHero(
          profileId: profileId,
          name: 'Miko',
          gender: ChildGender.girl,
        ),
        prompt: const StoryPrompt(
          theme: 'moon garden',
          moral: 'kindness',
          preferences: ChildStoryPreferences(),
        ),
        presentation: const StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.watercolor,
        ),
      ),
      pages: const <StoryPage>[
        StoryPage(
          number: 1,
          text: 'A kind beginning.',
          sceneDescription: 'A moonlit garden.',
        ),
      ],
    ),
    reviewStatus: StoryReviewStatus.approved,
  );
}
