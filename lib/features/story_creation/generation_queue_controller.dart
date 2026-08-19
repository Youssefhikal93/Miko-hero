import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';

/// Supplies the UTC clock used for collision-free queue identities.
final generationClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Exposes the durable pending generation queue to commands and status UI.
final generationQueueControllerProvider =
    AsyncNotifierProvider<GenerationQueueController, List<GenerationJob>>(
      GenerationQueueController.new,
    );

/// Owns queue persistence independently from completed application state.
class GenerationQueueController extends AsyncNotifier<List<GenerationJob>> {
  @override
  /// Loads jobs, validates profile references, and safely requeues interruptions.
  Future<List<GenerationJob>> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    final appState = await ref.watch(appControllerProvider.future);
    final jobs = await repository.readGenerationJobs();
    for (final job in jobs) {
      if (appState.profileById(job.request.profileId) == null) {
        throw LocalDataFormatException(
          const FormatException(
            'Generation job references an unknown profile.',
          ),
        );
      }
    }
    final normalized = jobs
        .map(
          (job) => job.status == GenerationJobStatus.running
              ? job.withStatus(GenerationJobStatus.queued)
              : job,
        )
        .toList(growable: false);
    if (!_sameStatuses(jobs, normalized)) {
      await repository.saveGenerationJobs(normalized);
    }
    return List<GenerationJob>.unmodifiable(normalized);
  }

  /// Saves a validated request before any generator work begins.
  Future<GenerationJob> enqueue(StoryRequest request) async {
    final jobs = state.requireValue;
    final createdAt = ref.read(generationClockProvider)().toUtc();
    final job = GenerationJob(
      id: _newJobId(jobs, createdAt),
      createdAt: createdAt,
      request: request,
      status: GenerationJobStatus.queued,
    );
    await _persist(<GenerationJob>[...jobs, job]);
    return job;
  }

  /// Marks one queued or failed request as actively generating.
  Future<GenerationJob> markRunning(String jobId) {
    return _replaceStatus(jobId, GenerationJobStatus.running);
  }

  /// Marks one unsuccessful attempt as safely retryable.
  Future<void> markFailed(String jobId) async {
    await _replaceStatus(jobId, GenerationJobStatus.failed);
  }

  /// Permanently removes a cancelled or successfully completed request.
  Future<void> remove(String jobId) async {
    final jobs = state.requireValue;
    final savedJobs = jobs.where((job) => job.id != jobId).toList();
    if (savedJobs.length == jobs.length) throw StateError('Unknown job.');
    await _persist(savedJobs);
  }

  /// Resolves one current job for an explicit retry command.
  GenerationJob jobById(String jobId) {
    for (final job in state.requireValue) {
      if (job.id == jobId) return job;
    }
    throw StateError('Unknown job.');
  }

  /// Replaces one job status while retaining request identity and order.
  Future<GenerationJob> _replaceStatus(
    String jobId,
    GenerationJobStatus status,
  ) async {
    final jobs = state.requireValue;
    GenerationJob? savedJob;
    final savedJobs = jobs
        .map((job) {
          if (job.id != jobId) return job;
          savedJob = job.withStatus(status);
          return savedJob!;
        })
        .toList(growable: false);
    if (savedJob == null) throw StateError('Unknown job.');
    await _persist(savedJobs);
    return savedJob!;
  }

  /// Persists a complete immutable queue before publishing it to listeners.
  Future<void> _persist(List<GenerationJob> jobs) async {
    final savedJobs = List<GenerationJob>.unmodifiable(jobs);
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveGenerationJobs(savedJobs);
    state = AsyncData(savedJobs);
  }

  /// Creates a collision-free identity from the enqueue timestamp.
  String _newJobId(List<GenerationJob> jobs, DateTime createdAt) {
    final baseId = 'generation-${createdAt.microsecondsSinceEpoch}';
    var candidate = baseId;
    var suffix = 1;
    while (jobs.any((job) => job.id == candidate)) {
      candidate = '$baseId-${suffix++}';
    }
    return candidate;
  }

  /// Detects whether interrupted running states required normalization.
  bool _sameStatuses(List<GenerationJob> left, List<GenerationJob> right) {
    for (var index = 0; index < left.length; index++) {
      if (left[index].status != right[index].status) return false;
    }
    return true;
  }
}
