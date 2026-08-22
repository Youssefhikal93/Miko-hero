import 'dart:typed_data';

import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/request_limits.dart';
import 'package:iam_hero_bridge/src/version.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test(
    'health reports unavailable ollama and comfyui when probes fail',
    () async {
      final testServer = await createTestServer(
        probeHttpClient: FakeProbeHttpClient(failAll: true),
      );
      addTearDown(testServer.close);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/health',
      );

      expect(status, 200);
      expect(body['version'], bridgeVersion);
      expect(body['uptimeSeconds'], isA<num>());
      expect(body['uptimeSeconds'] as num, isNonNegative);

      final statuses = body['statuses'] as Map<String, Object?>;
      expect(
        statuses.keys,
        containsAll(<String>['ollama', 'comfyui', 'library']),
      );

      for (final key in <String>['ollama', 'comfyui']) {
        final entry = statuses[key] as Map<String, Object?>;
        expect(entry['available'], isFalse, reason: '$key must be down');
        expect((entry['detail'] as String), isNotEmpty);
      }
    },
  );

  test(
    'health reports available services with the full response shape',
    () async {
      final testServer = await createTestServer();
      addTearDown(testServer.close);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/health',
      );

      expect(status, 200);
      expect(body['version'], bridgeVersion);
      final statuses = body['statuses'] as Map<String, Object?>;
      for (final key in <String>['ollama', 'comfyui', 'library']) {
        final entry = statuses[key] as Map<String, Object?>;
        expect(
          entry.keys,
          unorderedEquals(<String>['available', 'detail']),
          reason: '$key status shape',
        );
        expect(entry['available'], isTrue, reason: '$key must be available');
        expect((entry['detail'] as String), isNotEmpty);
      }

      final server = testServer.server;
      expect(server.pairingService.pendingCount, 0);
    },
  );

  test('oversized request bodies are rejected with the typed error', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);

    final oversized = Uint8List(maxRequestBodyBytes + 1);
    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/pair/request',
      body: oversized,
    );

    expect(status, 413);
    expect(errorCode(body), ApiErrorCode.bodyTooLarge);
  });

  test('bodies within the limit are accepted on public endpoints', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/pair/request',
      body: '{}',
    );
    expect(status, 201);
    expect(body.containsKey('pairingId'), isTrue);
  });
}
