import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';

/// Supplies story generation and library commands to story feature widgets.
final storyControllerProvider = Provider<StoryController>(StoryController.new);

/// Owns validated story generation, persistence, and deletion transactions.
class StoryController {
  /// Retains access to generator, repository, and shared application state.
  StoryController(this._ref);

  final Ref _ref;

  /// Generates and persists a new book for a saved, gender-matching profile.
  Future<StoryBook> createStory(StoryRequest request) async {
    _validateRequest(request);
    final queue = await _queueController();
    final job = await queue.enqueue(request);
    return _generateJob(job, queue);
  }

  /// Retries one saved request without creating duplicate completed books.
  Future<StoryBook> retryGeneration(String jobId) async {
    final queue = await _queueController();
    final job = queue.jobById(jobId);
    _validateRequest(job.request);
    return _generateJob(job, queue);
  }

  /// Removes one queued or failed request after explicit parent cancellation.
  Future<void> cancelGeneration(String jobId) async {
    final queue = await _queueController();
    await queue.remove(jobId);
  }

  /// Permanently removes one story while preserving every other local book.
  Future<void> deleteStory(String storyId) async {
    final current = _currentState;
    final savedStories = current.stories
        .where((story) => story.id != storyId)
        .toList(growable: false);
    await _saveStories(current, savedStories);
  }

  /// Makes one reviewed draft visible on child-facing shelves.
  Future<void> approveStory(String storyId) {
    return _updateStory(
      storyId,
      (story) => story.withReviewStatus(StoryReviewStatus.approved),
    );
  }

  /// Toggles the child-facing favorite marker for one approved book.
  Future<void> toggleFavorite(String storyId) {
    return _updateStory(
      storyId,
      (story) => story.withFavorite(!story.isFavorite),
    );
  }

  /// Replaces one book's bounded collection labels after model validation.
  Future<void> setCollections(String storyId, List<String> collections) {
    return _updateStory(storyId, (story) => story.withCollections(collections));
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }

  /// Ensures queued requests still match their saved child profile context.
  ///
  /// A deleted profile is reported as [UnknownEntityException] because a saved
  /// request can outlive the child it belongs to.
  void _validateRequest(StoryRequest request) {
    final profile = _currentState.profileById(request.profileId);
    if (profile == null) {
      throw const UnknownEntityException('child profile');
    }
    if (!request.gender.isSpecified || request.gender != profile.gender) {
      // Reachable by retrying a queued request after the parent edited the
      // child's Girl/Boy choice, so it must stay a recoverable exception.
      throw const UnknownEntityException('matching child profile');
    }
  }

  /// Loads the durable queue before invoking commands on its notifier.
  Future<GenerationQueueController> _queueController() async {
    await _ref.read(generationQueueControllerProvider.future);
    return _ref.read(generationQueueControllerProvider.notifier);
  }

  /// Runs one job and saves a queue-derived draft identity exactly once.
  Future<StoryBook> _generateJob(
    GenerationJob job,
    GenerationQueueController queue,
  ) async {
    final storyId = 'story-${job.id}';
    final completed = _storyById(storyId);
    if (completed != null) {
      await queue.remove(job.id);
      return completed;
    }
    await queue.markRunning(job.id);
    try {
      final generated = await _ref
          .read(storyGeneratorProvider)
          .generate(job.request);
      final story = generated
          .withId(storyId)
          .withReviewStatus(StoryReviewStatus.draft);
      final current = _currentState;
      await _saveStories(current, <StoryBook>[story, ...current.stories]);
      await queue.remove(job.id);
      return story;
    } catch (error, stackTrace) {
      try {
        await queue.markFailed(job.id);
      } on Exception {
        // Preserve the generator failure; the running job requeues on restart.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Finds an idempotently completed book in the current local snapshot.
  StoryBook? _storyById(String storyId) {
    for (final story in _currentState.stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }

  /// Persists one metadata transformation without changing story ordering.
  ///
  /// Reports a story deleted on another screen as [UnknownEntityException] so
  /// favorite, collection, and approval surfaces can show recoverable feedback.
  Future<void> _updateStory(
    String storyId,
    StoryBook Function(StoryBook story) update,
  ) async {
    final current = _currentState;
    var found = false;
    final savedStories = current.stories
        .map((story) {
          if (story.id != storyId) return story;
          found = true;
          return update(story);
        })
        .toList(growable: false);
    if (!found) throw const UnknownEntityException('story');
    await _saveStories(current, savedStories);
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
