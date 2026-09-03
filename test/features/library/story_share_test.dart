import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';
import 'package:miko_hero/core/backup/story_share_file_service.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/library/story_share_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies that one story can travel between devices without duplicates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'an imported story is stored for the profile the parent chose',
    () async {
      final container = await _familyContainer();
      final controller = container.read(storyShareControllerProvider);

      await controller.importStory(
        SharedStory(
          story: _story(profileId: 'far-away-child'),
          heroName: 'Maya',
        ),
        'abbas',
      );

      final reopened = await (await LocalRepository.open()).readState();
      final imported = reopened.stories.single;
      expect(imported.content.request.profileId, 'abbas');
      expect(imported.content.request.heroName, 'Maya');
      expect(imported.reviewStatus, StoryReviewStatus.approved);
      expect(reopened.storiesForProfile('abbas'), hasLength(1));
      expect(reopened.storiesForProfile('miko'), isEmpty);
    },
  );

  test('importing the same story twice is refused', () async {
    final container = await _familyContainer();
    final controller = container.read(storyShareControllerProvider);
    final shared = SharedStory(
      story: _story(profileId: 'far-away-child'),
      heroName: 'Maya',
    );
    await controller.importStory(shared, 'miko');

    await expectLater(
      controller.importStory(shared, 'abbas'),
      throwsA(isA<DuplicateStoryException>()),
    );
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.stories, hasLength(1));
    expect(reopened.stories.single.content.request.profileId, 'miko');
  });

  test(
    'an exported story file carries the hero name of the local profile',
    () async {
      final container = await _familyContainer(
        stories: <StoryBook>[_story(profileId: 'miko')],
      );
      final controller = container.read(storyShareControllerProvider);
      final codec = StoryShareCodec(deriver: _fakeBackupKey);

      final bytes = await controller.createStoryFile(
        'story-moon',
        'family-safe-password',
      );
      final decoded = await codec.decode(bytes, 'family-safe-password');

      expect(decoded.heroName, 'Miko');
      expect(decoded.story.id, 'story-moon');
      expect(utf8.decode(bytes), isNot(contains('photoBase64')));
    },
  );

  testWidgets('a picked story file is previewed, imported, and readable', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_profile_id': 'miko',
      'child_profiles': jsonEncode(<Map<String, Object>>[
        _profileJson('miko', 'Miko', 'girl'),
        _profileJson('abbas', 'Abbas', 'boy'),
      ]),
    });
    final codec = StoryShareCodec(deriver: _fakeBackupKey);
    final bytes = await codec.encode(
      SharedStory(
        story: _story(profileId: 'far-away-child'),
        heroName: 'Maya',
      ),
      'family-safe-password',
    );
    appRouter.go('/library');

    await tester.pumpWidget(_app(codec, _FakeStoryFiles(bytes)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import story file'));
    await tester.pumpAndSettle();
    // The last field is the password dialog's; the first is the shelf search.
    await tester.enterText(find.byType(TextField).last, 'family-safe-password');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Import this story?'), findsOneWidget);
    expect(find.text('Pages: 2'), findsOneWidget);
    expect(find.text('Hero in the file: Maya'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('import-profile-abbas')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import story'));
    await tester.pumpAndSettle();

    expect(find.text('Story imported: Moon Garden'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbas hero'));
    await tester.pumpAndSettle();
    final storyTile = find.text('Moon Garden').first;
    await tester.ensureVisible(storyTile);
    await tester.pumpAndSettle();
    await tester.tap(storyTile);
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2'), findsOneWidget);
    expect(find.textContaining('A kind beginning.'), findsOneWidget);
  });

  testWidgets('a full backup file is refused by the story importer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_profile_id': 'miko',
      'child_profiles': jsonEncode(<Map<String, Object>>[
        _profileJson('miko', 'Miko', 'girl'),
      ]),
    });
    final backup = await EncryptedBackupCodec(deriver: _fakeBackupKey).encode(
      (await (await LocalRepository.open()).readState()),
      'family-safe-password',
    );
    appRouter.go('/library');

    await tester.pumpWidget(
      _app(StoryShareCodec(deriver: _fakeBackupKey), _FakeStoryFiles(backup)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import story file'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'family-safe-password');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('This is not a supported Iam - hero story file.'),
      findsOneWidget,
    );
    expect(find.text('Import this story?'), findsNothing);
  });
}

/// Builds the real application with in-process crypto and a fake file picker.
Widget _app(StoryShareCodec codec, _FakeStoryFiles files) {
  return ProviderScope(
    overrides: [
      storyShareCodecProvider.overrideWithValue(codec),
      storyShareFileServiceProvider.overrideWithValue(files),
    ],
    child: const IamHeroApp(),
  );
}

/// Opens a container over real persisted state with two saved child profiles.
Future<ProviderContainer> _familyContainer({
  List<StoryBook> stories = const <StoryBook>[],
}) async {
  final repository = await LocalRepository.open();
  await repository.saveProfiles(<ChildProfile>[
    _profile('miko', 'Miko', ChildGender.girl),
    _profile('abbas', 'Abbas', ChildGender.boy),
  ]);
  await repository.saveStories(stories);
  await repository.saveActiveProfileId('miko');
  final container = ProviderContainer(
    overrides: [
      storyShareCodecProvider.overrideWithValue(
        StoryShareCodec(deriver: _fakeBackupKey),
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  return container;
}

/// Platform file boundary replaced by bytes the test already prepared.
class _FakeStoryFiles extends StoryShareFileService {
  /// Creates a picker that always returns the supplied encrypted container.
  _FakeStoryFiles(this.bytes);

  /// Bytes handed to the import flow as if a parent had picked a file.
  final Uint8List bytes;

  /// Bytes the export flow asked to save, if any.
  Uint8List? savedBytes;

  @override
  /// Returns the prepared file without opening a platform dialog.
  Future<PickedStoryFile?> pickStory() async {
    return PickedStoryFile(name: 'moon-garden.iamhero-story', bytes: bytes);
  }

  @override
  /// Records the export instead of writing to the device.
  Future<bool> saveStory(
    Uint8List saved,
    String storyTitle,
    String dialogTitle,
  ) async {
    savedBytes = saved;
    return true;
  }
}

/// One private child profile stored the way the editor would save it.
ChildProfile _profile(String id, String name, ChildGender gender) {
  return ChildProfile(
    id: id,
    name: name,
    legacyAge: 7,
    photoBase64: 'cHJpdmF0ZS1waG90bw==',
    gender: gender,
    themeColorValue: defaultProfileThemeColorValue(gender),
    hasCustomThemeColor: false,
  );
}

/// The same profile as stored JSON, for widget tests that seed preferences.
Map<String, Object> _profileJson(String id, String name, String gender) {
  return <String, Object>{
    'id': id,
    'name': name,
    'age': 7,
    'photoBase64': _transparentPixel,
    'gender': gender,
  };
}

/// Builds one approved two-page book owned by [profileId].
StoryBook _story({required String profileId}) {
  return StoryBook(
    id: 'story-moon',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: 'Moon Garden',
      request: StoryRequest(
        hero: StoryHero(
          profileId: profileId,
          name: 'Maya',
          gender: ChildGender.girl,
        ),
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
  );
}

/// Stands in for Argon2id so the share tests stay fast.
///
/// The real derivation is covered by `story_share_codec_test.dart`; these tests
/// are about the import transaction, not key strength.
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

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
