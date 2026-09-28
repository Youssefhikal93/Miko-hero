import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/reader/story_export_controller.dart';

import '../../support/fake_encrypted_file_picker.dart';
import '../../support/in_memory_illustration_store.dart';

/// A one-pixel PNG, so a cached picture really carries the PNG magic bytes.
const _pngPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Verifies what a parent actually receives when exporting a drawn story.
///
/// The real PDF renderer runs with real bundled fonts; only the image cache and
/// the platform save dialog are replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the exported PDF carries every cached page picture', () async {
    final store = InMemoryIllustrationStore();
    await store.write('illustration-1', base64Decode(_pngPixel));
    await store.write('illustration-2', base64Decode(_pngPixel));
    final drawn = FakeEncryptedFilePicker();
    final textOnly = FakeEncryptedFilePicker();

    await _export(store, drawn);
    await _export(InMemoryIllustrationStore(), textOnly);

    expect(ascii.decode(drawn.savedBytes!.take(4).toList()), '%PDF');
    expect(drawn.savedFileName, 'Miko Hero.pdf');
    expect(drawn.savedBytes!.length, greaterThan(textOnly.savedBytes!.length));
  });

  test('an unreadable cache still exports the story as text', () async {
    final store = InMemoryIllustrationStore()
      ..unwritableIllustrationId = 'illustration-1';
    final refused = FakeEncryptedFilePicker();
    final textOnly = FakeEncryptedFilePicker();

    await _export(store, refused);
    await _export(InMemoryIllustrationStore(), textOnly);

    expect(ascii.decode(refused.savedBytes!.take(4).toList()), '%PDF');
    expect(refused.savedBytes!.length, textOnly.savedBytes!.length);
  });

  test('a story still awaiting review is never exported', () async {
    final file = FakeEncryptedFilePicker();
    final container = _container(InMemoryIllustrationStore(), file);
    addTearDown(container.dispose);

    await expectLater(
      container
          .read(storyExportControllerProvider)
          .export(_story(reviewStatus: StoryReviewStatus.draft), 'Save story'),
      throwsStateError,
    );
    expect(file.savedBytes, isNull);
  });
}

/// Exports one drawn story through the real controller and PDF renderer.
Future<void> _export(
  InMemoryIllustrationStore store,
  FakeEncryptedFilePicker file,
) async {
  final container = _container(store, file);
  addTearDown(container.dispose);
  final saved = await container
      .read(storyExportControllerProvider)
      .export(_story(), 'Save story');
  expect(saved, isTrue);
}

/// Builds a scope with only the image cache and the save dialog replaced.
ProviderContainer _container(
  InMemoryIllustrationStore store,
  FakeEncryptedFilePicker file,
) {
  return ProviderContainer(
    overrides: [
      illustrationStoreProvider.overrideWithValue(store),
      encryptedFilePickerProvider.overrideWithValue(file),
    ],
  );
}

/// Creates one bridge-generated book whose pages name their drawn pictures.
StoryBook _story({
  StoryReviewStatus reviewStatus = StoryReviewStatus.approved,
}) {
  return StoryBook(
    id: 'story-drawn',
    createdAt: DateTime.utc(2026, 8, 18),
    reviewStatus: reviewStatus,
    content: StoryContent(
      title: 'Miko Hero',
      request: _request(),
      pages: <StoryPage>[
        StoryPage(
          number: 1,
          text: 'Miko found a kind dragon.',
          sceneDescription: _scene('illustration-1'),
        ),
        StoryPage(
          number: 2,
          text: 'He helped his friends bravely.',
          sceneDescription: _scene('illustration-2'),
        ),
      ],
    ),
  );
}

/// Encodes one page's bridge identities the way a synced story stores them.
String _scene(String illustrationId) {
  return BridgeStoryProvenance(
    scene: 'A kind hero greets a dragon',
    storyId: 'bridge-story-1',
    illustrationId: illustrationId,
  ).toSceneDescription();
}

/// Creates generation context without bypassing production model validation.
StoryRequest _request() {
  return StoryRequest(
    hero: const StoryHero(
      profileId: 'profile-miko',
      name: 'Miko',
      gender: ChildGender.boy,
    ),
    prompt: const StoryPrompt(
      theme: 'Stars',
      moral: 'Kindness',
      preferences: ChildStoryPreferences(),
    ),
    presentation: StoryPresentation(
      language: AppLanguage.english,
      length: StoryLength.short,
      style: IllustrationStyle.pictureBook,
    ),
  );
}
