import 'dart:io';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/server/app_server.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

Future<Response> _send(
  Handler handler,
  String method,
  String path, {
  Map<String, String>? headers,
}) {
  return Future.sync(
    () => handler(
      Request(method, Uri.parse('http://bridge.test$path'), headers: headers),
    ),
  );
}

/// Builds a server whose config lists [extraOrigins] as allowed web origins.
Future<Handler> _handlerWithOrigins(List<String> extraOrigins) async {
  final root = await createTempRoot();
  final library = MasterLibrary(
    rootPath: '${root.path}${Platform.pathSeparator}library',
  );
  await library.initialize();
  addTearDown(library.close);
  final defaults = BridgeConfig.defaults(workingDirectory: root.path);
  final server = AppServer(
    config: BridgeConfig(
      bindAddress: defaults.bindAddress,
      port: defaults.port,
      libraryPath: defaults.libraryPath,
      ollamaBaseUrl: defaults.ollamaBaseUrl,
      comfyUiBaseUrl: defaults.comfyUiBaseUrl,
      ollamaModel: defaults.ollamaModel,
      generationTimeoutSeconds: defaults.generationTimeoutSeconds,
      maxGenerationAttempts: defaults.maxGenerationAttempts,
      allowedWebOrigins: extraOrigins,
    ),
    library: library,
    probeHttpClient: FakeProbeHttpClient(),
  );
  return server.buildHandler();
}

void main() {
  test('loopback origins are allowed on any port', () async {
    final testServer = await createTestServer();
    for (final origin in <String>[
      'http://localhost:8090',
      'http://127.0.0.1:52341',
    ]) {
      final response = await _send(
        testServer.handler,
        'GET',
        '/health',
        headers: <String, String>{'origin': origin},
      );
      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], origin);
      expect(response.headers['vary'], 'Origin');
    }
  });

  test('preflight from a loopback origin is answered completely', () async {
    final testServer = await createTestServer();
    final response = await _send(
      testServer.handler,
      'OPTIONS',
      '/stories/generate',
      headers: <String, String>{
        'origin': 'http://127.0.0.1:8091',
        'access-control-request-method': 'POST',
        'access-control-request-headers': 'authorization, content-type',
      },
    );
    expect(response.statusCode, 204);
    expect(
      response.headers['access-control-allow-origin'],
      'http://127.0.0.1:8091',
    );
    expect(response.headers['access-control-allow-methods'], contains('POST'));
    expect(
      response.headers['access-control-allow-headers'],
      contains('authorization'),
    );
  });

  test('non-loopback origins receive no CORS consent by default', () async {
    final testServer = await createTestServer();
    final response = await _send(
      testServer.handler,
      'GET',
      '/health',
      headers: <String, String>{'origin': 'http://192.168.1.55:8090'},
    );
    expect(response.statusCode, 200);
    expect(response.headers.containsKey('access-control-allow-origin'), false);

    final preflight = await _send(
      testServer.handler,
      'OPTIONS',
      '/health',
      headers: <String, String>{'origin': 'https://evil.example'},
    );
    expect(preflight.statusCode, 204);
    expect(preflight.headers.containsKey('access-control-allow-origin'), false);
  });

  test('configured extra origins are allowed, others still refused', () async {
    final handler = await _handlerWithOrigins(<String>[
      'http://192.168.1.20:8765',
    ]);
    final allowed = await _send(
      handler,
      'GET',
      '/health',
      headers: <String, String>{'origin': 'http://192.168.1.20:8765'},
    );
    expect(
      allowed.headers['access-control-allow-origin'],
      'http://192.168.1.20:8765',
    );
    final refused = await _send(
      handler,
      'GET',
      '/health',
      headers: <String, String>{'origin': 'http://192.168.1.21:8765'},
    );
    expect(refused.headers.containsKey('access-control-allow-origin'), false);
  });

  test('requests without an Origin header pass through untouched', () async {
    final testServer = await createTestServer();
    final response = await _send(testServer.handler, 'GET', '/health');
    expect(response.statusCode, 200);
    expect(response.headers.containsKey('access-control-allow-origin'), false);
  });

  test('config refuses malformed origins and accepts bare ones', () {
    expect(
      () => BridgeConfig.fromJson(<String, Object?>{
        'allowedWebOrigins': <Object?>['http://192.168.1.20:8765/app'],
      }),
      throwsFormatException,
    );
    expect(
      () => BridgeConfig.fromJson(<String, Object?>{
        'allowedWebOrigins': 'http://192.168.1.20:8765',
      }),
      throwsFormatException,
    );
    final config = BridgeConfig.fromJson(<String, Object?>{
      'allowedWebOrigins': <Object?>['http://192.168.1.20:8765'],
    });
    expect(config.allowedWebOrigins, <String>['http://192.168.1.20:8765']);
  });
}
