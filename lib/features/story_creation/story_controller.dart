import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/generation_progress_controller.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';

/// Supplies story generation and library commands to story feature widgets.
final storyControllerProvider = Provider<StoryController>(StoryController.new);

/// Owns validated story generation, persistence, and deletion transactions.
class StoryController {
  /// Retains access to generator, repository, and shared application state.
  StoryController(this._ref);

  final Ref _ref;

  /// Job currently being generated, so only that request cancels remote work.
  String? _runningJobId;

  /// The generator running right now, kept so cancellation reaches that
  /// exact instance even if the parent changes the connection settings while
  /// the PC is still writing.
  CancellableStoryGenerator? _runningGenerator;

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
  ///
  /// A request already running on the paired PC is stopped there first, so
  /// cancelling in the app never leaves the other machine writing a story
  /// nobody will ever see.
  Future<void> cancelGeneration(String jobId) async {
    final queue = await _queueController();
    queue.jobById(jobId);
    if (jobId == _runningJobId) await _cancelRemoteGeneration();
    await queue.remove(jobId);
  }

  /// Permanently removes one story while preserving every other local book.
  ///
  /// Also drops the story from every child's reading-reward history, because a
  /// badge must never depend on a book that no longer exists on this device.
  Future<void> deleteStory(String storyId) async {
    final current = _currentState;
    final savedStories = current.stories
        .where((story) => story.id != storyId)
        .toList(growable: false);
    await _saveStories(current, savedStories);
    await _ref.read(profileControllerProvider).forgetFinishedStory(storyId);
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
    final generator = await _activeGenerator();
    await queue.markRunning(job.id);
    _runningJobId = job.id;
    _runningGenerator = generator is CancellableStoryGenerator
        ? generator
        : null;
    try {
      final generated = await generator.generate(job.request);
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
    } finally {
      _runningJobId = null;
      _runningGenerator = null;
      _ref.read(generationProgressProvider.notifier).clear();
    }
  }

  /// Resolves the generator the parent selected, once its settings are loaded.
  ///
  /// Awaiting the stored selection matters: reading the provider while it is
  /// still loading would hand a Local AI family the offline demo instead.
  Future<StoryGenerator> _activeGenerator() async {
    await _ref.read(aiConnectionControllerProvider.future);
    return _ref.read(storyGeneratorProvider);
  }

  /// Asks a remote generator to stop without blocking the local removal.
  Future<void> _cancelRemoteGeneration() async {
    final generator = _runningGenerator;
    if (generator == null) return;
    try {
      await generator.cancelActiveGeneration();
    } on Exception {
      // The saved request is removed either way; an unreachable PC simply
      // stops being polled, and the bridge never persists a partial story.
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
