import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_queue.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the three authenticated story generation endpoints.
///
/// Jobs are owned by the device that created them: another device's job is
/// reported as unknown rather than forbidden, so job ids cannot be probed.
class GenerationHandlers {
  /// Creates handlers over [queue].
  const GenerationHandlers({required this._queue});

  final StoryGenerationQueue _queue;

  /// Handles `POST /stories/generate`.
  Future<Response> createJob(Request request) async {
    final device = requireAuthenticatedDevice(request);
    final body = await parseJsonObjectBody(request);
    final StoryGenerationRequest generationRequest;
    try {
      generationRequest = StoryGenerationRequest.fromJson(body);
    } on StoryRequestValidationException catch (error) {
      throw ApiError(400, ApiErrorCode.invalidField, error.message);
    }
    final job = _queue.enqueue(deviceId: device.id, request: generationRequest);
    return jsonResponse(202, <String, Object?>{
      'jobId': job.id,
      'queuePosition': _queue.queuePosition(job.id) ?? 1,
    });
  }

  /// Handles `GET /stories/jobs/<jobId>`.
  Future<Response> readJob(Request request, String jobId) async {
    final job = _ownJob(request, jobId);
    return jsonResponse(
      200,
      job.toJson(queuePosition: _queue.queuePosition(jobId)),
    );
  }

  /// Handles `POST /stories/jobs/<jobId>/cancel`.
  ///
  /// Idempotent: cancelling an already finished job answers `200` with the
  /// status it ended in.
  Future<Response> cancelJob(Request request, String jobId) async {
    final job = _ownJob(request, jobId);
    final GenerationJob cancelled = _queue.cancel(job.id);
    return jsonResponse(200, <String, Object?>{
      'jobId': cancelled.id,
      'status': cancelled.status.wireName,
    });
  }

  GenerationJob _ownJob(Request request, String jobId) => requireOwnJob(
    request,
    _queue,
    jobId,
    notFoundMessage: 'No generation job exists under this id.',
  );
}
