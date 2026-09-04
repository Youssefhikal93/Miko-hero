import 'dart:convert';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/request_limits.dart';
import 'package:shelf/shelf.dart';

/// Context key under which the authenticated device is stored.
const String authenticatedDeviceContextKey = 'iam_hero.authenticated_device';

/// Middleware enforcing bearer-token authentication on wrapped handlers.
///
/// The presented token is SHA-256 hashed and compared against every stored
/// device token hash in constant time; revoked devices are rejected. On any
/// failure a typed `401` error is returned without revealing why the token
/// was rejected.
///
/// Every accepted call stamps the device's `last_seen_at_utc`, which is what
/// lets the parent see in the app which paired devices still reach the PC.
/// The stamp is one single-row `UPDATE` and records only the moment: never
/// the endpoint, the address, or anything about the request itself.
Middleware requireDeviceAuth({required DeviceStore deviceStore}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final String? header = request.headers['authorization'];
      final PairedDevice? device = _verifyBearerToken(header, deviceStore);
      if (device == null) {
        throw ApiError(
          401,
          ApiErrorCode.unauthorized,
          'A valid device bearer token is required.',
        );
      }
      deviceStore.markSeen(device.id);
      final Request authenticated = request.change(
        context: <String, Object?>{
          ...request.context,
          authenticatedDeviceContextKey: device,
        },
      );
      return innerHandler(authenticated);
    };
  };
}

PairedDevice? _verifyBearerToken(String? header, DeviceStore deviceStore) {
  if (header == null) {
    return null;
  }
  const prefix = 'Bearer ';
  if (!header.startsWith(prefix)) {
    return null;
  }
  final token = header.substring(prefix.length).trim();
  if (token.isEmpty || token.length > 256 || _containsWhitespace(token)) {
    return null;
  }
  final digestHex = sha256Hex(token);
  return deviceStore.findActiveByTokenHash(digestHex);
}

bool _containsWhitespace(String value) {
  return value.codeUnits.any(
    (unit) => unit == 0x20 || (unit >= 0x09 && unit <= 0x0D),
  );
}

/// Reads the authenticated device injected by [requireDeviceAuth], or `null`.
PairedDevice? authenticatedDevice(Map<String, Object?> context) {
  final device = context[authenticatedDeviceContextKey];
  return device is PairedDevice ? device : null;
}

/// Reads the authenticated device of [request] or raises a typed `401`.
///
/// Handlers behind [requireDeviceAuth] always have one; this exists so a
/// handler never has to treat "somehow unauthenticated" as a success path.
PairedDevice requireAuthenticatedDevice(Request request) {
  final device = authenticatedDevice(request.context);
  if (device == null) {
    throw ApiError(
      401,
      ApiErrorCode.unauthorized,
      'A valid device bearer token is required.',
    );
  }
  return device;
}

/// Reads [jobId] out of [queue] as a job the calling device owns.
///
/// Jobs are owned by the device that created them. Another device's job and
/// an id that never existed are reported identically — a `404` carrying
/// [notFoundMessage] — so job ids cannot be probed.
TJob requireOwnJob<TJob extends QueuedJob>(
  Request request,
  JobQueue<TJob, Object?> queue,
  String jobId, {
  required String notFoundMessage,
}) {
  final device = requireAuthenticatedDevice(request);
  final job = queue.job(jobId);
  if (job == null || job.deviceId != device.id) {
    throw ApiError(404, ApiErrorCode.jobNotFound, notFoundMessage);
  }
  return job;
}

/// Parses one JSON object request body, raising typed errors otherwise.
Future<Map<String, Object?>> parseJsonObjectBody(Request request) async {
  final Uint8List rawBytes;
  try {
    rawBytes = await readBoundedBody(request);
  } on ApiError {
    rethrow;
  } on Exception {
    throw ApiError(400, ApiErrorCode.invalidJson, 'Body could not be read.');
  }
  final String raw;
  try {
    raw = utf8.decode(rawBytes);
  } on FormatException {
    throw ApiError(400, ApiErrorCode.invalidJson, 'Body must be UTF-8 JSON.');
  }
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
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
  return decoded;
}

/// Drains the request body via [Request.read] while enforcing the size
/// limit, so oversized bodies are rejected with a typed error even when
/// this runs without the global body-limit middleware.
Future<Uint8List> readBoundedBody(Request request) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request.read()) {
    builder.add(chunk);
    if (builder.length > maxRequestBodyBytes) {
      throw ApiError(
        413,
        ApiErrorCode.bodyTooLarge,
        'Request body exceeds the '
        '${maxRequestBodyBytes ~/ (1024 * 1024)} MB limit.',
      );
    }
  }
  return builder.takeBytes();
}

/// Reads a required non-empty string field from a parsed JSON body.
String requiredStringField(
  Map<String, Object?> body,
  String fieldName, {
  int maxLength = 200,
}) {
  final value = body[fieldName];
  if (value is! String || value.trim().isEmpty) {
    throw ApiError(
      400,
      ApiErrorCode.invalidField,
      'Field "$fieldName" is required and must be a non-empty string.',
    );
  }
  if (value.length > maxLength) {
    throw ApiError(
      400,
      ApiErrorCode.invalidField,
      'Field "$fieldName" exceeds the $maxLength character limit.',
    );
  }
  return value.trim();
}

/// Reads a required ISO-8601 timestamp field and returns it in UTC.
DateTime requiredUtcTimestampField(
  Map<String, Object?> body,
  String fieldName,
) {
  final value = body[fieldName];
  final DateTime? parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) {
    throw ApiError(
      400,
      ApiErrorCode.invalidField,
      'Field "$fieldName" must be an ISO-8601 timestamp.',
    );
  }
  return parsed.toUtc();
}
