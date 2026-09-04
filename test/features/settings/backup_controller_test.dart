import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/files/encrypted_file_flow.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/backup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_encrypted_file_picker.dart';

const _password = 'family-safe-password';

/// Verifies the whole backup path above the codec, with real persistence.
///
/// The codec and the repository are the real ones; only the platform dialogs
/// and the Argon2id isolate are replaced. So what is asserted is what a parent
/// would get: a file that opens again on a device holding a different family,
/// and a restore that survives reopening the app.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a backup exported here restores onto another family', () async {
    final picker = FakeEncryptedFilePicker();
    final source = await _container(picker, childName: 'Miko');
    final bytes = await source
        .read(backupControllerProvider)
        .createBackup(_password);
    await source.read(backupControllerProvider).saveBackup(bytes, 'Save');

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final elsewhere = await _container(
      FakeEncryptedFilePicker(
        picked: picker.savedBytes,
        pickedName: picker.savedFileName!,
      ),
      childName: 'Someone else',
    );
    final controller = elsewhere.read(backupControllerProvider);
    final restored = await controller.openBackup(
      askPassword: (_) async => _password,
    );
    await controller.restore(restored!);

    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.profiles.single.name, 'Miko');
    expect(reopened.stories.single.id, 'story-moon');
    expect(
      elsewhere.read(appControllerProvider).requireValue.profiles.single.name,
      'Miko',
    );
  });

  test('a wrong password restores nothing and says which reason', () async {
    final picker = FakeEncryptedFilePicker();
    final container = await _container(picker, childName: 'Miko');
    final controller = container.read(backupControllerProvider);
    final bytes = await controller.createBackup(_password);
    picker
      ..picked = bytes
      ..pickedName = 'family.iamhero';

    await expectLater(
      controller.openBackup(askPassword: (_) async => 'not-the-password'),
      throwsA(
        isA<EncryptedFileException>().having(
          (error) => error.reason,
          'reason',
          EncryptedFileFailure.wrongPassword,
        ),
      ),
    );
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.profiles.single.name, 'Miko');
  });

  test('dismissing the picker leaves this device untouched', () async {
    final container = await _container(
      FakeEncryptedFilePicker(),
      childName: 'Miko',
    );

    final restored = await container
        .read(backupControllerProvider)
        .openBackup(askPassword: (_) async => _password);

    expect(restored, isNull);
    expect(
      container.read(appControllerProvider).requireValue.profiles.single.name,
      'Miko',
    );
  });
}

/// Opens a container over real persistence holding one child and one book.
Future<ProviderContainer> _container(
  FakeEncryptedFilePicker picker, {
  required String childName,
}) async {
  final repository = await LocalRepository.open();
  await repository.saveProfiles(<ChildProfile>[
    ChildProfile(
      id: 'miko',
      name: childName,
      legacyAge: 8,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
    ),
  ]);
  await repository.saveStories(<StoryBook>[_story()]);
  await repository.saveActiveProfileId('miko');
  final container = ProviderContainer(
    overrides: [
      encryptedFilePickerProvider.overrideWithValue(picker),
      encryptedBackupCodecProvider.overrideWithValue(
        EncryptedBackupCodec(deriver: _fakeBackupKey),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  return container;
}

/// Builds one approved book belonging to the container's only child.
StoryBook _story() {
  return StoryBook(
    id: 'story-moon',
    createdAt: DateTime.utc(2026, 8, 18),
    content: const StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
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
      pages: <StoryPage>[
        StoryPage(
          number: 1,
          text: 'A kind beginning.',
          sceneDescription: 'A moonlit garden.',
        ),
      ],
    ),
    reviewStatus: StoryReviewStatus.approved,
  );
}

/// Stands in for Argon2id so this suite stays about the flow, not key strength.
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
