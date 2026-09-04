import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';
import 'package:miko_hero/core/files/encrypted_file_flow.dart';
import 'package:miko_hero/core/files/encrypted_file_picker.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';

import '../../support/fake_encrypted_file_picker.dart';

const _password = 'family-safe-password';

/// Verifies the one flow backups and story files both travel through.
///
/// The real codecs run — only the platform dialogs are replaced — so what these
/// tests read back is what a parent would actually receive: an openable file
/// under a name a file system accepts, and one typed reason per way the flow
/// can refuse.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an exported story file opens again under a bounded name', () async {
    final picker = FakeEncryptedFilePicker();
    final flow = _storyFlow(picker);
    final shared = SharedStory(story: _story(), heroName: 'Miko');

    final saved = await flow.export(
      shared,
      _password,
      dialogTitle: 'Save story',
    );

    expect(saved, isTrue);
    expect(picker.savedFileName, 'Moon Garden.iamhero-story');
    final reopened = await _storyCodec.decode(picker.savedBytes!, _password);
    expect(reopened.story.id, 'story-moon');
    expect(reopened.heroName, 'Miko');
  });

  test('a title no file system would accept still earns a name', () async {
    final picker = FakeEncryptedFilePicker();
    final flow = _storyFlow(picker);
    final long = 'Moon/Garden: <the*very?long|tale>' * 8;

    await flow.export(
      SharedStory(
        story: _story(title: long),
        heroName: 'Miko',
      ),
      _password,
      dialogTitle: 'Save story',
    );

    final stem = picker.savedFileName!.split('.').first;
    expect(stem.runes.length, lessThanOrEqualTo(maximumFileStemRunes));
    expect(stem, isNot(matches(RegExp(r'''[<>:"/\\|?*\x00-\x1F]'''))));
    expect(picker.savedFileName, endsWith('.iamhero-story'));
  });

  test(
    'a punctuation-only title falls back rather than name nothing',
    () async {
      final picker = FakeEncryptedFilePicker();

      await _storyFlow(picker).export(
        SharedStory(
          story: _story(title: '<<>>'),
          heroName: 'Miko',
        ),
        _password,
        dialogTitle: 'Save story',
      );

      expect(picker.savedFileName, '$fallbackFileStem.iamhero-story');
    },
  );

  test('a backup opened as a story file is refused as unsupported', () async {
    final backup = await _backupCodec.encode(_state(), _password);
    final picker = FakeEncryptedFilePicker(
      picked: backup,
      pickedName: 'family.iamhero',
    );

    await expectLater(
      _storyFlow(picker).import(askPassword: (_) async => _password),
      throwsA(
        isA<EncryptedFileException>().having(
          (error) => error.reason,
          'reason',
          EncryptedFileFailure.unsupportedFile,
        ),
      ),
    );
  });

  test('a wrong password is told apart from a foreign file', () async {
    final story = await _storyCodec.encode(
      SharedStory(story: _story(), heroName: 'Miko'),
      _password,
    );
    final picker = FakeEncryptedFilePicker(picked: story);

    await expectLater(
      _storyFlow(picker).import(askPassword: (_) async => 'wrong-password-1'),
      throwsA(
        isA<EncryptedFileException>().having(
          (error) => error.reason,
          'reason',
          EncryptedFileFailure.wrongPassword,
        ),
      ),
    );
  });

  test('a selection over the cap is refused before it is decoded', () async {
    final picker = FakeEncryptedFilePicker(
      picked: Uint8List(maximumBackupBytes + 1),
    );

    await expectLater(
      _storyFlow(picker).import(askPassword: (_) async => _password),
      throwsA(
        isA<EncryptedFileException>().having(
          (error) => error.reason,
          'reason',
          EncryptedFileFailure.tooLarge,
        ),
      ),
    );
  });

  test('dismissing the picker imports nothing and asks nothing', () async {
    final picker = FakeEncryptedFilePicker();
    var asked = false;

    final imported = await _storyFlow(picker).import(
      askPassword: (_) async {
        asked = true;
        return _password;
      },
    );

    expect(imported, isNull);
    expect(asked, isFalse, reason: 'no file, so no password to ask for');
  });

  test('dismissing the password prompt imports nothing', () async {
    final story = await _storyCodec.encode(
      SharedStory(story: _story(), heroName: 'Miko'),
      _password,
    );
    final picker = FakeEncryptedFilePicker(picked: story);

    final imported = await _storyFlow(
      picker,
    ).import(askPassword: (_) async => null);

    expect(imported, isNull);
  });

  test('cancelling the save writes nothing and reports it', () async {
    final picker = FakeEncryptedFilePicker(acceptsSave: false);

    final saved = await _storyFlow(picker).export(
      SharedStory(story: _story(), heroName: 'Miko'),
      _password,
      dialogTitle: 'Save story',
    );

    expect(saved, isFalse);
    expect(picker.savedBytes, isNull);
  });

  test('a backup travels out and back through the same flow', () async {
    final picker = FakeEncryptedFilePicker();
    final flow = _backupFlow(picker);

    await flow.export(_state(), _password, dialogTitle: 'Save backup');
    picker
      ..picked = picker.savedBytes
      ..pickedName = picker.savedFileName!;
    final restored = await flow.import(askPassword: (_) async => _password);

    expect(picker.savedFileName, matches(RegExp(r'^iam-hero-backup-')));
    expect(picker.savedFileName, endsWith('.$backupFileExtension'));
    expect(picker.pickedExtensions, <String>[backupFileExtension]);
    expect(restored!.profiles.single.id, 'miko');
    expect(restored.stories.single.id, 'story-moon');
  });
}

/// The single-story codec with the isolate hop replaced, for speed.
final _storyCodec = StoryShareCodec(deriver: _fakeBackupKey);

/// The whole-family codec with the isolate hop replaced, for speed.
final _backupCodec = EncryptedBackupCodec(deriver: _fakeBackupKey);

/// The single-story configuration, exactly as the app composes it.
EncryptedFileFlow<SharedStory> _storyFlow(FakeEncryptedFilePicker picker) {
  return EncryptedFileFlow<SharedStory>(
    picker: picker,
    extension: storyShareFileExtension,
    maximumBytes: maximumBackupBytes,
    encode: _storyCodec.encode,
    decode: _storyCodec.decode,
    fileStem: (shared) => shared.story.content.title,
  );
}

/// The whole-family configuration, exactly as the app composes it.
EncryptedFileFlow<AppState> _backupFlow(FakeEncryptedFilePicker picker) {
  return EncryptedFileFlow<AppState>(
    picker: picker,
    extension: backupFileExtension,
    maximumBytes: maximumBackupBytes,
    encode: _backupCodec.encode,
    decode: _backupCodec.decode,
    fileStem: (_) {
      final date = DateTime.now().toUtc().toIso8601String().split('T').first;
      return 'iam-hero-backup-$date';
    },
  );
}

/// One family snapshot with a single child and a single book.
AppState _state() {
  return AppState.validated(
    locale: AppLanguage.english.locale,
    profiles: const <ChildProfile>[
      ChildProfile(
        id: 'miko',
        name: 'Miko',
        legacyAge: 8,
        photoBase64: 'cGhvdG8=',
        gender: ChildGender.girl,
        themeColorValue: roseProfileThemeColorValue,
        hasCustomThemeColor: false,
      ),
    ],
    stories: <StoryBook>[_story()],
    activeProfileId: 'miko',
  );
}

/// Builds one approved book belonging to the only child in [_state].
StoryBook _story({String title = 'Moon Garden'}) {
  return StoryBook(
    id: 'story-moon',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: title,
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
