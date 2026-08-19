import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies local persistence against the real preferences implementation seam.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'multiple profiles and their stories survive a repository reopen',
    () async {
      final repository = await LocalRepository.open();
      const profiles = <ChildProfile>[
        ChildProfile(
          id: 'miko',
          name: 'Miko',
          age: 7,
          photoBase64: 'cHJpdmF0ZS1waG90bw==',
          gender: ChildGender.girl,
          themeColorValue: roseProfileThemeColorValue,
          hasCustomThemeColor: false,
        ),
        ChildProfile(
          id: 'abbas',
          name: 'Abbas',
          age: 9,
          photoBase64: 'c2Vjb25kLXBob3Rv',
          gender: ChildGender.boy,
          themeColorValue: _customPurpleThemeColorValue,
          hasCustomThemeColor: true,
          storyPreferences: ChildStoryPreferences(
            defaultLanguage: AppLanguage.somali,
            favoriteThings: 'trains and stars',
            recurringWorld: 'Golden Cloud Kingdom',
            excludedTopics: <SafetyTopic>{SafetyTopic.violence},
          ),
        ),
      ];
      final story = _story(
        profileId: 'abbas',
        heroName: 'Abbas',
        gender: ChildGender.boy,
      ).withFavorite(true).withCollections(<String>['Bedtime', 'Space']);

      await repository.saveProfiles(profiles);
      await repository.saveActiveProfileId('abbas');
      await repository.saveStories(<StoryBook>[story]);
      final reopened = await LocalRepository.open();
      final state = await reopened.readState();

      expect(state.profiles.map((profile) => profile.heroName), <String>[
        'Miko hero',
        'Abbas hero',
      ]);
      expect(state.storiesForProfile('miko'), isEmpty);
      expect(state.storiesForProfile('abbas').single.toJson(), story.toJson());
      expect(state.activeProfile?.gender, ChildGender.boy);
      expect(
        state.activeProfile?.themeColorValue,
        _customPurpleThemeColorValue,
      );
      expect(state.activeProfile?.hasCustomThemeColor, isTrue);
      expect(
        state.activeProfile?.storyPreferences.defaultLanguage,
        AppLanguage.somali,
      );
      expect(
        state.activeProfile?.storyPreferences.excludedTopics,
        const <SafetyTopic>{SafetyTopic.violence},
      );
    },
  );

  test(
    'clearing family data preserves the selected interface locale',
    () async {
      final repository = await LocalRepository.open();
      await repository.saveLocale(const Locale('sv'));
      await repository.saveProfiles(const <ChildProfile>[
        ChildProfile(
          id: 'miko',
          name: 'Miko',
          age: 7,
          photoBase64: 'cGhvdG8=',
          gender: ChildGender.girl,
          themeColorValue: roseProfileThemeColorValue,
          hasCustomThemeColor: false,
        ),
      ]);
      await repository.saveStories(<StoryBook>[
        _story(profileId: 'miko', heroName: 'Miko', gender: ChildGender.girl),
      ]);
      await repository.saveActiveProfileId('miko');

      await repository.clearAll();
      final state = await repository.readState();

      expect(state.locale.languageCode, 'sv');
      expect(state.profiles, isEmpty);
      expect(state.stories, isEmpty);
      expect(state.activeProfileId, isNull);
    },
  );

  test(
    'restoring family state preserves PIN and removes a stale active hero',
    () async {
      final repository = await LocalRepository.open();
      const oldProfile = ChildProfile(
        id: 'old-hero',
        name: 'Old hero',
        age: 7,
        photoBase64: 'cGhvdG8=',
        gender: ChildGender.girl,
        themeColorValue: roseProfileThemeColorValue,
        hasCustomThemeColor: false,
      );
      final security = ParentSecurityRecord(
        saltBase64: base64Encode(List<int>.filled(16, 1)),
        verifierBase64: base64Encode(List<int>.filled(32, 2)),
      );
      await repository.saveProfiles(const <ChildProfile>[oldProfile]);
      await repository.saveActiveProfileId(oldProfile.id);
      await repository.saveParentSecurity(security);
      final replacement = AppState.validated(
        locale: const Locale('so'),
        profiles: const <ChildProfile>[],
        stories: const <StoryBook>[],
        activeProfileId: null,
      );

      await repository.replaceState(replacement);
      final reopened = await LocalRepository.open();
      final restored = await reopened.readState();
      final preservedSecurity = await reopened.readParentSecurity();

      expect(restored.toJson(), replacement.toJson());
      expect(preservedSecurity?.toJson(), security.toJson());
    },
  );

  test('single-profile storage migrates with its existing stories', () async {
    final legacyStory = _story(
      profileId: 'discarded-during-legacy-encoding',
      heroName: 'Miko',
      gender: ChildGender.girl,
    ).toJson();
    final content = legacyStory['content']! as Map<String, Object>;
    final request = content['request']! as Map<String, Object>;
    final prompt = request.remove('prompt')! as Map<String, Object>;
    request['theme'] = prompt['theme']!;
    request['moral'] = prompt['moral']!;
    request.remove('profileId');
    request.remove('gender');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daughter_profile': jsonEncode(<String, Object>{
        'name': 'Miko',
        'age': 7,
        'photoBase64': 'cGhvdG8=',
      }),
      'story_library': jsonEncode(<Map<String, Object>>[legacyStory]),
    });
    final repository = await LocalRepository.open();

    final migrated = await repository.readState();
    final reopened = await LocalRepository.open();
    final persisted = await reopened.readState();

    expect(migrated.profiles.single.id, legacyChildProfileId);
    expect(migrated.profiles.single.gender, ChildGender.girl);
    expect(
      migrated.profiles.single.themeColorValue,
      roseProfileThemeColorValue,
    );
    expect(migrated.profiles.single.hasCustomThemeColor, isFalse);
    expect(migrated.activeProfileId, legacyChildProfileId);
    expect(
      migrated.stories.single.content.request.profileId,
      legacyChildProfileId,
    );
    expect(migrated.stories.single.content.request.gender, ChildGender.girl);
    expect(migrated.stories.single.reviewStatus, StoryReviewStatus.approved);
    expect(persisted.storiesForProfile(legacyChildProfileId), hasLength(1));
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('daughter_profile'), isFalse);
    expect(preferences.containsKey('child_profiles'), isTrue);
  });

  test(
    'malformed profile list is reported without deleting stored bytes',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'child_profiles': jsonEncode(<Map<String, Object>>[
          <String, Object>{'id': 'miko', 'name': 'Miko'},
        ]),
      });
      final repository = await LocalRepository.open();

      expect(repository.readState, throwsA(isA<LocalDataFormatException>()));
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.containsKey('child_profiles'), isTrue);
    },
  );

  test(
    'current profiles without gender remain unspecified for parent choice',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'child_profiles': jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'id': 'abbas',
            'name': 'Abbas',
            'age': 9,
            'photoBase64': 'cGhvdG8=',
          },
        ]),
      });
      final repository = await LocalRepository.open();

      final state = await repository.readState();

      expect(state.profiles.single.gender, ChildGender.unspecified);
      expect(
        state.profiles.single.themeColorValue,
        goldenProfileThemeColorValue,
      );
      expect(state.profiles.single.hasCustomThemeColor, isFalse);
      expect(state.activeProfileId, isNull);
    },
  );
}

/// Custom value proves storage does not collapse colors back to gender defaults.
const _customPurpleThemeColorValue = 0xFF9C6BFF;

/// Builds a complete book so persistence tests exercise nested model decoding.
StoryBook _story({
  required String profileId,
  required String heroName,
  required ChildGender gender,
}) {
  return StoryBook(
    id: 'story-$profileId',
    createdAt: DateTime.utc(2026, 8, 17),
    content: StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
        hero: StoryHero(profileId: profileId, name: heroName, gender: gender),
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
          text: 'A beginning.',
          sceneDescription: 'A garden.',
        ),
      ],
    ),
  );
}
