import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/export/story_pdf_service.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Exercises real bundled fonts and the real PDF renderer for each script.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final examples = <AppLanguage, String>{
    AppLanguage.english: 'Miko found a kind and curious dragon.',
    AppLanguage.swedish: 'Miko följde stjärnorna över den gröna ängen.',
    AppLanguage.somali: 'Miko wuxuu saaxiibbadii la wadaagay xiddigaha.',
    AppLanguage.arabic: 'وجد ميكو تنيناً لطيفاً وساعد أصدقاءه بشجاعة.',
  };

  for (final example in examples.entries) {
    test('builds a readable ${example.key.code} PDF offline', () async {
      final bytes = await StoryPdfService().build(
        _story(example.key, example.value),
      );

      expect(ascii.decode(bytes.take(4).toList()), '%PDF');
      expect(bytes.length, greaterThan(1000));
    });
  }

  test('the chosen cover photo is embedded in a valid PDF', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');

    final withPhoto = await StoryPdfService().build(
      story,
      coverPhotoBase64: _transparentPixel,
    );
    final withoutPhoto = await StoryPdfService().build(story);

    expect(ascii.decode(withPhoto.take(4).toList()), '%PDF');
    expect(ascii.decode(withoutPhoto.take(4).toList()), '%PDF');
    expect(withPhoto.length, greaterThan(withoutPhoto.length));
  });

  test('an unreadable photo falls back to the photo-free cover', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');

    final broken = await StoryPdfService().build(
      story,
      coverPhotoBase64: 'not-base64-at-all',
    );
    final withoutPhoto = await StoryPdfService().build(story);

    expect(ascii.decode(broken.take(4).toList()), '%PDF');
    expect(broken.length, withoutPhoto.length);
  });

  for (final language in <AppLanguage>[
    AppLanguage.english,
    AppLanguage.arabic,
  ]) {
    test('drawn ${language.code} pages carry their picture', () async {
      final story = _illustratedStory(language);

      final illustrated = await StoryPdfService().build(
        story,
        illustrationBytesById: <String, Uint8List>{
          'illustration-1': base64Decode(_transparentPixel),
          'illustration-2': base64Decode(_transparentPixel),
        },
      );
      final textOnly = await StoryPdfService().build(story);

      expect(ascii.decode(illustrated.take(4).toList()), '%PDF');
      expect(illustrated.length, greaterThan(textOnly.length));
    });
  }

  test('a page whose picture is missing stays text-only', () async {
    final story = _illustratedStory(AppLanguage.english);

    final partial = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': base64Decode(_transparentPixel),
      },
    );
    final everyPage = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': base64Decode(_transparentPixel),
        'illustration-2': base64Decode(_transparentPixel),
      },
    );
    final textOnly = await StoryPdfService().build(story);

    expect(ascii.decode(partial.take(4).toList()), '%PDF');
    expect(partial.length, greaterThan(textOnly.length));
    expect(partial.length, lessThan(everyPage.length));
  });

  test('undecodable page bytes fall back to the text-only page', () async {
    final story = _illustratedStory(AppLanguage.english);

    final broken = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': Uint8List.fromList(ascii.encode('not-an-image')),
        'illustration-2': Uint8List(0),
      },
    );
    final textOnly = await StoryPdfService().build(story);

    expect(ascii.decode(broken.take(4).toList()), '%PDF');
    expect(broken.length, textOnly.length);
  });

  test('a demo story ignores bytes it has no identity for', () async {
    final story = _story(AppLanguage.english, 'Miko waved at the moon.');

    final withBytes = await StoryPdfService().build(
      story,
      illustrationBytesById: <String, Uint8List>{
        'illustration-1': base64Decode(_transparentPixel),
      },
    );
    final textOnly = await StoryPdfService().build(story);

    expect(withBytes.length, textOnly.length);
  });

  test('pictures leave the cover photo choice untouched', () async {
    final story = _illustratedStory(AppLanguage.english);
    final pictures = <String, Uint8List>{
      'illustration-1': base64Decode(_transparentPixel),
      'illustration-2': base64Decode(_transparentPixel),
    };

    final withoutPhoto = await StoryPdfService().build(
      story,
      illustrationBytesById: pictures,
    );
    final withPhoto = await StoryPdfService().build(
      story,
      coverPhotoBase64: _transparentPixel,
      illustrationBytesById: pictures,
    );

    expect(withPhoto.length, greaterThan(withoutPhoto.length));
  });
}

/// Obviously fake 1x1 transparent image standing in for a reference photo.
const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Creates one approved book with realistic multilingual generation metadata.
StoryBook _story(AppLanguage language, String pageText) {
  return StoryBook(
    id: 'story-${language.code}',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: _title(language),
      request: _request(language),
      pages: <StoryPage>[
        StoryPage(number: 1, text: pageText, sceneDescription: 'A kind hero'),
      ],
    ),
  );
}

/// Creates one bridge-generated book whose pages name their drawn pictures.
///
/// Built through the real provenance encoding, so the export has to recover the
/// identities the same way the reader does.
StoryBook _illustratedStory(AppLanguage language) {
  return StoryBook(
    id: 'story-drawn-${language.code}',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: _title(language),
      request: _request(language),
      pages: <StoryPage>[
        StoryPage(
          number: 1,
          text: language == AppLanguage.arabic
              ? 'وجد ميكو تنيناً لطيفاً.'
              : 'Miko found a kind dragon.',
          sceneDescription: const BridgeStoryProvenance(
            scene: 'A kind hero greets a dragon',
            storyId: 'bridge-story-1',
            illustrationId: 'illustration-1',
          ).toSceneDescription(),
        ),
        StoryPage(
          number: 2,
          text: language == AppLanguage.arabic
              ? 'ساعد أصدقاءه بشجاعة.'
              : 'He helped his friends bravely.',
          sceneDescription: const BridgeStoryProvenance(
            scene: 'The hero helps his friends',
            storyId: 'bridge-story-1',
            illustrationId: 'illustration-2',
          ).toSceneDescription(),
        ),
      ],
    ),
  );
}

/// Creates generation context without bypassing production model validation.
StoryRequest _request(AppLanguage language) {
  return StoryRequest(
    hero: const StoryHero(
      profileId: 'profile-miko',
      name: 'Miko',
      gender: ChildGender.boy,
    ),
    prompt: const StoryPrompt(
      theme: 'Stars',
      moral: 'Kindness',
      preferences: ChildStoryPreferences(),
    ),
    presentation: StoryPresentation(
      language: language,
      length: StoryLength.short,
      style: IllustrationStyle.pictureBook,
    ),
  );
}

/// Includes Arabic glyphs on the cover in addition to page prose.
String _title(AppLanguage language) {
  return language == AppLanguage.arabic ? 'ميكو بطل النجوم' : 'Miko Hero';
}
