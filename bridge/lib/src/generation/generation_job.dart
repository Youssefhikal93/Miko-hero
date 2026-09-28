import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Lifecycle of one story generation job.
///
/// `queued → generating → validating → completed`, with `failed` and
/// `cancelled` reachable from any non-terminal state.
enum GenerationJobStatus {
  /// Waiting for the single worker to pick it up.
  queued('queued'),

  /// The model is writing the story.
  generating('generating'),

  /// The model answered and the bridge is checking it.
  validating('validating'),

  /// The story passed validation and is stored in the master library.
  completed('completed'),

  /// The job ended without a story; see the attached failure.
  failed('failed'),

  /// The job was cancelled by the device that created it.
  cancelled('cancelled');

  const GenerationJobStatus(this.wireName);

  /// Stable value used in JSON payloads and log lines.
  final String wireName;

  /// Whether the job will never change state again.
  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;
}

/// Immutable snapshot of one generation job.
///
/// The queue replaces the whole snapshot on every transition, so a snapshot
/// handed to a request handler can never change underneath it.
class GenerationJob implements QueuedJob {
  /// Creates a job snapshot.
  const GenerationJob({
    required this.id,
    required this.deviceId,
    required this.request,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.progress,
    this.failure,
    this.story,
  });

  /// Stable job id (uuid v4).
  @override
  final String id;

  /// Device that created the job; only that device may read or cancel it.
  @override
  final String deviceId;

  /// Validated inputs. Private content — never serialized to a response.
  final StoryGenerationRequest request;

  /// Current lifecycle state.
  final GenerationJobStatus status;

  /// When the job was accepted.
  final DateTime createdAtUtc;

  /// When the job last changed state.
  final DateTime updatedAtUtc;

  /// Short, content-free description of what the job is doing.
  final String progress;

  /// Typed failure, set exactly when [status] is
  /// [GenerationJobStatus.failed].
  final GenerationFailure? failure;

  /// The stored story, set exactly when [status] is
  /// [GenerationJobStatus.completed].
  final GeneratedStory? story;

  @override
  bool get isTerminal => status.isTerminal;

  /// Returns a copy with the given fields replaced.
  GenerationJob copyWith({
    GenerationJobStatus? status,
    DateTime? updatedAtUtc,
    String? progress,
    GenerationFailure? failure,
    GeneratedStory? story,
  }) {
    return GenerationJob(
      id: id,
      deviceId: deviceId,
      request: request,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      progress: progress ?? this.progress,
      failure: failure ?? this.failure,
      story: story ?? this.story,
    );
  }

  /// JSON shape of `GET /stories/jobs/<jobId>`.
  ///
  /// [queuePosition] is included only while the job is still queued. The
  /// request itself is never echoed: it holds the child's name.
  Map<String, Object?> toJson({int? queuePosition}) {
    return <String, Object?>{
      'jobId': id,
      'status': status.wireName,
      'progress': progress,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      if (status == GenerationJobStatus.queued && queuePosition != null)
        'queuePosition': queuePosition,
      if (failure != null) 'error': failure!.toJson(),
      if (story != null) 'story': story!.toJson(),
    };
  }
}
