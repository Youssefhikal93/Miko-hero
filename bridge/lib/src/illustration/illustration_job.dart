import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_errors.dart';

/// Lifecycle of one illustration job.
///
/// `queued → rendering → completed`, with `failed` and `cancelled` reachable
/// from any non-terminal state. Unlike a story job, a job that ends
/// `completed` may still have failed pages: a single page that ComfyUI could
/// not render does not throw away the ones that worked. The counts on the job
/// are what say how the book actually turned out.
enum IllustrationJobStatus {
  /// Waiting for the single worker to pick it up.
  queued('queued'),

  /// Pages are being rendered, one at a time.
  rendering('rendering'),

  /// Every page was attempted and at least one image was stored.
  completed('completed'),

  /// The job produced no image at all; see the attached failure.
  failed('failed'),

  /// The job was cancelled by the device that created it.
  cancelled('cancelled');

  const IllustrationJobStatus(this.wireName);

  /// Stable value used in JSON payloads and log lines.
  final String wireName;

  /// Whether the job will never change state again.
  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;
}

/// Immutable snapshot of one illustration job.
///
/// The queue replaces the whole snapshot on every transition, so a snapshot
/// handed to a request handler can never change underneath it.
class IllustrationJob implements QueuedJob {
  /// Creates a job snapshot.
  const IllustrationJob({
    required this.id,
    required this.deviceId,
    required this.storyId,
    required this.pageCount,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.progress,
    this.completedPageCount = 0,
    this.failedPageCount = 0,
    this.failure,
  });

  /// Stable job id (uuid v4).
  @override
  final String id;

  /// Device that created the job; only that device may read or cancel it.
  @override
  final String deviceId;

  /// Story whose pages this job renders.
  final String storyId;

  /// How many pages this job set out to render.
  ///
  /// Pages that were already `completed` when the job was queued are not
  /// counted: a re-run renders only what is still missing.
  final int pageCount;

  /// Current lifecycle state.
  final IllustrationJobStatus status;

  /// When the job was accepted.
  final DateTime createdAtUtc;

  /// When the job last changed state.
  final DateTime updatedAtUtc;

  /// Short, content-free description such as `Rendering page 3 of 6.`
  final String progress;

  /// Pages whose image is now stored in the library.
  final int completedPageCount;

  /// Pages whose row was marked `failed`.
  final int failedPageCount;

  /// Typed failure, set exactly when [status] is
  /// [IllustrationJobStatus.failed].
  final IllustrationFailure? failure;

  @override
  bool get isTerminal => status.isTerminal;

  /// Returns a copy with the given fields replaced.
  IllustrationJob copyWith({
    IllustrationJobStatus? status,
    DateTime? updatedAtUtc,
    String? progress,
    int? completedPageCount,
    int? failedPageCount,
    IllustrationFailure? failure,
  }) {
    return IllustrationJob(
      id: id,
      deviceId: deviceId,
      storyId: storyId,
      pageCount: pageCount,
      status: status ?? this.status,
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      progress: progress ?? this.progress,
      completedPageCount: completedPageCount ?? this.completedPageCount,
      failedPageCount: failedPageCount ?? this.failedPageCount,
      failure: failure ?? this.failure,
    );
  }

  /// JSON shape of `GET /illustrations/jobs/<jobId>`.
  ///
  /// [queuePosition] is included only while the job is still queued. Nothing
  /// here is story content: ids, counts and a progress sentence only.
  Map<String, Object?> toJson({int? queuePosition}) {
    return <String, Object?>{
      'jobId': id,
      'storyId': storyId,
      'status': status.wireName,
      'progress': progress,
      'pageCount': pageCount,
      'completedPageCount': completedPageCount,
      'failedPageCount': failedPageCount,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      if (status == IllustrationJobStatus.queued && queuePosition != null)
        'queuePosition': queuePosition,
      if (failure != null) 'error': failure!.toJson(),
    };
  }
}
