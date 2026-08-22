import 'dart:convert';
import 'dart:typed_data';

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
