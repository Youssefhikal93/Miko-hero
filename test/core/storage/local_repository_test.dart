import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
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
        ),
        ChildProfile(
          id: 'abbas',
          name: 'Abbas',
          age: 9,
          photoBase64: 'c2Vjb25kLXBob3Rv',
        ),
      ];
      final story = _story(profileId: 'abbas', heroName: 'Abbas');

      await repository.saveProfiles(profiles);
      await repository.saveStories(<StoryBook>[story]);
      final reopened = await LocalRepository.open();
      final state = await reopened.readState();

      expect(state.profiles.map((profile) => profile.heroName), <String>[
        'Miko hero',
        'Abbas hero',
      ]);
      expect(state.storiesForProfile('miko'), isEmpty);
      expect(state.storiesForProfile('abbas').single.toJson(), story.toJson());
    },
  );

  test(
    'clearing family data preserves the selected interface locale',
    () async {
      final repository = await LocalRepository.open();
      await repository.saveLocale(const Locale('sv'));
      await repository.saveProfiles(const <ChildProfile>[
        ChildProfile(id: 'miko', name: 'Miko', age: 7, photoBase64: 'cGhvdG8='),
      ]);
      await repository.saveStories(<StoryBook>[
        _story(profileId: 'miko', heroName: 'Miko'),
      ]);

      await repository.clearAll();
      final state = await repository.readState();

      expect(state.locale.languageCode, 'sv');
      expect(state.profiles, isEmpty);
      expect(state.stories, isEmpty);
    },
  );

  test('single-profile storage migrates with its existing stories', () async {
    final legacyStory = _story(
      profileId: 'discarded-during-legacy-encoding',
      heroName: 'Miko',
    ).toJson();
    final content = legacyStory['content']! as Map<String, Object>;
    final request = content['request']! as Map<String, Object>;
    request.remove('profileId');
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
    expect(
      migrated.stories.single.content.request.profileId,
      legacyChildProfileId,
    );
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
}

/// Builds a complete book so persistence tests exercise nested model decoding.
StoryBook _story({required String profileId, required String heroName}) {
  return StoryBook(
    id: 'story-$profileId',
    createdAt: DateTime.utc(2026, 8, 17),
    content: StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
        profileId: profileId,
        heroName: heroName,
        theme: 'moon garden',
        moral: 'kindness',
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
