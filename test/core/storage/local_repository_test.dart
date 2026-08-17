import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/daughter_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies local persistence against the real preferences implementation seam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('saved profile and story survive a repository reopen', () async {
    final repository = await LocalRepository.open();
    final profile = const DaughterProfile(
      name: 'Miko',
      age: 7,
      photoBase64: 'cHJpdmF0ZS1waG90bw==',
    );
    final story = _story();

    await repository.saveProfile(profile);
    await repository.saveStories(<StoryBook>[story]);
    final reopened = await LocalRepository.open();
    final state = await reopened.readState();

    expect(state.profile?.name, 'Miko');
    expect(state.profile?.photoBase64, profile.photoBase64);
    expect(state.stories.single.toJson(), story.toJson());
  });

  test(
    'clearing personal data preserves the selected interface locale',
    () async {
      final repository = await LocalRepository.open();
      await repository.saveLocale(const Locale('sv'));
      await repository.saveProfile(
        const DaughterProfile(name: 'Miko', age: 7, photoBase64: 'cGhvdG8='),
      );
      await repository.saveStories(<StoryBook>[_story()]);

      await repository.clearAll();
      final state = await repository.readState();

      expect(state.locale.languageCode, 'sv');
      expect(state.profile, isNull);
      expect(state.stories, isEmpty);
    },
  );

  test(
    'malformed profile JSON is reported without deleting stored bytes',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'daughter_profile': jsonEncode(<String, Object>{'name': 'Miko'}),
      });
      final repository = await LocalRepository.open();

      expect(repository.readState, throwsA(isA<LocalDataFormatException>()));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('daughter_profile'), isTrue);
    },
  );
}

/// Builds a complete book so persistence tests exercise nested model decoding.
StoryBook _story() {
  return StoryBook(
    id: 'story-1',
    createdAt: DateTime.utc(2026, 8, 17),
    content: StoryContent(
      title: 'Moon Garden',
      request: const StoryRequest(
        heroName: 'Miko',
        theme: 'moon garden',
        moral: 'kindness',
        presentation: StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.watercolor,
        ),
      ),
      pages: const <StoryPage>[
        StoryPage(
          number: 1,
          text: 'A beginning.',
          sceneDescription: 'A garden.',
        ),
      ],
    ),
  );
}
