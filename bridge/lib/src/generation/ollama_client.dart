import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/base_url.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';

/// Path of the one Ollama endpoint the bridge calls, for generating and for
/// unloading alike.
const String ollamaGeneratePath = '/api/generate';

/// Largest Ollama answer the bridge is willing to buffer (4 MB).
///
/// A ten-page story is a few kilobytes; anything beyond this is a broken or
/// runaway model and is aborted instead of filling memory.
const int maxOllamaResponseBytes = 4 * 1024 * 1024;

/// One `/api/generate` call to the local Ollama server.
class OllamaGenerateRequest {
  /// Creates a request against [baseUrl] for [model].
  const OllamaGenerateRequest({
    required this.baseUrl,
    required this.model,
    required this.prompt,
    required this.format,
    required this.timeout,
  });

  /// Base URL of the local Ollama API, e.g. `http://127.0.0.1:11434`.
  final BaseUrl baseUrl;

  /// Model tag to generate with, e.g. `gemma3:4b`.
  final String model;

  /// Full prompt. Private family content: never logged.
  final String prompt;

  /// JSON schema the answer must conform to (Ollama's `format` field).
  final Map<String, Object?> format;

  /// Wall-clock budget for the whole call.
  final Duration timeout;

  /// The `/api/generate` endpoint derived from [baseUrl].
  Uri get endpoint => baseUrl.resolve(ollamaGeneratePath);

  /// The request body Ollama expects.
  ///
  /// `stream` is always false: the bridge wants one complete, schema-checked
  /// answer, not a token stream.
  ///
  /// `think` is always false. Reasoning models such as `qwen3.5:*` otherwise
  /// spend the answer in Ollama's `thinking` field and return an empty
  /// `response`, which the bridge can only read as "no story". Models without
  /// a thinking mode ignore the flag.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'model': model,
      'prompt': prompt,
      'stream': false,
      'think': false,
      'format': format,
    };
  }

  /// The body encoded as explicit UTF-8 bytes.
  ///
  /// Encoding is done here (and paired with an explicit `charset=utf-8`
  /// content type) because Arabic prompts corrupt when the transport is left
  /// to guess an encoding.
  Uint8List encodeBody() => utf8.encode(jsonEncode(toJson()));
}

/// One request to unload a model from Ollama after generation finishes.
class OllamaUnloadRequest {
  /// Creates an unload request against [baseUrl] for [model].
  const OllamaUnloadRequest({
    required this.baseUrl,
    required this.model,
    required this.timeout,
  });

  /// Base URL of the local Ollama API, e.g. `http://127.0.0.1:11434`.
  final BaseUrl baseUrl;

  /// Model tag to unload, e.g. `gemma3:4b`.
  final String model;

  /// Wall-clock budget for the unload call.
  final Duration timeout;

  /// The `/api/generate` endpoint derived from [baseUrl].
  Uri get endpoint => baseUrl.resolve(ollamaGeneratePath);

  /// The request body Ollama expects for an explicit unload.
  Map<String, Object?> toJson() {
    return <String, Object?>{'model': model, 'keep_alive': 0};
  }

  /// The body encoded as explicit UTF-8 bytes.
  Uint8List encodeBody() => utf8.encode(jsonEncode(toJson()));
}

/// Raw answer of one `/api/generate` call.
class OllamaGenerateResponse {
  /// Creates a response.
  const OllamaGenerateResponse({
    required this.statusCode,
    required this.bodyBytes,
  });

  /// HTTP status code returned by Ollama.
  final int statusCode;

  /// Raw response body bytes, decoded on demand.
  final Uint8List bodyBytes;

  /// Decodes the body as UTF-8 text.
  String get bodyText => utf8.decode(bodyBytes, allowMalformed: true);
}

/// Abstraction over the single outbound call story generation makes.
///
/// This is the seam tests replace: no real Ollama server is ever needed.
/// Implementations propagate transport failures ([SocketException],
/// [TimeoutException], [HttpException]); the job engine maps them to typed
/// failure codes.
abstract class OllamaStoryClient {
  /// Posts [request] to Ollama and returns its raw answer.
  ///
  /// Aborts the in-flight request as soon as [cancellation] is cancelled.
  Future<OllamaGenerateResponse> generate(
    OllamaGenerateRequest request, {
    required CancellationToken cancellation,
  });

  /// Asks Ollama to unload the model named by [request].
  Future<void> unload(OllamaUnloadRequest request);
}

/// Production [OllamaStoryClient] backed by `dart:io`.
class IoOllamaStoryClient implements OllamaStoryClient {
  /// Creates the production IO-backed client.
  const IoOllamaStoryClient();

  /// Shared client. Generation is single-threaded by design, so one
  /// connection per host is enough.
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 5)
    ..maxConnectionsPerHost = 2
    ..autoUncompress = true;

  @override
  Future<OllamaGenerateResponse> generate(
    OllamaGenerateRequest request, {
    required CancellationToken cancellation,
  }) {
    final handle = _AbortHandle();
    return _send(request, cancellation, handle).timeout(
      request.timeout,
      onTimeout: () {
        final timeout = TimeoutException(
          'Ollama did not answer in time.',
          request.timeout,
        );
        handle.abort(timeout);
        throw timeout;
      },
    );
  }

  @override
  Future<void> unload(OllamaUnloadRequest request) {
    final handle = _AbortHandle();
    return _sendUnload(request, handle).timeout(
      request.timeout,
      onTimeout: () {
        final timeout = TimeoutException(
          'Ollama did not unload the model in time.',
          request.timeout,
        );
        handle.abort(timeout);
        throw timeout;
      },
    );
  }

  Future<OllamaGenerateResponse> _send(
    OllamaGenerateRequest request,
    CancellationToken cancellation,
    _AbortHandle handle,
  ) async {
    final Uint8List body = request.encodeBody();
    final HttpClientRequest httpRequest = await _client.postUrl(
      request.endpoint,
    );
    handle.attach(httpRequest);
    unawaited(
      cancellation.whenCancelled.then((_) {
        handle.abort(
          const GenerationException(
            GenerationFailureCode.cancelled,
            'Generation was cancelled.',
          ),
        );
      }),
    );
    try {
      httpRequest.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
      httpRequest.contentLength = body.length;
      httpRequest.add(body);
      final HttpClientResponse response = await httpRequest.close();
      final Uint8List bytes = await _collectBody(response, handle);
      return OllamaGenerateResponse(
        statusCode: response.statusCode,
        bodyBytes: bytes,
      );
    } finally {
      handle.settle();
    }
  }

  Future<void> _sendUnload(
    OllamaUnloadRequest request,
    _AbortHandle handle,
  ) async {
    final Uint8List body = request.encodeBody();
    final HttpClientRequest httpRequest = await _client.postUrl(
      request.endpoint,
    );
    handle.attach(httpRequest);
    try {
      httpRequest.headers.set(
        HttpHeaders.contentTypeHeader,
        'application/json; charset=utf-8',
      );
      httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
      httpRequest.contentLength = body.length;
      httpRequest.add(body);
      final HttpClientResponse response = await httpRequest.close();
      await response.drain<void>();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Ollama answered HTTP ${response.statusCode} while unloading.',
          uri: request.endpoint,
        );
      }
    } finally {
      handle.settle();
    }
  }

  Future<Uint8List> _collectBody(
    HttpClientResponse response,
    _AbortHandle handle,
  ) {
    final completer = Completer<Uint8List>();
    final builder = BytesBuilder(copy: false);
    late StreamSubscription<List<int>> subscription;
    subscription = response.listen(
      (chunk) {
        builder.add(chunk);
        if (builder.length > maxOllamaResponseBytes) {
          subscription.cancel();
          handle.abort(
            const GenerationException(
              GenerationFailureCode.invalidModelOutput,
              'The model answer exceeded the accepted size.',
            ),
          );
          if (!completer.isCompleted) {
            completer.completeError(
              const GenerationException(
                GenerationFailureCode.invalidModelOutput,
                'The model answer exceeded the accepted size.',
              ),
            );
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(builder.takeBytes());
        }
      },
      onError: (Object error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      cancelOnError: true,
    );
    return completer.future;
  }
}

/// Holds the in-flight request so timeout and cancellation can abort it.
class _AbortHandle {
  HttpClientRequest? _request;
  bool _settled = false;

  void attach(HttpClientRequest request) => _request = request;

  void settle() => _settled = true;

  void abort(Object reason) {
    if (_settled) {
      return;
    }
    _request?.abort(reason);
  }
}
