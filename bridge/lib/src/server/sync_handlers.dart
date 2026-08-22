import 'dart:io';

import 'package:iam_hero_bridge/src/library/story_deleter.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:iam_hero_bridge/src/sync/illustration_file_reader.dart';
import 'package:iam_hero_bridge/src/sync/sync_reader.dart';
import 'package:iam_hero_bridge/src/sync/sync_state_store.dart';
import 'package:shelf/shelf.dart';

/// Serves the authenticated synchronization and deletion endpoints.
///
/// The whole protocol is three calls plus a delete: fetch a manifest, pull
/// the stories whose timestamps moved, report the manifest back. There is no
/// change feed and no server-side session — a device that loses its notes can
/// always rebuild them from one manifest.
class SyncHandlers {
  /// Creates handlers over the sync reader, state store, story deleter and
  /// illustration file reader.
  const SyncHandlers({
    required this._reader,
    required this._stateStore,
    required this._deleter,
    required this._illustrationFiles,
  });

  final SyncReader _reader;
  final SyncStateStore _stateStore;
  final StoryDeleter _deleter;
  final IllustrationFileReader _illustrationFiles;

  /// Handles `GET /sync/manifest`.
  Future<Response> readManifest(Request request) async {
    final device = requireAuthenticatedDevice(request);
    final manifest = _reader.readManifest(
      deviceId: device.id,
      nowUtc: DateTime.now().toUtc(),
    );
    return jsonResponse(200, manifest.toJson());
  }

  /// Handles `GET /sync/stories/<storyId>`.
  ///
  /// Answers `404 story_not_found` for an unknown id, which includes a story
  /// that was deleted: the manifest's deletion records are how a device
  /// learns that difference.
  Future<Response> downloadStory(Request request, String storyId) async {
    requireAuthenticatedDevice(request);
    final story = _reader.readStory(storyId);
    if (story == null) {
      throw ApiError(
        404,
        ApiErrorCode.storyNotFound,
        'No story exists under this id.',
      );
    }
    return jsonResponse(200, <String, Object?>{'story': story.toJson()});
  }

  /// Handles `GET /sync/illustrations/<illustrationId>`.
  ///
  /// The one endpoint that answers with bytes instead of JSON: the rendered
  /// PNG, with a content-hash `ETag` a device can store and send back as
  /// `If-None-Match` to skip a re-download. Errors stay typed JSON — an
  /// unknown id is `404`, and a page that has not been rendered (or whose
  /// render failed) is `409 illustration_not_ready`, which is a different
  /// thing a device must not confuse with a missing story.
  Future<Response> downloadIllustration(
    Request request,
    String illustrationId,
  ) async {
    requireAuthenticatedDevice(request);
    final result = await _illustrationFiles.read(illustrationId);
    final file = result.file;
    if (file == null) {
      switch (result.problem!) {
        case IllustrationFileProblem.unknown:
          throw ApiError(
            404,
            ApiErrorCode.illustrationNotFound,
            'No illustration exists under this id.',
          );
        case IllustrationFileProblem.notReady:
          throw ApiError(
            409,
            ApiErrorCode.illustrationNotReady,
            'This illustration has not been rendered yet.',
          );
      }
    }
    if (request.headers[HttpHeaders.ifNoneMatchHeader] == file.eTag) {
      return Response.notModified(
        headers: <String, String>{HttpHeaders.etagHeader: file.eTag},
      );
    }
    return Response.ok(
      file.bytes,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'image/png',
        HttpHeaders.etagHeader: file.eTag,
        HttpHeaders.cacheControlHeader: 'private, no-cache',
        'x-illustration-story-id': file.storyId,
        'x-illustration-page-number': '${file.pageNumber}',
      },
    );
  }

  /// Handles `POST /sync/complete`.
  Future<Response> completeSync(Request request) async {
    final device = requireAuthenticatedDevice(request);
    final body = await parseJsonObjectBody(request);
    final manifestGeneratedAtUtc = requiredUtcTimestampField(
      body,
      'manifestGeneratedAtUtc',
    );
    final stored = _stateStore.recordCompletedSync(
      deviceId: device.id,
      manifestGeneratedAtUtc: manifestGeneratedAtUtc,
      nowUtc: DateTime.now().toUtc(),
    );
    return jsonResponse(200, <String, Object?>{
      'deviceId': device.id,
      'lastSyncedAtUtc': stored.toIso8601String(),
    });
  }

  /// Handles `POST /stories/<storyId>/delete`.
  ///
  /// Idempotent by design: a story that is already gone answers `200` with
  /// `alreadyDeleted: true`, and only an id that was never in this library
  /// answers `404 story_not_found`.
  Future<Response> deleteStory(Request request, String storyId) async {
    final device = requireAuthenticatedDevice(request);
    final deletion = await _deleter.deleteStory(
      storyId: storyId,
      requestedByDeviceId: device.id,
      nowUtc: DateTime.now().toUtc(),
    );
    if (deletion == null) {
      throw ApiError(
        404,
        ApiErrorCode.storyNotFound,
        'No story exists under this id.',
      );
    }
    return jsonResponse(200, deletion.toJson());
  }
}
