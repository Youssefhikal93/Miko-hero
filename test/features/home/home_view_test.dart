import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/home/home_view.dart';

/// Verifies everything Home decides, without pumping the screen that shows it.
///
/// These rules used to be worked out while `_HomeContent` built itself, where
/// only a widget test could reach them. They are pure functions of one stored
/// snapshot and one moment, so they are asserted as such.
void main() {
  final moment = DateTime(2026, 9, 3, 19);

  group('the keep-reading book', () {
    test('is the newest book on the active shelf nobody finished', () {
      final view = HomeView.of(
        _state(
          stories: <StoryBook>[
            _story(id: 'newest', hour: 14),
            _story(id: 'older', hour: 12),
          ],
        ),
        now: moment,
      );

      expect(view.keepReading?.id, 'newest');
    });

    test('skips the books this device recorded as finished', () {
      final view = HomeView.of(
        _state(
          finishedStoryIds: const <String>['newest'],
          stories: <StoryBook>[
            _story(id: 'newest', hour: 14),
            _story(id: 'older', hour: 12),
          ],
        ),
        now: moment,
      );

      expect(view.keepReading?.id, 'older');
    });

    test('is absent for a family whose every book is finished', () {
      final view = HomeView.of(
        _state(
          finishedStoryIds: const <String>['a', 'b'],
          stories: <StoryBook>[
            _story(id: 'a', hour: 14),
            _story(id: 'b', hour: 12),
          ],
        ),
        now: moment,
      );

      expect(view.keepReading, isNull);
      expect(
        view.shelfStrip.map((story) => story.id),
        <String>['a', 'b'],
        reason: 'a finished book leaves the tile but stays on the shelf',
      );
    });

    test('is absent while no child is active', () {
      final view = HomeView.of(
        _state(activeProfileId: null, stories: <StoryBook>[_story(id: 'a')]),
        now: moment,
      );

      expect(view.keepReading, isNull);
      expect(view.shelfStrip, isEmpty);
      expect(view.shelfRoute, isNull);
    });
  });

  group('the shelf strip', () {
    test('never shows the book already featured on the tile', () {
      final view = HomeView.of(
        _state(
          stories: <StoryBook>[
            for (var index = 0; index < 4; index++)
              _story(id: 'story-$index', hour: 20 - index),
          ],
        ),
        now: moment,
      );

      expect(view.keepReading?.id, 'story-0');
      expect(view.shelfStrip.map((story) => story.id), <String>[
        'story-1',
        'story-2',
        'story-3',
      ]);
    });

    test('caps at six covers and hands the rest to the library', () {
      final view = HomeView.of(
        _state(
          stories: <StoryBook>[
            for (var index = 0; index < 9; index++)
              _story(id: 'story-$index', hour: 20 - index),
          ],
        ),
        now: moment,
      );

      expect(view.shelfStrip.length, 6);
      expect(view.shelfStrip.first.id, 'story-1');
      expect(view.shelfStrip.last.id, 'story-6');
    });

    test('caps at six even when no book is featured', () {
      final view = HomeView.of(
        _state(
          finishedStoryIds: <String>[
            for (var index = 0; index < 9; index++) 'story-$index',
          ],
          stories: <StoryBook>[
            for (var index = 0; index < 9; index++)
              _story(id: 'story-$index', hour: 20 - index),
          ],
        ),
        now: moment,
      );

      expect(view.keepReading, isNull);
      expect(view.shelfStrip.length, 6);
      expect(view.shelfStrip.first.id, 'story-0');
    });

    test('carries neither a draft nor another child\'s book', () {
      final view = HomeView.of(
        _state(
          stories: <StoryBook>[
            _story(id: 'featured', hour: 20),
            _story(id: 'mine', hour: 18),
            _story(
              id: 'draft',
              hour: 17,
              reviewStatus: StoryReviewStatus.draft,
            ),
            _story(id: 'theirs', hour: 16, profileId: 'abbas'),
          ],
        ),
        now: moment,
      );

      expect(view.shelfStrip.map((story) => story.id), <String>['mine']);
      expect(view.draftCount, 1);
    });
  });

  group('"See all"', () {
    test('names the child Home is reading as, not the first profile', () {
      final view = HomeView.of(
        _state(
          activeProfileId: 'abbas',
          stories: <StoryBook>[
            _story(id: 'featured', hour: 20, profileId: 'abbas'),
            _story(id: 'theirs', hour: 18, profileId: 'abbas'),
            _story(id: 'mine', hour: 16),
          ],
        ),
        now: moment,
      );

      expect(view.shelfRoute, '/library?child=abbas');
    });

    test('is absent while there is no strip to hand over', () {
      final view = HomeView.of(
        _state(stories: <StoryBook>[_story(id: 'only-one')]),
        now: moment,
      );

      expect(view.shelfStrip, isEmpty);
      expect(
        view.shelfRoute,
        isNull,
        reason: 'the heading carrying the link only exists over a strip',
      );
    });
  });

  group('the line under the greeting', () {
    test('a book to continue comes before drafts and the invitation', () {
      final view = HomeView.of(
        _state(
          stories: <StoryBook>[
            _story(id: 'a', hour: 14),
            _story(
              id: 'draft',
              hour: 12,
              reviewStatus: StoryReviewStatus.draft,
            ),
          ],
        ),
        now: moment,
      );

      expect(view.greetingLine, HomeGreetingLine.continueReading);
    });

    test('drafts come before the invitation', () {
      final view = HomeView.of(
        _state(
          finishedStoryIds: const <String>['a'],
          stories: <StoryBook>[
            _story(id: 'a', hour: 14),
            _story(
              id: 'draft',
              hour: 12,
              reviewStatus: StoryReviewStatus.draft,
            ),
          ],
        ),
        now: moment,
      );

      expect(view.greetingLine, HomeGreetingLine.draftsWaiting);
      expect(view.draftCount, 1);
    });

    test('with neither, the family is invited to write one', () {
      final view = HomeView.of(_state(), now: moment);

      expect(view.greetingLine, HomeGreetingLine.invitation);
      expect(view.draftCount, 0);
    });

    test('another child\'s drafts still count as waiting', () {
      final view = HomeView.of(
        _state(
          stories: <StoryBook>[
            _story(
              id: 'draft',
              hour: 12,
              profileId: 'abbas',
              reviewStatus: StoryReviewStatus.draft,
            ),
          ],
        ),
        now: moment,
      );

      expect(view.greetingLine, HomeGreetingLine.draftsWaiting);
    });
  });

  group('the greeting follows the clock', () {
    test('every part of the day has its own hours', () {
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 4, 59)), HomeTimeOfDay.night);
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 5)), HomeTimeOfDay.morning);
      expect(
        homeTimeOfDay(DateTime(2026, 9, 3, 11, 59)),
        HomeTimeOfDay.morning,
      );
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 12)), HomeTimeOfDay.afternoon);
      expect(
        homeTimeOfDay(DateTime(2026, 9, 3, 16, 59)),
        HomeTimeOfDay.afternoon,
      );
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 17)), HomeTimeOfDay.evening);
      expect(
        homeTimeOfDay(DateTime(2026, 9, 3, 21, 59)),
        HomeTimeOfDay.evening,
      );
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 22)), HomeTimeOfDay.night);
    });

    test('the supplied moment is the one the greeting follows', () {
      final state = _state();

      expect(
        HomeView.of(state, now: DateTime(2026, 9, 3, 8)).timeOfDay,
        HomeTimeOfDay.morning,
      );
      expect(
        HomeView.of(state, now: DateTime(2026, 9, 3, 23)).timeOfDay,
        HomeTimeOfDay.night,
      );
    });
  });
}

/// One stored family: Miko and Abbas, Miko reading unless told otherwise.
AppState _state({
  List<StoryBook> stories = const <StoryBook>[],
  String? activeProfileId = 'miko',
  List<String> finishedStoryIds = const <String>[],
}) {
  return AppState.validated(
    locale: AppLanguage.english.locale,
    profiles: <ChildProfile>[
      _profile('miko', 'Miko', finishedStoryIds: finishedStoryIds),
      _profile('abbas', 'Abbas'),
    ],
    stories: stories,
    activeProfileId: activeProfileId,
  );
}

/// One stored child profile with the defaults the editor writes.
ChildProfile _profile(
  String id,
  String name, {
  List<String> finishedStoryIds = const <String>[],
}) {
  return ChildProfile(
    id: id,
    name: name,
    legacyAge: 7,
    photoBase64: '',
    gender: ChildGender.girl,
    themeColorValue: roseProfileThemeColorValue,
    hasCustomThemeColor: false,
    finishedStoryIds: finishedStoryIds,
  );
}

/// One stored book on [profileId]'s shelf, created at [hour] on one day.
StoryBook _story({
  required String id,
  int hour = 12,
  String profileId = 'miko',
  StoryReviewStatus reviewStatus = StoryReviewStatus.approved,
}) {
  return StoryBook(
    id: id,
    createdAt: DateTime.utc(2026, 8, 17, hour),
    reviewStatus: reviewStatus,
    content: StoryContent(
      title: 'The moon garden',
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
