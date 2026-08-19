import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/backup/story_share_codec.dart';
import 'package:miko_hero/core/backup/story_share_file_service.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';

/// Supplies the authenticated encryption codec used by story share commands.
final storyShareCodecProvider = Provider<StoryShareCodec>((ref) {
  return StoryShareCodec();
});

/// Supplies cross-platform story-file selection and saving.
final storyShareFileServiceProvider = Provider<StoryShareFileService>((ref) {
  return StoryShareFileService();
});

/// Supplies single-story export and import commands to library widgets.
final storyShareControllerProvider = Provider<StoryShareController>(
  StoryShareController.new,
);

/// Coordinates encrypted story files, platform files, and local persistence.
class StoryShareController {
  /// Retains the provider scope used by the share and import transactions.
  StoryShareController(this._ref);

  final Ref _ref;

  /// Encrypts one stored story plus its hero name, without the child's photo.
  Future<Uint8List> createStoryFile(String storyId, String password) {
    final current = _currentState;
    final story = _requireStory(current, storyId);
    final profile = current.profileById(story.content.request.profileId);
    final heroName = profile?.name ?? story.content.request.heroName;
    return _ref
        .read(storyShareCodecProvider)
        .encode(SharedStory(story: story, heroName: heroName), password);
  }

  /// Opens the save flow and reports whether a file or download was accepted.
  Future<bool> saveStoryFile(
    Uint8List bytes,
    String storyTitle,
    String dialogTitle,
  ) {
    return _ref
        .read(storyShareFileServiceProvider)
        .saveStory(bytes, storyTitle, dialogTitle);
  }

  /// Opens the platform picker for one encrypted story file.
  Future<PickedStoryFile?> pickStoryFile() {
    return _ref.read(storyShareFileServiceProvider).pickStory();
  }

  /// Decrypts and fully validates a selected story file before the preview.
  Future<SharedStory> decodeStoryFile(Uint8List bytes, String password) {
    return _ref.read(storyShareCodecProvider).decode(bytes, password);
  }

  /// Adds one decoded story to the chosen profile's shelf.
  ///
  /// Refuses a story identity that already exists on this device with
  /// [DuplicateStoryException] so importing the same file twice can never
  /// create a second copy. An unknown destination profile surfaces as
  /// [UnknownEntityException], for example when it was deleted mid-import. The
  /// imported book keeps its review status, so a shared draft still needs
  /// parent approval here.
  Future<void> importStory(SharedStory shared, String profileId) async {
    final current = _currentState;
    if (current.profileById(profileId) == null) {
      throw const UnknownEntityException('child profile');
    }
    if (current.stories.any((story) => story.id == shared.story.id)) {
      throw const DuplicateStoryException();
    }
    final savedStories = <StoryBook>[
      shared.storyForProfile(profileId),
      ...current.stories,
    ]..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.saveStories(savedStories);
    _ref
        .read(appControllerProvider.notifier)
        .commit(
          current.withStories(List<StoryBook>.unmodifiable(savedStories)),
        );
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }

  /// Rejects an export for a story that was deleted on another screen.
  StoryBook _requireStory(AppState current, String storyId) {
    for (final story in current.stories) {
      if (story.id == storyId) return story;
    }
    throw const UnknownEntityException('story');
  }
}
