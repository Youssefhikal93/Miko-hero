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

/// Verifies portable backup confidentiality, integrity, and schema handling.
void main() {
  const password = 'family-safe-password';

  test(
    'encrypted family snapshot restores without losing relationships',
    () async {
      final codec = EncryptedBackupCodec();
      final original = _familyState();

      final encrypted = await codec.encode(original, password);
      final restored = await codec.decode(encrypted, password);

      expect(restored.toJson(), original.toJson());
      expect(restored.profiles.single.birthDate, DateTime(2018, 6, 15));
      expect(restored.profiles.single.ageOn(DateTime(2026, 6, 15)), 8);
      expect(utf8.decode(encrypted), isNot(contains('cHJpdmF0ZS1waG90bw==')));
      expect(utf8.decode(encrypted), isNot(contains('Moon Garden')));
    },
  );

  test('wrong backup password cannot decrypt family data', () async {
    final codec = EncryptedBackupCodec();
    final encrypted = await codec.encode(_familyState(), password);

    expect(
      codec.decode(encrypted, 'different-password'),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('changed ciphertext fails authenticated integrity checks', () async {
    final codec = EncryptedBackupCodec();
    final encrypted = await codec.encode(_familyState(), password);
    final envelope = jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
    final cipher = envelope['cipher'] as Map<String, dynamic>;
    final payload = base64Decode(cipher['payload'] as String);
    payload[payload.length ~/ 2] ^= 1;
    cipher['payload'] = base64Encode(payload);
    final changed = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

    expect(
      codec.decode(changed, password),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('unsupported container is rejected before password derivation', () {
    final codec = EncryptedBackupCodec();
    final unsupported = Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object>{
          'format': 'iam-hero-backup',
          'version': 99,
        }),
      ),
    );

    expect(
      codec.decode(unsupported, password),
      throwsA(isA<BackupFormatException>()),
    );
  });
}

/// Builds real profile and story models to exercise the complete backup schema.
AppState _familyState() {
  final profile = ChildProfile(
    id: 'miko',
    name: 'Miko',
    legacyAge: 7,
    birthDate: DateTime(2018, 6, 15),
    photoBase64: 'cHJpdmF0ZS1waG90bw==',
    gender: ChildGender.girl,
    themeColorValue: roseProfileThemeColorValue,
    hasCustomThemeColor: false,
  );
  final story = StoryBook(
    id: 'moon-story',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: 'Moon Garden',
      request: const StoryRequest(
        hero: StoryHero(
          profileId: 'miko',
          name: 'Miko',
          gender: ChildGender.girl,
        ),
        prompt: StoryPrompt(
          theme: 'moon garden',
          moral: 'kindness',
          preferences: ChildStoryPreferences(),
        ),
        presentation: StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.watercolor,
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
  return AppState.validated(
    locale: const Locale('sv'),
    profiles: <ChildProfile>[profile],
    stories: <StoryBook>[story],
    activeProfileId: profile.id,
  );
}
