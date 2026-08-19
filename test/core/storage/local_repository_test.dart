import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

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
          legacyAge: 7,
          photoBase64: 'cHJpdmF0ZS1waG90bw==',
          gender: ChildGender.girl,
          themeColorValue: roseProfileThemeColorValue,
          hasCustomThemeColor: false,
        ),
        ChildProfile(
          id: 'abbas',
          name: 'Abbas',
          legacyAge: 9,
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
          legacyAge: 7,
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
        legacyAge: 7,
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

  test('an encrypted backup restores byte for byte after a reload', () async {
    final repository = await LocalRepository.open();
    final codec = EncryptedBackupCodec(deriver: _fakeBackupKey);
    final original = AppState.validated(
      locale: const Locale('ar'),
      profiles: <ChildProfile>[_profile(birthDate: DateTime(2018, 6, 15))],
      stories: <StoryBook>[
        _story(profileId: 'miko', heroName: 'Miko', gender: ChildGender.girl),
      ],
      activeProfileId: 'miko',
    );

    final encrypted = await codec.encode(original, 'family-safe-password');
    final decoded = await codec.decode(encrypted, 'family-safe-password');
    await repository.replaceState(decoded);
    final reopened = await LocalRepository.open();
    final restored = await reopened.readState();

    expect(restored.toJson(), original.toJson());
    expect(restored.profiles.single.birthDate, DateTime(2018, 6, 15));
    expect(reopened.storedSchemaVersion, appStateSchemaVersion);
  });

  test(
    'a backup from a newer app version is refused before restoring',
    () async {
      final codec = EncryptedBackupCodec(deriver: _fakeBackupKey);
      final newerBackup = await codec.encode(
        _NewerSchemaState(_familyState()),
        'family-safe-password',
      );

      expect(
        codec.decode(newerBackup, 'family-safe-password'),
        throwsA(isA<UnsupportedSchemaVersionException>()),
      );
    },
  );

  test('a restore that fails midway rolls every key back', () async {
    final store = _CountingPreferencesStore();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    SharedPreferencesStorePlatform.instance = store;
    addTearDown(() {
      SharedPreferencesStorePlatform.instance =
          InMemorySharedPreferencesStore.empty();
    });
    final repository = await LocalRepository.open();
    final original = _familyState();
    await repository.replaceState(original);
    store.failOnWrite(3);

    await expectLater(
      repository.replaceState(
        AppState.validated(
          locale: const Locale('so'),
          profiles: const <ChildProfile>[],
          stories: const <StoryBook>[],
          activeProfileId: null,
        ),
      ),
      throwsA(isA<Exception>()),
    );
    final rolledBack = await repository.readState();

    expect(rolledBack.toJson(), original.toJson());
    expect(store.values['flutter.app_locale'], 'sv');
    expect(store.values['flutter.active_profile_id'], 'miko');
  });

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

/// Builds one validated profile, optionally carrying a chosen birth date.
ChildProfile _profile({DateTime? birthDate}) {
  return ChildProfile(
    id: 'miko',
    name: 'Miko',
    legacyAge: 8,
    birthDate: birthDate,
    photoBase64: 'cGhvdG8=',
    gender: ChildGender.girl,
    themeColorValue: roseProfileThemeColorValue,
    hasCustomThemeColor: false,
  );
}

/// Builds a complete family snapshot used by the restore transactions.
AppState _familyState() {
  return AppState.validated(
    locale: const Locale('sv'),
    profiles: <ChildProfile>[_profile(birthDate: DateTime(2018, 6, 15))],
    stories: <StoryBook>[
      _story(profileId: 'miko', heroName: 'Miko', gender: ChildGender.girl),
    ],
    activeProfileId: 'miko',
  );
}

/// Pretends to be a snapshot written by a future application version.
class _NewerSchemaState extends AppState {
  /// Wraps a real snapshot so only its declared schema version changes.
  _NewerSchemaState(AppState state)
    : super(
        locale: state.locale,
        profiles: state.profiles,
        stories: state.stories,
        activeProfileId: state.activeProfileId,
      );

  @override
  /// Claims a version this build cannot possibly understand.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      ...super.toJson(),
      'schemaVersion': appStateSchemaVersion + 1,
    };
  }
}

/// Preference store that fails one chosen write to prove restore rollback.
///
/// Extends the real platform store contract so the production
/// `SharedPreferences` code path, including its cache, behaves normally.
class _CountingPreferencesStore extends SharedPreferencesStorePlatform {
  /// Values as the platform would hold them, including the plugin key prefix.
  final Map<String, Object> values = <String, Object>{};

  int? _failingWrite;
  int _writes = 0;

  /// Makes only the [write]-th following write fail, like a transient error.
  void failOnWrite(int write) {
    _failingWrite = write;
    _writes = 0;
  }

  @override
  /// Records values unless this exact write is the one selected to fail.
  Future<bool> setValue(String valueType, String key, Object value) async {
    _writes++;
    if (_writes == _failingWrite) {
      throw Exception('Simulated preference write failure.');
    }
    values[key] = value;
    return true;
  }

  @override
  /// Deletes one stored value.
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }

  @override
  /// Drops every stored value.
  Future<bool> clear() async {
    values.clear();
    return true;
  }

  @override
  /// Returns a copy so callers cannot mutate the fake store directly.
  Future<Map<String, Object>> getAll() async {
    return Map<String, Object>.from(values);
  }
}

/// Stands in for Argon2id so restore tests stay fast.
///
/// The real derivation is covered by `encrypted_backup_codec_test.dart`; these
/// tests are about the storage transaction, not key strength.
Future<Uint8List> _fakeBackupKey(BackupKeyDerivation derivation) async {
  final passwordBytes = utf8.encode(derivation.password);
  return Uint8List.fromList(
    List<int>.generate(
      32,
      (index) =>
          (passwordBytes[index % passwordBytes.length] +
              derivation.salt[index % derivation.salt.length]) &
          0xFF,
    ),
  );
}

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
