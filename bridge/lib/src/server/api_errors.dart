import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:shelf/shelf.dart';

/// Machine-readable error codes used in typed JSON error responses.
abstract final class ApiErrorCode {
  /// Resource not found (unknown URL).
  static const String notFound = 'not_found';

  /// HTTP method not allowed for the URL.
  static const String methodNotAllowed = 'method_not_allowed';

  /// Request body is not valid JSON or has the wrong shape.
  static const String invalidJson = 'invalid_json';

  /// Request body exceeded the configured size limit.
  static const String bodyTooLarge = 'body_too_large';

  /// The request took too long and was aborted.
  static const String requestTimeout = 'request_timeout';

  /// Missing, malformed, revoked or unknown bearer token.
  static const String unauthorized = 'unauthorized';

  /// Pairing requests are being issued too quickly.
  static const String rateLimited = 'rate_limited';

  /// The pairing id does not match any pending pairing.
  static const String pairingNotFound = 'pairing_not_found';

  /// The pairing existed but its code lifetime expired.
  static const String pairingExpired = 'pairing_expired';

  /// The submitted pairing code is wrong.
  static const String invalidPairingCode = 'invalid_pairing_code';

  /// A required body field is missing or malformed.
  static const String invalidField = 'invalid_field';

  /// No active paired device with this id exists on the PC.
  static const String deviceNotFound = 'device_not_found';

  /// A device tried to remove its own pairing from the PC device list.
  static const String cannotRemoveSelf = 'cannot_remove_self';

  /// No generation job with this id belongs to the calling device.
  static const String jobNotFound = 'job_not_found';

  /// No story with this id exists in the master library.
  static const String storyNotFound = 'story_not_found';

  /// No profile with this id exists in the master library.
  static const String profileNotFound = 'profile_not_found';

  /// The uploaded reference photo declared a type the bridge does not accept.
  static const String unsupportedImageType = 'unsupported_image_type';

  /// The uploaded bytes are not the image type they were declared as.
  static const String invalidImage = 'invalid_image';

  /// The uploaded reference photo exceeds the per-photo size limit.
  static const String photoTooLarge = 'photo_too_large';

  /// No illustration with this id exists in the master library.
  static const String illustrationNotFound = 'illustration_not_found';

  /// The illustration exists but has no rendered image file yet.
  static const String illustrationNotReady = 'illustration_not_ready';

  /// Unexpected server-side failure.
  static const String internalError = 'internal_error';
}

/// Exception carrying a typed JSON error through middleware boundaries.
class ApiError implements Exception {
  /// Creates an API error with the intended [status] and machine [code].
  ApiError(this.status, this.code, this.message);

  /// HTTP status code to respond with.
  final int status;

  /// Stable machine-readable code from [ApiErrorCode].
  final String code;

  /// Safe human-readable message; never echoes request content.
  final String message;

  @override
  String toString() => 'ApiError($status, $code)';
}

/// How a JSON request body names its fields and refuses them.
///
/// One bad field is a `400 invalid_field` with the field named and its value
/// left out, which is the same envelope every other handler answers with.
class _ApiFieldFailures extends JsonFieldFailures {
  const _ApiFieldFailures();

  @override
  String describeField(String path) => 'Field "$path"';

  @override
  String describeContainer(String path) =>
      path.isEmpty ? 'The request body' : 'Field "$path"';

  @override
  Object failure(String path, String message) =>
      ApiError(400, ApiErrorCode.invalidField, message);
}

/// The vocabulary an HTTP request body's fields are refused in.
const JsonFieldFailures apiFieldFailures = _ApiFieldFailures();

/// Serializes [body] as one JSON response with `application/json`.
Response jsonResponse(int status, Map<String, Object?> body) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: <String, String>{
      HttpHeaders.contentTypeHeader: ContentType.json.toString(),
    },
  );
}

/// Builds the canonical typed error envelope `{error: {code, message}}`.
Response jsonError(int status, String code, String message) {
  return jsonResponse(status, <String, Object?>{
    'error': <String, Object?>{'code': code, 'message': message},
  });
}

/// Converts an [ApiError] into its typed JSON response.
Response apiErrorResponse(ApiError error) {
  return jsonError(error.status, error.code, error.message);
}
