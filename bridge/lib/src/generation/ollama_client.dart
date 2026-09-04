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

/// Budget for the unload call made after a job leaves the GPU.
///
/// Short on purpose: the story is already written or already failed, and the
/// only thing waiting on this is the release of the shared GPU lease.
const Duration ollamaUnloadTimeout = Duration(seconds: 5);

/// Budget for one call that asks a vision model to look at a photo.
///
/// Far below a story's budget on purpose. This is one small structured answer
/// about three colours, and the callers that want it are a photo upload and the
/// moment before a story starts — neither can afford to sit on the card for a
/// quarter of an hour waiting for a model that is not going to answer.
const Duration ollamaVisionCallTimeout = Duration(minutes: 2);

/// Budget for the call that spells one child's name in the four languages.
///
/// The tightest budget in the bridge, and deliberately so: this one is asked
/// *synchronously*, from a parent standing in the profile editor, and the whole
/// HTTP request it sits inside is capped at 20 seconds. Anything slower is not
/// a suggestion any more — the editor says so and the parent types the four
/// spellings, which is always allowed. A cold model on a busy card will miss
/// this; asking again once it is resident is cheap.
const Duration ollamaNameSpellingCallTimeout = Duration(seconds: 15);

/// Where the local Ollama is, which model it must answer with, and how long
/// one call to it may take.
///
/// Three values that only ever travel together. Handing callers the target
/// instead of the three fields is what keeps the queue from knowing how a URL,
/// a model tag and a duration combine into an outbound call.
class OllamaTarget {
  /// Creates a target from an already-validated base URL.
  const OllamaTarget({
    required this.baseUrl,
    required this.model,
    required this.callTimeout,
  });

  /// Base URL of the local Ollama API.
  final BaseUrl baseUrl;

  /// Model tag every call names, e.g. `gemma3:4b`.
  final String model;

  /// Wall-clock budget for one generation call — not for a whole job, which
  /// makes two.
  final Duration callTimeout;

  /// One generation call carrying [prompt] and the schema its answer must
  /// conform to.
  ///
  /// [images] is base64 for the one caller that has a picture to show — the
  /// character-sheet pass — and empty for every other call, which is what keeps
  /// a story request byte-for-byte the body it has always been.
  OllamaGenerateRequest generateRequest({
    required String prompt,
    required Map<String, Object?> format,
    List<String> images = const <String>[],
  }) {
    return OllamaGenerateRequest(
      baseUrl: baseUrl,
      model: model,
      prompt: prompt,
      format: format,
      timeout: callTimeout,
      images: images,
    );
  }

  /// The call that asks Ollama to drop [model] from the card again.
  OllamaUnloadRequest unloadRequest() {
    return OllamaUnloadRequest(
      baseUrl: baseUrl,
      model: model,
      timeout: ollamaUnloadTimeout,
    );
  }
}

/// One `/api/generate` call to the local Ollama server.
class OllamaGenerateRequest {
  /// Creates a request against [baseUrl] for [model].
  const OllamaGenerateRequest({
    required this.baseUrl,
    required this.model,
    required this.prompt,
    required this.format,
    required this.timeout,
    this.images = const <String>[],
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

  /// Base64-encoded images the model is asked to look at.
  ///
  /// Empty for every text call, which is all story generation makes. The one
  /// caller that fills it is the character-sheet pass, which shows a child's
  /// reference photo to a vision model exactly once per photo. Those bytes are
  /// the most private thing the bridge holds: like [prompt], this list is never
  /// logged and never echoed.
  final List<String> images;

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
  ///
  /// `images` is written only when there is one: a text-only model handed an
  /// empty `images` array can refuse the whole call, and every story request
  /// must keep the body it has always sent.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'model': model,
      'prompt': prompt,
      'stream': false,
      'think': false,
      'format': format,
      if (images.isNotEmpty) 'images': images,
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
