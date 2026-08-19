import 'package:miko_hero/core/models/story_models.dart';

/// Durable lifecycle states for one local story-generation request.
enum GenerationJobStatus {
  /// Saved request waiting for the parent to start or retry generation.
  queued,

  /// Request currently being processed by the configured generator.
  running,

  /// Last generation attempt failed and can be retried safely.
  failed,
}

/// One persisted generation request retained until a draft is stored.
class GenerationJob {
  /// Creates a durable job from a validated request and lifecycle state.
  const GenerationJob({
    required this.id,
    required this.createdAt,
    required this.request,
    required this.status,
  });

  /// Stable identity used to make completed story persistence idempotent.
  final String id;

  /// UTC time used to order pending requests oldest first.
  final DateTime createdAt;

  /// Complete profile, prompt, language, length, and style request snapshot.
  final StoryRequest request;

  /// Current persisted generation lifecycle state.
  final GenerationJobStatus status;

  /// Converts one pending request into local JSON.
  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'request': request.toJson(),
      'status': status.name,
    };
  }

  /// Validates and restores one current-schema generation job.
  factory GenerationJob.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final createdAt = json['createdAt'];
    final request = json['request'];
    final status = json['status'];
    if (id is! String ||
        id.trim().isEmpty ||
        createdAt is! String ||
        request is! Map<String, Object?> ||
        status is! String) {
      throw const FormatException('Malformed generation job.');
    }
    try {
      return GenerationJob(
        id: id,
        createdAt: DateTime.parse(createdAt).toUtc(),
        request: StoryRequest.fromJson(request),
        status: GenerationJobStatus.values.byName(status),
      );
    } on ArgumentError {
      throw const FormatException('Unsupported generation job status.');
    }
  }

  /// Returns the same durable request with a new lifecycle state.
  GenerationJob withStatus(GenerationJobStatus savedStatus) {
    return GenerationJob(
      id: id,
      createdAt: createdAt,
      request: request,
      status: savedStatus,
    );
  }
}
