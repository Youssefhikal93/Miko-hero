import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/probes/probe_client.dart';
import 'package:iam_hero_bridge/src/server/app_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

/// A fake [ProbeHttpClient] whose behavior is fully scripted per test.
///
/// This is the injection seam required by the brief: Ollama and ComfyUI are
/// mocked at this boundary, so no real services are ever contacted.
class FakeProbeHttpClient implements ProbeHttpClient {
  /// Creates a client. When [failAll] is set every request throws, which
  /// simulates both local services being down. Otherwise canned "available"
  /// answers are returned.
  FakeProbeHttpClient({this.failAll = false});

  /// Whether every probe request should fail.
  final bool failAll;

  /// URLs seen by this client, in request order (for assertions).
  final List<Uri> requestedUrls = <Uri>[];

  @override
  Future<ProbeHttpResponse> get(Uri url, {required Duration timeout}) async {
    requestedUrls.add(url);
    if (failAll) {
      throw const SocketException('Fake probe failure.');
    }
    final path = url.path;
    if (path.endsWith('/api/version')) {
      return _json(200, <String, Object?>{'version': '0.1.17'});
    }
    if (path.endsWith('/api/tags')) {
      return _json(200, <String, Object?>{
        'models': <Object?>[
          <String, Object?>{'name': 'gemma3:4b'},
        ],
      });
    }
    if (path.endsWith('/system_stats')) {
      return _json(200, <String, Object?>{
        'system': <String, Object?>{'os': 'fake'},
      });
    }
    return _json(404, <String, Object?>{'error': 'not found'});
  }

  ProbeHttpResponse _json(int status, Map<String, Object?> body) {
    return ProbeHttpResponse(
      statusCode: status,
      bodyBytes: Uint8List.fromList(utf8.encode(jsonEncode(body))),
    );
  }
}

/// Scripted behaviour of one fake Ollama call.
typedef FakeOllamaResponder =
    Future<OllamaGenerateResponse> Function(
      OllamaGenerateRequest request,
      CancellationToken cancellation,
    );

/// A fake [OllamaStoryClient] scripted per test.
///
/// This is the only mocked boundary in the generation tests: everything
/// between the HTTP endpoint and this client is the real implementation.
class FakeOllamaStoryClient implements OllamaStoryClient {
  /// Creates a client driven by [responder].
  FakeOllamaStoryClient(this.responder);

  /// Answers every call with [payload] inside an Ollama envelope.
  factory FakeOllamaStoryClient.answering(String payload) {
    return FakeOllamaStoryClient(
      (OllamaGenerateRequest request, CancellationToken cancellation) async =>
          ollamaEnvelope(payload),
    );
  }

  /// Fails every call by throwing [error], like a broken transport.
  factory FakeOllamaStoryClient.failing(Object error) {
    return FakeOllamaStoryClient(
      (OllamaGenerateRequest request, CancellationToken cancellation) async =>
          throw error,
    );
  }

  /// Behaviour invoked for every call.
  final FakeOllamaResponder responder;

  /// Requests seen by this client, in call order (for assertions).
  final List<OllamaGenerateRequest> requests = <OllamaGenerateRequest>[];

  @override
  Future<OllamaGenerateResponse> generate(
    OllamaGenerateRequest request, {
    required CancellationToken cancellation,
  }) {
    requests.add(request);
    return responder(request, cancellation);
  }
}

/// Wraps a model answer in the non-streaming `/api/generate` envelope.
OllamaGenerateResponse ollamaEnvelope(String payload, {int statusCode = 200}) {
  return OllamaGenerateResponse(
    statusCode: statusCode,
    bodyBytes: Uint8List.fromList(
      utf8.encode(
        jsonEncode(<String, Object?>{
          'model': 'gemma3:4b',
          'response': payload,
          'done': true,
        }),
      ),
    ),
  );
}

/// One test server plus everything needed to drive it without sockets.
class TestServer {
  /// Creates a server over an initialized library rooted inside [root].
  TestServer({required this.root, required this.library, required this.server})
    : handler = server.buildHandler();

  /// Temporary directory backing the master library; deleted on cleanup.
  final Directory root;

  /// Initialized master library under [root].
  final MasterLibrary library;

  /// The wired application server.
  final AppServer server;

  /// Request pipeline; invoke directly with shelf [Request]s.
  final Handler handler;

  /// Stops any unfinished generation job and closes the database.
  void close() {
    server.generationQueue.shutdown();
    library.close();
  }

  /// Number of rows currently stored in [table].
  int countRows(String table) {
    final rows = library.database.select(
      'SELECT COUNT(*) AS total FROM $table',
    );
    return rows.first['total']! as int;
  }

  /// Asserts that no story, page, illustration or profile was written.
  void expectEmptyLibrary() {
    for (final table in <String>[
      'profiles',
      'stories',
      'story_pages',
      'illustrations',
    ]) {
      expect(countRows(table), 0, reason: '$table must stay empty');
    }
  }
}

/// Builds a default configuration whose library lives inside [directory].
BridgeConfig testConfig(Directory directory) {
  return BridgeConfig.defaults(workingDirectory: directory.path);
}

/// Creates a fresh temp directory that is removed when the test ends.
Future<Directory> createTempRoot() async {
  final directory = await Directory.systemTemp.createTemp(
    'iam_hero_bridge_test',
  );
  addTearDown(() {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });
  return directory;
}

/// Creates a [TestServer] over a fresh temp library and registers cleanup.
Future<TestServer> createTestServer({
  ProbeHttpClient? probeHttpClient,
  OllamaStoryClient? ollamaClient,
  DateTime Function()? clock,
  void Function(String message)? notifyCode,
}) async {
  final root = await createTempRoot();
  final library = MasterLibrary(
    rootPath: '${root.path}${Platform.pathSeparator}library',
  );
  await library.initialize();
  addTearDown(library.close);
  final server = AppServer(
    config: testConfig(root),
    library: library,
    probeHttpClient: probeHttpClient ?? FakeProbeHttpClient(),
    ollamaClient:
        ollamaClient ??
        FakeOllamaStoryClient.failing(
          const SocketException('No Ollama in this test.'),
        ),
    clock: clock,
    notifyCode: notifyCode,
  );
  return TestServer(root: root, library: library, server: server);
}

/// Sends [method] [path] through [handler] and returns status + JSON body.
Future<(int, Map<String, Object?>)> callJson(
  Handler handler,
  String method,
  String path, {
  Map<String, String>? headers,
  Object? body,
}) async {
  final request = Request(
    method,
    Uri.parse('http://bridge.test$path'),
    headers: headers,
    body: body,
  );
  final response = await handler(request);
  final raw = await response.readAsString();
  final Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    fail('Expected a JSON response but got: $raw');
  }
  if (decoded is! Map<String, Object?>) {
    fail('Expected a JSON object response but got: $raw');
  }
  return (response.statusCode, decoded);
}

/// Extracts `error.code` from a typed error envelope, failing if absent.
String errorCode(Map<String, Object?> body) {
  final error = body['error'];
  if (error is! Map<String, Object?>) {
    fail('Expected a typed error envelope but got: $body');
  }
  return error['code'] as String;
}

/// Issues one pairing request against [server] and returns its id and the
/// code captured from the console callback.
Future<(String, String)> issuePairing(
  TestServer testServer,
  List<String> printedCodes,
) async {
  final (status, body) = await callJson(
    testServer.handler,
    'POST',
    '/pair/request',
  );
  expect(status, 201, reason: 'body was $body');
  expect(body.containsKey('code'), isFalse, reason: 'code must not leak');
  expect(printedCodes, isNotEmpty);
  final code = RegExp(
    r'^Pairing code: (\d{6}) ',
  ).firstMatch(printedCodes.last)!.group(1)!;
  return (body['pairingId'] as String, code);
}

/// Runs a full pairing ceremony and returns the device's bearer token.
Future<String> pairDevice(
  TestServer testServer,
  List<String> printedCodes, {
  String deviceName = 'Family tablet',
}) async {
  final (pairingId, code) = await issuePairing(testServer, printedCodes);
  final (status, body) = await callJson(
    testServer.handler,
    'POST',
    '/pair/confirm',
    body: jsonEncode(<String, Object?>{
      'pairingId': pairingId,
      'code': code,
      'deviceName': deviceName,
    }),
  );
  expect(status, 200, reason: 'body was $body');
  return body['deviceToken']! as String;
}

/// Authorization header carrying [token].
Map<String, String> authHeaders(String token) {
  return <String, String>{'authorization': 'Bearer $token'};
}
