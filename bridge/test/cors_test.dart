import 'dart:io';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/config/bridge_config_loader.dart';
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
      illustrationTimeoutSeconds: defaults.illustrationTimeoutSeconds,
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
      'http://127.42.0.8:52341',
    ]) {
      final response = await _send(
        testServer.handler,
        'GET',
        '/health',
        headers: <String, String>{'origin': origin},
      );
      expect(response.statusCode, 200);
      expect(response.headers['access-control-allow-origin'], origin);
      // Without the exposure a browser hides the ETag from the web app and
      // every illustration re-check becomes a full re-download.
      expect(response.headers['access-control-expose-headers'], 'etag');
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

  test(
    'config accepts only loopback, private, and Tailscale bind addresses',
    () {
      for (final address in <String>[
        'localhost',
        '127.0.0.1',
        '127.255.255.255',
        '::1',
        '10.0.0.1',
        '10.255.255.254',
        '172.16.0.1',
        '172.31.255.254',
        '192.168.1.20',
        '169.254.10.20',
        '100.64.0.1',
        '100.127.255.254',
        'fc00::1',
        'fdff::1',
        'fe80::1',
        'febf::1',
      ]) {
        expect(
          BridgeConfig.fromJson(<String, Object?>{
            'bindAddress': address,
          }).bindAddress,
          address,
          reason: address,
        );
      }
    },
  );

  test('config refuses wildcard, public, and non-local hostname binds', () {
    for (final address in <String>[
      '0.0.0.0',
      '::',
      '8.8.8.8',
      '2001:4860:4860::8888',
      '172.15.255.255',
      '172.32.0.0',
      '100.63.255.255',
      '100.128.0.0',
      'example.com',
    ]) {
      expect(
        () => BridgeConfig.fromJson(<String, Object?>{'bindAddress': address}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('bindAddress'),
          ),
        ),
        reason: address,
      );
    }
  });

  test('config accepts exact private http and public https origins', () {
    final origins = <String>[
      'http://localhost:5173',
      'http://127.42.0.8',
      'http://10.1.2.3:8765',
      'http://172.16.0.1',
      'http://172.31.255.254',
      'http://192.168.1.20:8765',
      'http://169.254.1.2',
      'http://100.64.0.1',
      'http://100.127.255.254',
      'http://[::1]:5173',
      'http://[fc00::1]',
      'http://[fdff::1]',
      'http://[fe80::1]',
      'http://[febf::1]',
      'https://stories.example.com',
      'https://8.8.8.8:443',
      'https://[2001:4860:4860::8888]',
    ];
    final config = BridgeConfig.fromJson(<String, Object?>{
      'allowedWebOrigins': origins,
    });
    expect(config.allowedWebOrigins, origins);
  });

  test('config refuses every non-origin or insecure public origin shape', () {
    for (final origin in <String>[
      '*',
      'https://*.example.com',
      'https://stories.example.com/',
      'https://stories.example.com/app',
      'https://stories.example.com?mode=family',
      'https://stories.example.com#family',
      'https://parent@stories.example.com',
      'ftp://stories.example.com',
      'stories.example.com',
      ' https://stories.example.com',
      'https://stories.example.com ',
      'https://stories.example.com:',
      'https://stories.example.com:0',
      'https://stories.example.com:65536',
      'http://stories.example.com',
      'http://8.8.8.8',
      'http://[2001:4860:4860::8888]',
    ]) {
      expect(
        () => BridgeConfig.fromJson(<String, Object?>{
          'allowedWebOrigins': <Object?>[origin],
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('allowedWebOrigins'),
          ),
        ),
        reason: origin,
      );
    }
  });

  test('config refuses a non-list origin setting', () {
    expect(
      () => BridgeConfig.fromJson(<String, Object?>{
        'allowedWebOrigins': 'http://192.168.1.20:8765',
      }),
      throwsFormatException,
    );
  });

  test('loader reports the refused field before server startup', () async {
    final root = await createTempRoot();
    final configFile = File(
      '${root.path}${Platform.pathSeparator}unsafe_bridge_config.json',
    );
    await configFile.writeAsString('{"bindAddress":"0.0.0.0"}');

    await expectLater(
      const BridgeConfigLoader().load(
        args: <String>['--config', configFile.path],
        workingDirectory: root,
      ),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('bindAddress'),
        ),
      ),
    );
  });
}
