import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Verifies the observable contract of the temporary local demo generator.
void main() {
  final fixedTime = DateTime.utc(2026, 8, 17, 10);
  final generator = DemoStoryGenerator(
    latency: Duration.zero,
    currentTime: () => fixedTime,
  );

  test('selected length produces the exact reader page count', () async {
    for (final testCase in <(StoryLength, int)>[
      (StoryLength.short, 6),
      (StoryLength.medium, 8),
      (StoryLength.long, 10),
    ]) {
      final story = await generator.generate(_request(length: testCase.$1));

      expect(story.content.pages, hasLength(testCase.$2));
      expect(
        story.content.pages.map((page) => page.number),
        orderedEquals(List<int>.generate(testCase.$2, (index) => index + 1)),
      );
    }
  });

  test('each supported language produces a complete isolated script', () async {
    for (final language in AppLanguage.values) {
      final story = await generator.generate(_request(language: language));

      expect(story.content.request.presentation.language, language);
      expect(story.content.title, isNotEmpty);
      expect(story.content.pages.every((page) => page.text.isNotEmpty), isTrue);
    }
  });

  test(
    'Girl and Boy choices produce matching English character wording',
    () async {
      final girlStory = await generator.generate(
        _request(gender: ChildGender.girl),
      );
      final boyStory = await generator.generate(
        _request(gender: ChildGender.boy),
      );

      expect(girlStory.content.pages[1].text, startsWith('She '));
      expect(boyStory.content.pages[1].text, startsWith('He '));
      expect(girlStory.content.pages.first.sceneDescription, contains('girl'));
      expect(boyStory.content.pages.first.sceneDescription, contains('boy'));
    },
  );

  test(
    'Girl and Boy choices affect prose in every supported language',
    () async {
      for (final language in AppLanguage.values) {
        final girlStory = await generator.generate(
          _request(language: language, gender: ChildGender.girl),
        );
        final boyStory = await generator.generate(
          _request(language: language, gender: ChildGender.boy),
        );

        expect(
          girlStory.content.pages.map((page) => page.text),
          isNot(orderedEquals(boyStory.content.pages.map((page) => page.text))),
        );
      }
    },
  );

  test('generation rejects a request without a parent gender choice', () async {
    expect(
      generator.generate(_request(gender: ChildGender.unspecified)),
      throwsArgumentError,
    );
  });

  test('saved child inspiration is carried into demo story context', () async {
    const preferences = ChildStoryPreferences(
      favoriteThings: 'trains and stars',
      recurringWorld: 'Golden Cloud Kingdom',
      excludedTopics: <SafetyTopic>{SafetyTopic.frighteningContent},
    );

    final story = await generator.generate(_request(preferences: preferences));

    expect(story.content.title, contains(preferences.recurringWorld));
    expect(story.content.pages[2].text, contains(preferences.favoriteThings));
  });
}

/// Creates a valid request while allowing tests to vary one generator contract.
StoryRequest _request({
  AppLanguage language = AppLanguage.english,
  StoryLength length = StoryLength.short,
  ChildGender gender = ChildGender.girl,
  ChildStoryPreferences preferences = const ChildStoryPreferences(),
}) {
  return StoryRequest(
    hero: StoryHero(profileId: 'miko', name: 'Miko', gender: gender),
    prompt: StoryPrompt(
      theme: 'a moon garden',
      moral: 'kindness',
      preferences: preferences,
    ),
    presentation: StoryPresentation(
      language: language,
      length: length,
      style: IllustrationStyle.pictureBook,
    ),
  );
}
