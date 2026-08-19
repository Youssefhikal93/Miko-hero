import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Verifies single-story file confidentiality, integrity, and format identity.
void main() {
  const password = 'family-safe-password';

  test('a shared story survives the round trip unchanged', () async {
    final codec = StoryShareCodec();
    final original = SharedStory(story: _story(), heroName: 'Miko');

    final encrypted = await codec.encode(original, password);
    final restored = await codec.decode(encrypted, password);

    expect(restored.toJson(), original.toJson());
    expect(restored.heroName, 'Miko');
    expect(restored.pageCount, 2);
    expect(restored.story.reviewStatus, StoryReviewStatus.draft);
    expect(restored.story.collections, <String>['Bedtime']);
    expect(utf8.decode(encrypted), isNot(contains('Moon Garden')));
    expect(utf8.decode(encrypted), isNot(contains('A kind beginning')));
  });

  test('a story file carries no reference photo', () {
    final shared = SharedStory(story: _story(), heroName: 'Miko');

    final payload = jsonEncode(shared.toJson());

    expect(payload, isNot(contains('photoBase64')));
    expect(payload, isNot(contains('cHJpdmF0ZS1waG90bw==')));
  });

  test('a wrong password cannot decrypt a shared story', () async {
    final codec = StoryShareCodec();
    final encrypted = await codec.encode(
      SharedStory(story: _story(), heroName: 'Miko'),
      password,
    );

    expect(
      codec.decode(encrypted, 'different-password'),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test(
    'changed story ciphertext fails authenticated integrity checks',
    () async {
      final codec = StoryShareCodec();
      final encrypted = await codec.encode(
        SharedStory(story: _story(), heroName: 'Miko'),
        password,
      );
      final envelope =
          jsonDecode(utf8.decode(encrypted)) as Map<String, dynamic>;
      final cipher = envelope['cipher'] as Map<String, dynamic>;
      final payload = base64Decode(cipher['payload'] as String);
      payload[payload.length ~/ 2] ^= 1;
      cipher['payload'] = base64Encode(payload);
      final changed = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));

      expect(
        codec.decode(changed, password),
        throwsA(isA<BackupAuthenticationException>()),
      );
    },
  );

  test('a full backup and a story file can never be confused', () async {
    final backupCodec = EncryptedBackupCodec();
    final storyCodec = StoryShareCodec();
    final backupBytes = await backupCodec.encode(_familyState(), password);
    final storyBytes = await storyCodec.encode(
      SharedStory(story: _story(), heroName: 'Miko'),
      password,
    );

    await expectLater(
      storyCodec.decode(backupBytes, password),
      throwsA(isA<BackupFormatException>()),
    );
    await expectLater(
      backupCodec.decode(storyBytes, password),
      throwsA(isA<BackupFormatException>()),
    );
    expect(
      jsonDecode(utf8.decode(storyBytes)),
      containsPair('format', storyShareEnvelopeFormat),
    );
    expect(
      jsonDecode(utf8.decode(backupBytes)),
      containsPair('format', backupEnvelopeFormat),
    );
  });

  test('a story file from a newer app version is refused', () {
    expect(
      () => SharedStory.fromJson(<String, Object?>{
        'schemaVersion': appStateSchemaVersion + 1,
        'heroName': 'Miko',
        'story': _story().toJson(),
      }),
      throwsA(isA<UnsupportedSchemaVersionException>()),
    );
  });

  test('an imported story is re-attached to the chosen profile', () {
    final shared = SharedStory(story: _story(), heroName: 'Miko');

    final imported = shared.storyForProfile('abbas');

    expect(imported.content.request.profileId, 'abbas');
    expect(imported.content.request.heroName, 'Miko');
    expect(imported.id, shared.story.id);
    expect(imported.reviewStatus, StoryReviewStatus.draft);
    expect(shared.story.content.request.profileId, 'miko');
  });
}

/// Builds one complete two-page story that keeps its own review metadata.
StoryBook _story() {
  return StoryBook(
    id: 'story-moon',
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
        StoryPage(
          number: 2,
          text: 'A gentle ending.',
          sceneDescription: 'A sleeping garden.',
        ),
      ],
    ),
    reviewStatus: StoryReviewStatus.draft,
    collections: const <String>['Bedtime'],
  );
}

/// Builds a complete family snapshot used by the cross-format assertion.
AppState _familyState() {
  return AppState.validated(
    locale: const Locale('en'),
    profiles: const <ChildProfile>[
      ChildProfile(
        id: 'miko',
        name: 'Miko',
        legacyAge: 7,
        photoBase64: 'cHJpdmF0ZS1waG90bw==',
        gender: ChildGender.girl,
        themeColorValue: roseProfileThemeColorValue,
        hasCustomThemeColor: false,
      ),
    ],
    stories: <StoryBook>[_story()],
    activeProfileId: 'miko',
  );
}
