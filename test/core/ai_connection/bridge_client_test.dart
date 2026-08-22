import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies the observable contract of the typed PC bridge client.
///
/// Only the HTTP boundary is replaced, so encoding, headers, bounded failures,
/// and the mapping from the bridge's typed error codes stay honest.
void main() {
  final baseUrl = Uri.parse(defaultBridgeBaseUrl);

  test('an address without a usable origin is refused', () {
    expect(parseBridgeBaseUrl('http://127.0.0.1:8765'), isNotNull);
    expect(parseBridgeBaseUrl('https://pc.local'), isNotNull);
    expect(parseBridgeBaseUrl('http://127.0.0.1:8765/'), isNotNull);
    expect(parseBridgeBaseUrl(''), isNull);
    expect(parseBridgeBaseUrl('127.0.0.1:8765'), isNull);
    expect(parseBridgeBaseUrl('ftp://127.0.0.1'), isNull);
    expect(parseBridgeBaseUrl('http://127.0.0.1?token=x'), isNull);
  });

  test('health reports the three local dependencies', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      expect(request.url.path, '/health');
      return bridgeJsonResponse(<String, Object>{
        'version': '0.1.0',
        'uptimeSeconds': 12.4,
        'statuses': <String, Object>{
          'ollama': <String, Object>{'available': true, 'detail': 'Ready.'},
          'comfyui': <String, Object>{'available': false, 'detail': 'Down.'},
          'library': <String, Object>{'available': true, 'detail': 'Open.'},
        },
      });
    });
    final client = BridgeClient(httpClient: httpClient, baseUrl: baseUrl);

    final health = await client.readHealth();

    expect(health.version, '0.1.0');
    expect(health.isOllamaAvailable, isTrue);
    expect(health.isComfyUiAvailable, isFalse);
    expect(health.isLibraryAvailable, isTrue);
  });

  test('a story request travels as UTF-8 JSON with the device token', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'job-1',
        'queuePosition': 2,
      }, statusCode: 202);
    });
    final client = BridgeClient(
      httpClient: httpClient,
      baseUrl: baseUrl,
      deviceToken: 'device-token',
    );

    final submission = await client.submitStory(
      const BridgeStoryRequest(
        profileId: 'miko',
        heroName: 'نور',
        ageYears: 6,
        genderContext: 'girl',
        languageCode: 'ar',
        theme: 'مهرجان الفوانيس',
        moral: 'المشاركة',
        pageCount: 8,
        illustrationStyle: 'watercolor',
      ),
    );

    expect(submission.jobId, 'job-1');
    expect(submission.queuePosition, 2);
    final sentRequest = httpClient.requests.single;
    expect(sentRequest.headers['authorization'], 'Bearer device-token');
    expect(sentRequest.headers['content-type'], contains('charset=utf-8'));
    final body =
        jsonDecode(utf8.decode(sentRequest.bodyBytes)) as Map<String, Object?>;
    expect(body['heroName'], 'نور');
    expect(body['theme'], 'مهرجان الفوانيس');
    expect(body['languageCode'], 'ar');
    expect(body['pageCount'], 8);
  });

  test('an unpaired client never sends an authenticated call', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{});
    });
    final client = BridgeClient(httpClient: httpClient, baseUrl: baseUrl);

    await expectLater(
      client.readJob('job-1'),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.notPaired,
        ),
      ),
    );
    expect(httpClient.requests, isEmpty);
  });

  test('typed bridge error codes become typed client failures', () async {
    for (final testCase in <(String, int, BridgeFailure)>[
      ('unauthorized', 401, BridgeFailure.unauthorized),
      ('rate_limited', 429, BridgeFailure.rateLimited),
      ('pairing_not_found', 404, BridgeFailure.pairingNotFound),
      ('pairing_expired', 410, BridgeFailure.pairingExpired),
      ('invalid_pairing_code', 403, BridgeFailure.invalidPairingCode),
      ('invalid_field', 400, BridgeFailure.invalidRequest),
      ('job_not_found', 404, BridgeFailure.jobNotFound),
      ('ollama_timeout', 500, BridgeFailure.generationFailed),
      ('surprise_code', 500, BridgeFailure.bridgeError),
    ]) {
      final httpClient = FakeBridgeHttpClient((request) async {
        return bridgeErrorResponse(testCase.$1, testCase.$2);
      });
      final client = BridgeClient(
        httpClient: httpClient,
        baseUrl: baseUrl,
        deviceToken: 'device-token',
      );

      await expectLater(
        client.readJob('job-1'),
        throwsA(
          isA<BridgeException>().having(
            (error) => error.failure,
            'failure',
            testCase.$3,
          ),
        ),
        reason: testCase.$1,
      );
    }
  });

  test('a dead address and a slow bridge are told apart', () async {
    final unreachable = BridgeClient(
      httpClient: FakeBridgeHttpClient((request) async {
        throw http.ClientException('Connection refused.', request.url);
      }),
      baseUrl: baseUrl,
    );
    final slow = BridgeClient(
      httpClient: FakeBridgeHttpClient((request) async {
        throw TimeoutException('Too slow.');
      }),
      baseUrl: baseUrl,
    );

    await expectLater(
      unreachable.readHealth(),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.unreachable,
        ),
      ),
    );
    await expectLater(
      slow.readHealth(),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.timedOut,
        ),
      ),
    );
  });

  test('an answer that is not the agreed shape is refused', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{'unexpected': true});
    });
    final client = BridgeClient(httpClient: httpClient, baseUrl: baseUrl);

    await expectLater(
      client.readHealth(),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.invalidResponse,
        ),
      ),
    );
  });

  test('pairing returns the identity and then the one-time token', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return switch (request.url.path) {
        '/pair/request' => bridgeJsonResponse(<String, Object>{
          'pairingId': 'pairing-1',
        }),
        '/pair/confirm' => bridgeJsonResponse(<String, Object>{
          'deviceToken': 'issued-token',
        }),
        _ => bridgeErrorResponse('job_not_found', 404),
      };
    });
    final client = BridgeClient(httpClient: httpClient, baseUrl: baseUrl);

    final pairingId = await client.requestPairing();
    final token = await client.confirmPairing(
      pairingId: pairingId,
      code: '123456',
      deviceName: 'Family tablet',
    );

    expect(pairingId, 'pairing-1');
    expect(token, 'issued-token');
    final confirmBody = httpClient.jsonBodiesFor('/pair/confirm').single;
    expect(confirmBody['pairingId'], 'pairing-1');
    expect(confirmBody['code'], '123456');
    expect(confirmBody['deviceName'], 'Family tablet');
  });
}
