import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/shared/story_artwork.dart';

/// Verifies that one table paints the swatch, the cover, and the page.
void main() {
  test('a style and a hero produce the same colours on every surface', () {
    for (final style in IllustrationStyle.values) {
      for (final gender in ChildGender.values) {
        final colors = StoryArtwork.placeholderColors(style, gender);
        final story = _story(style: style, gender: gender);

        expect(
          StoryArtwork.gradientOf(story).colors,
          colors,
          reason: 'the cover and the page of a $gender $style story',
        );
        expect(
          StoryArtwork.swatchFor(style, gender),
          colors,
          reason: 'the creation swatch for a $gender $style story',
        );
      }
    }
  });

  test('a request with no hero yet previews the neutral palette', () {
    for (final style in IllustrationStyle.values) {
      expect(
        StoryArtwork.swatchFor(style, null),
        StoryArtwork.placeholderColors(style, ChildGender.unspecified),
      );
    }
  });

  test('the colorful-3D placeholder closes on the one artwork violet', () {
    for (final gender in ChildGender.values) {
      expect(
        StoryArtwork.placeholderColors(
          IllustrationStyle.colorful3d,
          gender,
        ).last,
        storyArtworkViolet,
      );
    }
  });

  test(
    'a hero changes the placeholder, so a girl never gets a boy palette',
    () {
      for (final style in IllustrationStyle.values) {
        expect(
          StoryArtwork.placeholderColors(style, ChildGender.girl),
          isNot(StoryArtwork.placeholderColors(style, ChildGender.boy)),
        );
      }
    },
  );
}

/// Builds one approved book styled exactly as the request asked.
StoryBook _story({
  required IllustrationStyle style,
  required ChildGender gender,
}) {
  return StoryBook(
    id: 'story-$style-$gender',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
        hero: StoryHero(profileId: 'miko', name: 'Miko', gender: gender),
        prompt: const StoryPrompt(
          theme: 'moon garden',
          moral: 'kindness',
          preferences: ChildStoryPreferences(),
        ),
        presentation: StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: style,
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
  );
}
