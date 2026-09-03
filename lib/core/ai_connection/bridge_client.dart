import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/ai_connection/bridge_sync_models.dart';

/// Address the bridge listens on out of the box, on the parent's own PC.
const defaultBridgeBaseUrl = 'http://127.0.0.1:8765';

/// Longest a single bridge call may take before it is reported as timed out.
const defaultBridgeRequestTimeout = Duration(seconds: 20);

/// Content type of a JPEG reference photo the bridge accepts.
const bridgeJpegContentType = 'image/jpeg';

/// Content type of a PNG reference photo the bridge accepts.
const bridgePngContentType = 'image/png';

/// Validates a parent-entered bridge address and returns null when unusable.
///
/// Only a plain `http`/`https` origin is accepted: a query, a fragment, or a
/// missing host is refused before it can be stored.
Uri? parseBridgeBaseUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final address = Uri.tryParse(trimmed);
  if (address == null || !address.isAbsolute) return null;
  if (address.scheme != 'http' && address.scheme != 'https') return null;
  if (address.host.isEmpty) return null;
  if (address.hasQuery || address.hasFragment || address.userInfo.isNotEmpty) {
    return null;
  }
  final path = address.path.endsWith('/')
      ? address.path.substring(0, address.path.length - 1)
      : address.path;
  return Uri(
    scheme: address.scheme,
    host: address.host,
    port: address.hasPort ? address.port : null,
    path: path,
  );
}

/// Typed HTTP client for the private PC bridge on the home network.
///
/// The HTTP layer is injected so tests replace the process boundary and never
/// open a socket, and only `package:http` is used so the same client works on
/// mobile and on web.
class BridgeClient {
  /// Creates a client bound to one address and one optional device token.
  const BridgeClient({
    required this.httpClient,
    required this.baseUrl,
    this.deviceToken,
    this.requestTimeout = defaultBridgeRequestTimeout,
    this.runsInBrowser = kIsWeb,
  });

  /// Web-safe HTTP boundary replaced by tests.
  final http.Client httpClient;

  /// Origin of the bridge, for example `http://127.0.0.1:8765`.
  final Uri baseUrl;

  /// Bearer token stored at pairing time; absent until this device is paired.
  ///
  /// Never logged and never rendered: only this client reads it.
  final String? deviceToken;

  /// Bound applied to every single call so no screen can hang forever.
  final Duration requestTimeout;

  /// Whether a failed connection is the browser's refusal rather than the PC's.
  ///
  /// A browser reports every blocked or refused call as one opaque client
  /// exception, so on the web that exception is typed [BridgeFailure.blockedByBrowser]
  /// and its message tells the parent about the site permission. Injectable so
  /// the web reading can be tested on the VM.
  final bool runsInBrowser;

  /// Reads bridge and dependency health; the only call needing no pairing.
  Future<BridgeHealth> readHealth() async {
    final answer = await _send('GET', '/health', authenticated: false);
    return BridgeHealth.fromJson(answer);
  }

  /// Starts a pairing ceremony and returns the identity of the pending request.
  ///
  /// The 6-digit code is deliberately not part of the answer: it appears only
  /// on the PC console, so a parent must be standing at the PC.
  Future<String> requestPairing() async {
    final answer = await _send('POST', '/pair/request', authenticated: false);
    final pairingId = answer['pairingId'];
    if (pairingId is! String || pairingId.isEmpty) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return pairingId;
  }

  /// Confirms a pairing with the code from the PC and returns the one-time token.
  Future<String> confirmPairing({
    required String pairingId,
    required String code,
    required String deviceName,
  }) async {
    final answer = await _send(
      'POST',
      '/pair/confirm',
      authenticated: false,
      body: <String, Object>{
        'pairingId': pairingId,
        'code': code,
        'deviceName': deviceName,
      },
    );
    final token = answer['deviceToken'];
    if (token is! String || token.isEmpty) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return token;
  }

  /// Queues one story generation job and returns its identity and position.
  Future<BridgeJobSubmission> submitStory(BridgeStoryRequest request) async {
    final answer = await _send(
      'POST',
      '/stories/generate',
      authenticated: true,
      body: request.toJson(),
    );
    return BridgeJobSubmission.fromJson(answer);
  }

  /// Polls one job, including the whole story once it completed.
  Future<BridgeJob> readJob(String jobId) async {
    final answer = await _send(
      'GET',
      '/stories/jobs/${Uri.encodeComponent(jobId)}',
      authenticated: true,
    );
    return BridgeJob.fromJson(answer);
  }

  /// Asks the bridge to stop one job and reports the state it ended in.
  ///
  /// Idempotent on the bridge, so cancelling twice is safe.
  Future<BridgeJobStatus> cancelJob(String jobId) async {
    final answer = await _send(
      'POST',
      '/stories/jobs/${Uri.encodeComponent(jobId)}/cancel',
      authenticated: true,
    );
    final status = answer['status'];
    if (status is! String) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    try {
      return BridgeJobStatus.values.byName(status);
    } on ArgumentError {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
  }

  /// Reads what this device needs to decide what to download and what to drop.
  ///
  /// Metadata only: titles and timestamps travel here, prose never does.
  Future<BridgeSyncManifest> readSyncManifest() async {
    final answer = await _send('GET', '/sync/manifest', authenticated: true);
    return BridgeSyncManifest.fromJson(answer);
  }

  /// Downloads one complete story, including the profile it belongs to.
  Future<BridgeSyncStoryDownload> readSyncStory(String storyId) async {
    final answer = await _send(
      'GET',
      '/sync/stories/${Uri.encodeComponent(storyId)}',
      authenticated: true,
    );
    return BridgeSyncStoryDownload.fromJson(answer);
  }

  /// Reports the manifest this device finished applying and returns the mark.
  ///
  /// The reported moment is the manifest's own generation time, so anything
  /// the PC wrote while this device was downloading is picked up next sync.
  Future<DateTime> completeSync({
    required DateTime manifestGeneratedAtUtc,
  }) async {
    final answer = await _send(
      'POST',
      '/sync/complete',
      authenticated: true,
      body: <String, Object>{
        'manifestGeneratedAtUtc': manifestGeneratedAtUtc
            .toUtc()
            .toIso8601String(),
      },
    );
    final lastSyncedAtUtc = answer['lastSyncedAtUtc'];
    if (lastSyncedAtUtc is! String) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return parseBridgeTimestamp(lastSyncedAtUtc);
  }

  /// Deletes one story on the PC, and through it on every paired device.
  ///
  /// Idempotent on the bridge: a story that is already gone answers with the
  /// original deletion, which is still a success for the caller.
  Future<BridgeStoryDeletion> deleteStoryEverywhere(String storyId) async {
    final answer = await _send(
      'POST',
      '/stories/${Uri.encodeComponent(storyId)}/delete',
      authenticated: true,
    );
    return BridgeStoryDeletion.fromJson(answer);
  }

  /// Stores one child's reference photo on the PC for face likeness.
  ///
  /// The bytes travel as the raw image body the bridge expects, never as
  /// base64 inside JSON, and they are neither logged nor echoed anywhere: a
  /// photo of a child is the most private thing this app moves.
  Future<BridgeProfilePhoto> uploadProfilePhoto({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final request = http.Request(
      'PUT',
      _endpoint('/profiles/${Uri.encodeComponent(profileId)}/photo'),
    );
    request.headers['accept'] = 'application/json';
    _authenticate(request);
    request.headers['content-type'] = contentType;
    request.bodyBytes = bytes;
    return BridgeProfilePhoto.fromJson(_answer(await _response(request)));
  }

  /// Removes one child's stored reference photo from the PC.
  ///
  /// Reports whether a photo was actually there; the endpoint is idempotent, so
  /// a profile that never had one is still a success.
  Future<bool> deleteProfilePhoto(String profileId) async {
    final answer = await _send(
      'DELETE',
      '/profiles/${Uri.encodeComponent(profileId)}/photo',
      authenticated: true,
    );
    final removed = answer['removed'];
    if (removed is! bool) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return removed;
  }

  /// Asks the PC to draw the page images of one master-library story.
  ///
  /// Pages the PC has already drawn are skipped there, so re-invoking this
  /// after a partial failure costs only the pages that are still missing.
  Future<BridgeIllustrationSubmission> illustrateStory(
    String storyId, {
    String? illustrationStyle,
    String? genderContext,
  }) async {
    final answer = await _send(
      'POST',
      '/stories/${Uri.encodeComponent(storyId)}/illustrate',
      authenticated: true,
      body: <String, Object>{
        'illustrationStyle': ?illustrationStyle,
        'genderContext': ?genderContext,
      },
    );
    return BridgeIllustrationSubmission.fromJson(answer);
  }

  /// Polls one illustration job, including how many pages are already drawn.
  Future<BridgeIllustrationJob> readIllustrationJob(String jobId) async {
    final answer = await _send(
      'GET',
      '/illustrations/jobs/${Uri.encodeComponent(jobId)}',
      authenticated: true,
    );
    return BridgeIllustrationJob.fromJson(answer);
  }

  /// Asks the PC to stop drawing and reports the state the job ended in.
  ///
  /// Pages that were already finished stay on the PC, so cancelling costs the
  /// family only the pictures that had not been drawn yet.
  Future<BridgeIllustrationJobStatus> cancelIllustrationJob(
    String jobId,
  ) async {
    final answer = await _send(
      'POST',
      '/illustrations/jobs/${Uri.encodeComponent(jobId)}/cancel',
      authenticated: true,
    );
    final status = answer['status'];
    if (status is! String) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    try {
      return BridgeIllustrationJobStatus.values.byName(status);
    } on ArgumentError {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
  }

  /// Downloads one page image, or reports the cached copy as still current.
  ///
  /// [knownETag] is the marker stored beside a cached image; when the PC still
  /// serves that exact version it answers `304` and no bytes travel at all.
  Future<BridgeIllustrationDownload> downloadIllustration(
    String illustrationId, {
    String? knownETag,
  }) async {
    final request = http.Request(
      'GET',
      _endpoint('/sync/illustrations/${Uri.encodeComponent(illustrationId)}'),
    );
    request.headers['accept'] = 'image/png';
    _authenticate(request);
    if (knownETag != null && knownETag.isNotEmpty) {
      request.headers['if-none-match'] = knownETag;
    }
    final response = await _response(request);
    if (response.statusCode == 304) {
      return BridgeIllustrationDownload.unchanged(knownETag);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = _errorCode(_decoded(response));
      throw BridgeException(_failure(code, response.statusCode), code: code);
    }
    if (response.bodyBytes.isEmpty) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeIllustrationDownload(
      bytes: response.bodyBytes,
      eTag: response.headers['etag'],
    );
  }

  /// Performs one bounded call and converts every failure into a typed reason.
  Future<Map<String, Object?>> _send(
    String method,
    String path, {
    required bool authenticated,
    Map<String, Object>? body,
  }) async {
    final request = http.Request(method, _endpoint(path));
    request.headers['accept'] = 'application/json';
    if (authenticated) _authenticate(request);
    if (body != null) {
      // Explicit UTF-8 bytes with the charset stated: Arabic prose corrupts
      // when the transport is allowed to guess a Latin-1 body encoding.
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.bodyBytes = utf8.encode(jsonEncode(body));
    }
    final response = await _response(request);
    return _answer(response);
  }

  /// Attaches the stored device token, refusing the call when there is none.
  void _authenticate(http.Request request) {
    final token = deviceToken;
    if (token == null || token.isEmpty) {
      throw const BridgeException(BridgeFailure.notPaired);
    }
    request.headers['authorization'] = 'Bearer $token';
  }

  /// Sends one request and reports transport failures as typed reasons.
  Future<http.Response> _response(http.Request request) async {
    try {
      final streamed = await httpClient.send(request).timeout(requestTimeout);
      return await http.Response.fromStream(streamed).timeout(requestTimeout);
    } on TimeoutException {
      throw const BridgeException(BridgeFailure.timedOut);
    } on http.ClientException {
      throw BridgeException(
        runsInBrowser
            ? BridgeFailure.blockedByBrowser
            : BridgeFailure.unreachable,
      );
    } on Exception {
      throw const BridgeException(BridgeFailure.unreachable);
    }
  }

  /// Decodes a successful answer or raises the bridge's typed failure.
  Map<String, Object?> _answer(http.Response response) {
    final decoded = _decoded(response);
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    if (isSuccess) {
      if (decoded == null) {
        throw const BridgeException(BridgeFailure.invalidResponse);
      }
      return decoded;
    }
    final code = _errorCode(decoded);
    throw BridgeException(_failure(code, response.statusCode), code: code);
  }

  /// Reads a JSON object body, tolerating an unparsable failure answer.
  Map<String, Object?>? _decoded(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Reads the typed code of an error envelope without its English message.
  String? _errorCode(Map<String, Object?>? decoded) {
    final error = decoded?['error'];
    if (error is! Map<String, Object?>) return null;
    final code = error['code'];
    return code is String ? code : null;
  }

  /// Maps a bridge error code, then its status, onto one typed reason.
  BridgeFailure _failure(String? code, int statusCode) {
    return switch (code) {
      'unauthorized' => BridgeFailure.unauthorized,
      'rate_limited' => BridgeFailure.rateLimited,
      'pairing_not_found' => BridgeFailure.pairingNotFound,
      'pairing_expired' => BridgeFailure.pairingExpired,
      'invalid_pairing_code' => BridgeFailure.invalidPairingCode,
      'invalid_field' || 'invalid_request' => BridgeFailure.invalidRequest,
      'job_not_found' => BridgeFailure.jobNotFound,
      'story_not_found' => BridgeFailure.storyNotFound,
      'profile_not_found' => BridgeFailure.profileNotFound,
      'photo_too_large' => BridgeFailure.photoTooLarge,
      'invalid_image' ||
      'unsupported_image_type' => BridgeFailure.unsupportedImage,
      'illustration_not_found' => BridgeFailure.illustrationNotFound,
      'illustration_not_ready' => BridgeFailure.illustrationNotReady,
      'cancelled' => BridgeFailure.cancelled,
      'ollama_unavailable' ||
      'ollama_timeout' ||
      'invalid_model_output' ||
      'library_write_failed' ||
      'internal_error' => BridgeFailure.generationFailed,
      _ => _statusFailure(statusCode),
    };
  }

  /// Falls back to the HTTP status when the bridge sent no known code.
  BridgeFailure _statusFailure(int statusCode) {
    return switch (statusCode) {
      401 || 403 => BridgeFailure.unauthorized,
      404 => BridgeFailure.jobNotFound,
      413 => BridgeFailure.photoTooLarge,
      429 => BridgeFailure.rateLimited,
      _ => BridgeFailure.bridgeError,
    };
  }

  /// Joins one endpoint path onto the configured origin.
  Uri _endpoint(String path) {
    return baseUrl.replace(path: '${baseUrl.path}$path');
  }
}
