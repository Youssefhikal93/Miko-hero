import 'dart:async';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:shelf/shelf.dart';

/// Maximum accepted request body size: 25 MB.
const int maxRequestBodyBytes = 25 * 1024 * 1024;

/// Default wall-clock budget for one request.
const Duration defaultRequestTimeout = Duration(seconds: 20);

/// Middleware that buffers the body and rejects requests larger than
/// [maxBytes] with a typed `413` error before any handler sees them.
Middleware requestBodyLimit({int maxBytes = maxRequestBodyBytes}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final Uint8List body = await _readBounded(request, maxBytes);
      if (body.length > maxBytes) {
        throw ApiError(
          413,
          ApiErrorCode.bodyTooLarge,
          'Request body exceeds the ${maxBytes ~/ (1024 * 1024)} MB limit.',
        );
      }
      final Request boundedRequest = request.change(body: body);
      return innerHandler(boundedRequest);
    };
  };
}

Future<Uint8List> _readBounded(Request request, int maxBytes) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in request.read()) {
    builder.add(chunk);
    if (builder.length > maxBytes) {
      // Stop reading early; the caller rejects with 413 once we return.
      return builder.takeBytes();
    }
  }
  return builder.takeBytes();
}

/// Middleware that fails slow handlers with a typed `503` after [timeout].
///
/// The underlying computation is not cancelled (Dart cannot preempt it), but
/// the client receives an explicit timeout instead of hanging forever.
Middleware requestTimeout({Duration timeout = defaultRequestTimeout}) {
  return (Handler innerHandler) {
    return (Request request) {
      final Future<Response> handled = Future.sync(() => innerHandler(request));
      return handled.timeout(
        timeout,
        onTimeout: () => throw ApiError(
          503,
          ApiErrorCode.requestTimeout,
          'The bridge did not answer within ${timeout.inSeconds} seconds.',
        ),
      );
    };
  };
}
