import 'dart:convert';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_job.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_queue.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the three authenticated illustration endpoints.
///
/// Jobs are owned by the device that created them, exactly like story jobs:
/// another device's job is reported as unknown rather than forbidden, so job
/// ids cannot be probed.
class IllustrationHandlers {
  /// Creates handlers over [queue].
  const IllustrationHandlers({required this._queue});

  final IllustrationQueue _queue;

  /// Handles `POST /stories/<storyId>/illustrate`.
  ///
  /// The body is optional. It may carry `illustrationStyle` and
  /// `genderContext` — the two things the library does not remember about a
  /// story but a picture needs. Absent style falls back to `pictureBook`;
  /// absent gender simply leaves the hero described as a child.
  Future<Response> createJob(Request request, String storyId) async {
    final device = requireAuthenticatedDevice(request);
    final options = await _readOptions(request);
    final IllustrationJob? job = _queue.enqueue(
      deviceId: device.id,
      storyId: storyId,
      style: options.style,
      gender: options.gender,
    );
    if (job == null) {
      throw ApiError(
        404,
        ApiErrorCode.storyNotFound,
        'No story exists under this id.',
      );
    }
    return jsonResponse(202, <String, Object?>{
      'jobId': job.id,
      'pageCount': job.pageCount,
      'queuePosition': _queue.queuePosition(job.id) ?? 1,
    });
  }

  /// Handles `GET /illustrations/jobs/<jobId>`.
  Future<Response> readJob(Request request, String jobId) async {
    final job = _requireOwnJob(request, jobId);
    return jsonResponse(
      200,
      job.toJson(queuePosition: _queue.queuePosition(jobId)),
    );
  }

  /// Handles `POST /illustrations/jobs/<jobId>/cancel`.
  ///
  /// Idempotent: cancelling an already finished job answers `200` with the
  /// status it ended in.
  Future<Response> cancelJob(Request request, String jobId) async {
    final job = _requireOwnJob(request, jobId);
    final IllustrationJob cancelled = _queue.cancel(job.id);
    return jsonResponse(200, <String, Object?>{
      'jobId': cancelled.id,
      'status': cancelled.status.wireName,
    });
  }

  IllustrationJob _requireOwnJob(Request request, String jobId) {
    final device = requireAuthenticatedDevice(request);
    final job = _queue.job(jobId);
    if (job == null || job.deviceId != device.id) {
      throw ApiError(
        404,
        ApiErrorCode.jobNotFound,
        'No illustration job exists under this id.',
      );
    }
    return job;
  }

  Future<_IllustrationOptions> _readOptions(Request request) async {
    final Uint8List raw;
    try {
      raw = await readBoundedBody(request);
    } on ApiError {
      rethrow;
    } on Exception {
      throw ApiError(400, ApiErrorCode.invalidJson, 'Body could not be read.');
    }
    if (raw.isEmpty) {
      return const _IllustrationOptions(
        style: StoryIllustrationStyle.pictureBook,
        gender: null,
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(raw));
    } on FormatException {
      throw ApiError(400, ApiErrorCode.invalidJson, 'Body must be valid JSON.');
    }
    if (decoded is! Map<String, Object?>) {
      throw ApiError(
        400,
        ApiErrorCode.invalidJson,
        'Body must be a JSON object.',
      );
    }
    final reader = JsonReader.root(decoded, failures: apiFieldFailures);
    return _IllustrationOptions(
      style:
          reader.optionalNamedChoice<StoryIllustrationStyle>(
            'illustrationStyle',
            resolve: StoryIllustrationStyle.fromWireName,
            expected: 'one of pictureBook, watercolor, colorful3d',
          ) ??
          StoryIllustrationStyle.pictureBook,
      gender: reader.optionalNamedChoice<StoryGenderContext>(
        'genderContext',
        resolve: StoryGenderContext.fromWireName,
        expected: '"girl" or "boy"',
      ),
    );
  }
}

/// The two optional inputs of one illustrate request.
class _IllustrationOptions {
  const _IllustrationOptions({required this.style, required this.gender});

  final StoryIllustrationStyle style;
  final StoryGenderContext? gender;
}
