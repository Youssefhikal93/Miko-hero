import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:test/test.dart';

/// A local HTTP server standing in for Ollama.
///
/// This keeps the mocking at the HTTP boundary while exercising the real
/// production client: encoding, headers, cancellation and timeouts.
class _StubOllama {
  _StubOllama(this._server) {
    unawaited(_serve());
  }

  static Future<_StubOllama> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return _StubOllama(server);
  }

  final HttpServer _server;

  /// Base URL clients should point at.
  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  /// Bytes of the last received request body.
  List<int> receivedBody = const <int>[];

  /// Content type of the last received request.
  String? receivedContentType;

  /// Completes once a request has been received.
  final Completer<void> received = Completer<void>();

  /// Delay applied before answering; used for timeout and abort tests.
  Duration answerDelay = Duration.zero;

  /// Payload placed in the Ollama `response` field.
  String payload = '{"title":"ok","pages":[]}';

  Future<void> _serve() async {
    await for (final request in _server) {
      receivedContentType = request.headers.contentType?.toString();
      receivedBody = await request.expand((chunk) => chunk).toList();
      if (!received.isCompleted) {
        received.complete();
      }
      if (answerDelay > Duration.zero) {
        await Future<void>.delayed(answerDelay);
      }
      request.response.headers.contentType = ContentType.json;
      request.response.add(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'model': 'gemma3:4b',
            'response': payload,
            'done': true,
          }),
        ),
      );
      await request.response.close();
    }
  }

  /// Stops the stub server.
  Future<void> close() => _server.close(force: true);
}

OllamaGenerateRequest _request(
  String baseUrl, {
  String prompt = 'Write a story.',
  Duration timeout = const Duration(seconds: 10),
}) {
  return OllamaGenerateRequest(
    baseUrl: baseUrl,
    model: 'gemma3:4b',
    prompt: prompt,
    format: <String, Object?>{'type': 'object'},
    timeout: timeout,
  );
}

void main() {
  test('the request is sent as UTF-8 bytes with an explicit charset', () async {
    final stub = await _StubOllama.start();
    addTearDown(stub.close);
    const arabicPrompt = 'اكتب قصة عن فانوس صغير.';

    final response = await const IoOllamaStoryClient().generate(
      _request(stub.baseUrl, prompt: arabicPrompt),
      cancellation: CancellationToken(),
    );

    expect(response.statusCode, 200);
    expect(response.bodyText, contains('"done":true'));
    expect(stub.receivedContentType, 'application/json; charset=utf-8');
    final decoded =
        jsonDecode(utf8.decode(stub.receivedBody))! as Map<String, Object?>;
    expect(
      decoded['prompt'],
      arabicPrompt,
      reason: 'Arabic must survive the transport unchanged',
    );
    expect(decoded['stream'], isFalse);
    expect(
      decoded['think'],
      isFalse,
      reason:
          'thinking models otherwise put the JSON in `thinking` and '
          'leave `response` empty',
    );
    expect(decoded['model'], 'gemma3:4b');
  });

  test('cancelling aborts the in-flight request', () async {
    final stub = await _StubOllama.start();
    addTearDown(stub.close);
    stub.answerDelay = const Duration(seconds: 30);
    final token = CancellationToken();

    final pending = const IoOllamaStoryClient().generate(
      _request(stub.baseUrl),
      cancellation: token,
    );
    await stub.received.future;
    token.cancel();

    await expectLater(
      pending,
      throwsA(
        isA<GenerationException>().having(
          (error) => error.code,
          'code',
          GenerationFailureCode.cancelled,
        ),
      ),
    );
  });

  test('a slow answer fails with a timeout', () async {
    final stub = await _StubOllama.start();
    addTearDown(stub.close);
    stub.answerDelay = const Duration(seconds: 30);

    await expectLater(
      const IoOllamaStoryClient().generate(
        _request(stub.baseUrl, timeout: const Duration(milliseconds: 200)),
        cancellation: CancellationToken(),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('an unreachable server surfaces a socket failure', () async {
    final stub = await _StubOllama.start();
    final deadBaseUrl = stub.baseUrl;
    await stub.close();

    await expectLater(
      const IoOllamaStoryClient().generate(
        _request(deadBaseUrl, timeout: const Duration(seconds: 5)),
        cancellation: CancellationToken(),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('the endpoint is derived from the configured base URL', () {
    expect(
      _request('http://127.0.0.1:11434').endpoint.toString(),
      'http://127.0.0.1:11434/api/generate',
    );
    expect(
      _request('http://127.0.0.1:11434/').endpoint.toString(),
      'http://127.0.0.1:11434/api/generate',
    );
  });
}
