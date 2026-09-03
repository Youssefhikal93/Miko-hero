import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/library/shelf_view.dart';

/// Verifies the five decisions the shelf makes, without pumping a widget.
///
/// These used to live inside the library page's `State`, where the only way to
/// reach them was to build the whole screen. They are pure functions of one
/// library snapshot, so they are asserted here as such.
void main() {
  final miko = _profile('miko', 'Miko');
  final abbas = _profile('abbas', 'Abbas');

  group('whose shelf is on screen', () {
    test('a tapped chip beats the route, the active child, and the first', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko, abbas],
        stories: const <StoryBook>[],
        filter: const AllStories(),
        query: '',
        requestedProfileId: 'miko',
        activeProfileId: 'miko',
        tappedProfileId: 'abbas',
      );

      expect(view.profile?.id, 'abbas');
    });

    test('the route beats the active child and the first', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko, abbas],
        stories: const <StoryBook>[],
        filter: const AllStories(),
        query: '',
        requestedProfileId: 'abbas',
        activeProfileId: 'miko',
      );

      expect(view.profile?.id, 'abbas');
    });

    test('the active child beats the first profile', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko, abbas],
        stories: const <StoryBook>[],
        filter: const AllStories(),
        query: '',
        activeProfileId: 'abbas',
      );

      expect(view.profile?.id, 'abbas');
    });

    test('nothing asked for opens the first profile', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko, abbas],
        stories: const <StoryBook>[],
        filter: const AllStories(),
        query: '',
      );

      expect(view.profile?.id, 'miko');
    });

    test('a child deleted while their shelf was open falls through', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: const <StoryBook>[],
        filter: const AllStories(),
        query: '',
        tappedProfileId: 'gone',
        requestedProfileId: 'also-gone',
        activeProfileId: 'abbas',
      );

      expect(view.profile?.id, 'miko');
    });

    test('a family with no children resolves to no shelf at all', () {
      final view = ShelfView.resolve(
        profiles: const <ChildProfile>[],
        stories: const <StoryBook>[],
        filter: const AllStories(),
        query: '',
        activeProfileId: 'miko',
      );

      expect(view.profile, isNull);
      expect(view.hasBooks, isFalse);
      expect(view.stories, isEmpty);
    });
  });

  group('which books the shelf holds', () {
    test('only this child\'s approved books reach the shelf', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko, abbas],
        stories: <StoryBook>[
          _story(id: 'a', profileId: 'miko', title: 'The moon garden'),
          _story(
            id: 'b',
            profileId: 'miko',
            title: 'A draft',
            reviewStatus: StoryReviewStatus.draft,
          ),
          _story(id: 'c', profileId: 'abbas', title: 'Two kites'),
        ],
        filter: const AllStories(),
        query: '',
        activeProfileId: 'miko',
      );

      expect(
        view.stories.map((story) => story.id),
        <String>['a'],
        reason: 'a draft is invisible to a child and so is another shelf',
      );
      expect(view.hasBooks, isTrue);
      expect(view.matchingCount, 1);
    });

    test(
      'a shelf that holds books but matches nothing is not an empty one',
      () {
        final view = ShelfView.resolve(
          profiles: <ChildProfile>[miko],
          stories: <StoryBook>[
            _story(id: 'a', profileId: 'miko', title: 'The moon garden'),
          ],
          filter: const AllStories(),
          query: 'lantern',
          activeProfileId: 'miko',
        );

        expect(view.hasBooks, isTrue);
        expect(view.stories, isEmpty);
        expect(view.matchingCount, 0);
      },
    );
  });

  group('the title search', () {
    final shelf = <StoryBook>[
      _story(id: 'a', profileId: 'miko', title: 'The Lantern Path'),
      _story(id: 'b', profileId: 'miko', title: 'The moon garden'),
    ];

    test('ignores the case of both the query and the title', () {
      for (final query in <String>['lantern', 'LANTERN', 'LaNtErN']) {
        final view = ShelfView.resolve(
          profiles: <ChildProfile>[miko],
          stories: shelf,
          filter: const AllStories(),
          query: query,
          activeProfileId: 'miko',
        );

        expect(view.stories.map((story) => story.id), <String>['a']);
      }
    });

    test('ignores surrounding whitespace and an empty search', () {
      final trimmed = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: shelf,
        filter: const AllStories(),
        query: '  lantern  ',
        activeProfileId: 'miko',
      );
      final blank = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: shelf,
        filter: const AllStories(),
        query: '   ',
        activeProfileId: 'miko',
      );

      expect(trimmed.stories.map((story) => story.id), <String>['a']);
      expect(blank.stories.length, 2);
    });

    test('never reads the prose a child is reading', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: shelf,
        filter: const AllStories(),
        query: 'glowed',
        activeProfileId: 'miko',
      );

      expect(
        view.stories,
        isEmpty,
        reason: 'every page says "The garden glowed"; only titles are searched',
      );
    });

    test('narrows the All count but never the collection chips', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(
            id: 'a',
            profileId: 'miko',
            title: 'The lantern path',
            collections: const <String>['Bedtime'],
          ),
          _story(
            id: 'b',
            profileId: 'miko',
            title: 'The moon garden',
            collections: const <String>['Adventures'],
          ),
        ],
        filter: const AllStories(),
        query: 'lantern',
        activeProfileId: 'miko',
      );

      expect(view.matchingCount, 1);
      expect(view.collections, <String>['Adventures', 'Bedtime']);
    });
  });

  group('the filter chips', () {
    test('collections are listed once, in case-insensitive order', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(
            id: 'a',
            profileId: 'miko',
            title: 'One',
            collections: const <String>['bedtime', 'Adventures'],
          ),
          _story(
            id: 'b',
            profileId: 'miko',
            title: 'Two',
            collections: const <String>['bedtime'],
          ),
        ],
        filter: const AllStories(),
        query: '',
        activeProfileId: 'miko',
      );

      expect(view.collections, <String>['Adventures', 'bedtime']);
    });

    test('favorites keeps only the starred books', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(id: 'a', profileId: 'miko', title: 'One', isFavorite: true),
          _story(id: 'b', profileId: 'miko', title: 'Two'),
        ],
        filter: const FavoriteStories(),
        query: '',
        activeProfileId: 'miko',
      );

      expect(view.filter, const FavoriteStories());
      expect(view.stories.map((story) => story.id), <String>['a']);
    });

    test('a filter whose collection left the shelf falls back to All', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(id: 'a', profileId: 'miko', title: 'One'),
          _story(id: 'b', profileId: 'miko', title: 'Two'),
        ],
        filter: const StoriesInCollection('Bedtime'),
        query: '',
        activeProfileId: 'miko',
      );

      expect(view.filter, const AllStories());
      expect(view.stories.length, 2);
    });

    test('favorites survives a shelf with no starred book on it', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[_story(id: 'a', profileId: 'miko', title: 'One')],
        filter: const FavoriteStories(),
        query: '',
        activeProfileId: 'miko',
      );

      expect(
        view.filter,
        const FavoriteStories(),
        reason: 'the favorites chip is always offered, so it never falls back',
      );
      expect(view.stories, isEmpty);
    });

    test('a collection literally named "collection:bedtime" still works', () {
      const label = 'collection:bedtime';
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(
            id: 'a',
            profileId: 'miko',
            title: 'One',
            collections: const <String>[label],
          ),
          _story(
            id: 'b',
            profileId: 'miko',
            title: 'Two',
            collections: const <String>['bedtime'],
          ),
        ],
        filter: const StoriesInCollection(label),
        query: '',
        activeProfileId: 'miko',
      );

      expect(view.filter, const StoriesInCollection(label));
      expect(
        view.stories.map((story) => story.id),
        <String>['a'],
        reason: 'the label is a name, not an encoded selector to decode again',
      );
    });

    test('a collection named "all" is not the All chip', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(
            id: 'a',
            profileId: 'miko',
            title: 'One',
            collections: const <String>['all'],
          ),
          _story(id: 'b', profileId: 'miko', title: 'Two'),
        ],
        filter: const StoriesInCollection('all'),
        query: '',
        activeProfileId: 'miko',
      );

      expect(view.stories.map((story) => story.id), <String>['a']);
    });

    test('search and collection narrow the shelf together', () {
      final view = ShelfView.resolve(
        profiles: <ChildProfile>[miko],
        stories: <StoryBook>[
          _story(
            id: 'a',
            profileId: 'miko',
            title: 'The lantern path',
            collections: const <String>['Bedtime'],
          ),
          _story(
            id: 'b',
            profileId: 'miko',
            title: 'The moon garden',
            collections: const <String>['Bedtime'],
          ),
        ],
        filter: const StoriesInCollection('Bedtime'),
        query: 'moon',
        activeProfileId: 'miko',
      );

      expect(view.stories.map((story) => story.id), <String>['b']);
    });
  });
}

/// One stored child profile with the defaults the editor writes.
ChildProfile _profile(String id, String name) {
  return ChildProfile(
    id: id,
    name: name,
    legacyAge: 7,
    photoBase64: '',
    gender: ChildGender.girl,
    themeColorValue: roseProfileThemeColorValue,
    hasCustomThemeColor: false,
  );
}

/// One stored book on [profileId]'s shelf.
StoryBook _story({
  required String id,
  required String profileId,
  required String title,
  StoryReviewStatus reviewStatus = StoryReviewStatus.approved,
  bool isFavorite = false,
  List<String> collections = const <String>[],
}) {
  return StoryBook(
    id: id,
    createdAt: DateTime.utc(2026, 8, 17, 12),
    reviewStatus: reviewStatus,
    isFavorite: isFavorite,
    collections: collections,
    content: StoryContent(
      title: title,
      request: StoryRequest(
        hero: StoryHero(
          profileId: profileId,
          name: 'Hero',
          gender: ChildGender.girl,
        ),
        prompt: const StoryPrompt(
          theme: 'a moon garden',
          moral: 'kindness',
          preferences: ChildStoryPreferences(),
        ),
        presentation: const StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.pictureBook,
        ),
      ),
      pages: const <StoryPage>[
        StoryPage(
          number: 1,
          text: 'The garden glowed.',
          sceneDescription: 'a glowing garden',
        ),
      ],
    ),
  );
}
