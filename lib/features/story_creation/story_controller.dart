import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Supplies story generation and library commands to story feature widgets.
final storyControllerProvider = Provider<StoryController>(StoryController.new);

/// Owns validated story generation, persistence, and deletion transactions.
class StoryController {
  /// Retains access to generator, repository, and shared application state.
  StoryController(this._ref);

  final Ref _ref;

  /// Generates and persists a new book for a saved, gender-matching profile.
  Future<StoryBook> createStory(StoryRequest request) async {
    final current = _currentState;
    final profile = current.profileById(request.profileId);
    if (profile == null) {
      throw StateError('Cannot create a story for an unknown child profile.');
    }
    if (!request.gender.isSpecified || request.gender != profile.gender) {
      throw StateError('Story gender must match the selected child profile.');
    }
    final generator = _ref.read(storyGeneratorProvider);
    final story = await generator.generate(request);
    final savedStories = List<StoryBook>.unmodifiable(<StoryBook>[
      story,
      ...current.stories,
    ]);
    await _saveStories(current, savedStories);
    return story;
  }

  /// Permanently removes one story while preserving every other local book.
  Future<void> deleteStory(String storyId) async {
    final current = _currentState;
    final savedStories = current.stories
        .where((story) => story.id != storyId)
        .toList(growable: false);
    await _saveStories(current, savedStories);
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }

  /// Publishes a library only after its complete JSON snapshot is persisted.
  Future<void> _saveStories(
    AppState current,
    List<StoryBook> savedStories,
  ) async {
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.saveStories(savedStories);
    _ref
        .read(appControllerProvider.notifier)
        .commit(current.withStories(savedStories));
  }
}
