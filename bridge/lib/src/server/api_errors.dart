import 'dart:convert';
import 'dart:io';

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

  /// No generation job with this id belongs to the calling device.
  static const String jobNotFound = 'job_not_found';

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
