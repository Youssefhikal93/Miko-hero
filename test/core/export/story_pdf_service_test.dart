import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}

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
