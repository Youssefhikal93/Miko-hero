import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';
import 'package:miko_hero/core/backup/story_share_file_service.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/library/story_share_controller.dart';

import '../../support/seeded_device.dart';

/// Verifies that one story can travel between devices without duplicates.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    await _storeFamily();
    final codec = StoryShareCodec(deriver: _fakeBackupKey);
    final bytes = await codec.encode(
      SharedStory(
        story: _story(profileId: 'far-away-child'),
        heroName: 'Maya',
      ),
      'family-safe-password',
    );

    await _pumpLibrary(tester, codec, _FakeStoryFiles(bytes));

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
    await seedDevice(
      profiles: <ChildProfile>[child()],
      activeProfileId: 'miko',
    );
    final backup = await EncryptedBackupCodec(deriver: _fakeBackupKey).encode(
      (await (await LocalRepository.open()).readState()),
      'family-safe-password',
    );

    await _pumpLibrary(
      tester,
      StoryShareCodec(deriver: _fakeBackupKey),
      _FakeStoryFiles(backup),
    );

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

/// Opens the shelf with in-process crypto and a fake file picker.
Future<void> _pumpLibrary(
  WidgetTester tester,
  StoryShareCodec codec,
  _FakeStoryFiles files,
) {
  return pumpApp(
    tester,
    route: '/library',
    overrides: [
      storyShareCodecProvider.overrideWithValue(codec),
      storyShareFileServiceProvider.overrideWithValue(files),
    ],
  );
}

/// Stores the two children an imported story can be attached to.
Future<void> _storeFamily({List<StoryBook> stories = const <StoryBook>[]}) {
  return seedDevice(
    profiles: <ChildProfile>[
      child(),
      child(id: 'abbas', name: 'Abbas', gender: ChildGender.boy),
    ],
    stories: stories,
    activeProfileId: 'miko',
  );
}

/// Opens a container over real persisted state with two saved child profiles.
Future<ProviderContainer> _familyContainer({
  List<StoryBook> stories = const <StoryBook>[],
}) async {
  await _storeFamily(stories: stories);
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

/// Builds one approved two-page book owned by [profileId].
StoryBook _story({required String profileId}) {
  return book(
    id: 'story-moon',
    profileId: profileId,
    title: 'Moon Garden',
    heroName: 'Maya',
    theme: 'moon garden',
    createdAt: DateTime.utc(2026, 8, 18),
    style: IllustrationStyle.watercolor,
    pages: <StoryPage>[
      storyPage(1, 'A kind beginning.', scene: 'A moonlit garden.'),
      storyPage(2, 'A gentle ending.', scene: 'A sleeping garden.'),
    ],
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
