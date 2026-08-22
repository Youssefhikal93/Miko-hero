import 'dart:convert';

import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Injectable clock for deterministic expiry behaviour.
class _FakeClock {
  /// Current simulated time returned by [call].
  DateTime now = DateTime.utc(2026, 8, 22, 12);

  /// Clock function passed into the pairing service.
  DateTime call() => now;
}

void main() {
  test(
    'pairing happy path issues a token that works on GET /devices',
    () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final (pairingId, code) = await issuePairing(testServer, printedCodes);

      final (confirmStatus, confirmBody) = await callJson(
        testServer.handler,
        'POST',
        '/pair/confirm',
        body: jsonEncode(<String, Object?>{
          'pairingId': pairingId,
          'code': code,
          'deviceName': 'Family tablet',
        }),
      );
      expect(confirmStatus, 200, reason: 'body was $confirmBody');
      final token = confirmBody['deviceToken'] as String;
      expect(token.length, greaterThanOrEqualTo(43));
      expect(confirmBody.containsKey('code'), isFalse);

      final (listStatus, listBody) = await callJson(
        testServer.handler,
        'GET',
        '/devices',
        headers: <String, String>{'authorization': 'Bearer $token'},
      );
      expect(listStatus, 200, reason: 'body was $listBody');
      final devices = listBody['devices'] as List<Object?>;
      expect(devices, hasLength(1));
      final device = devices.first as Map<String, Object?>;
      expect(device['name'], 'Family tablet');
      expect(device['createdAtUtc'], isA<String>());
      expect(
        jsonEncode(listBody).contains(token),
        isFalse,
        reason: 'tokens must never be listed',
      );
    },
  );

  test('wrong code is denied but the pairing stays alive', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final (pairingId, code) = await issuePairing(testServer, printedCodes);
    final wrongCode = code == '000000' ? '000001' : '000000';

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/pair/confirm',
      body: jsonEncode(<String, Object?>{
        'pairingId': pairingId,
        'code': wrongCode,
        'deviceName': 'Family tablet',
      }),
    );
    expect(status, 403);
    expect(errorCode(body), 'invalid_pairing_code');
    expect(body.containsKey('deviceToken'), isFalse);
  });

  test('expired code is denied with the typed expired error', () async {
    final clock = _FakeClock();
    final printedCodes = <String>[];
    final testServer = await createTestServer(
      clock: clock.call,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final (pairingId, code) = await issuePairing(testServer, printedCodes);

    clock.now = clock.now.add(const Duration(minutes: 2, seconds: 1));
    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/pair/confirm',
      body: jsonEncode(<String, Object?>{
        'pairingId': pairingId,
        'code': code,
        'deviceName': 'Family tablet',
      }),
    );
    expect(status, 410);
    expect(errorCode(body), 'pairing_expired');
  });

  test('a fifth wrong attempt invalidates even the correct code', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final (pairingId, code) = await issuePairing(testServer, printedCodes);
    final wrongCode = code == '000000' ? '000001' : '000000';

    for (var attempt = 0; attempt < 5; attempt++) {
      final (status, body) = await callJson(
        testServer.handler,
        'POST',
        '/pair/confirm',
        body: jsonEncode(<String, Object?>{
          'pairingId': pairingId,
          'code': wrongCode,
          'deviceName': 'Family tablet',
        }),
      );
      expect(status, 403, reason: 'attempt ${attempt + 1}: $body');
      expect(errorCode(body), 'invalid_pairing_code');
    }

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/pair/confirm',
      body: jsonEncode(<String, Object?>{
        'pairingId': pairingId,
        'code': code,
        'deviceName': 'Family tablet',
      }),
    );
    expect(status, 404);
    expect(errorCode(body), 'pairing_not_found');
  });

  test(
    'auth middleware rejects missing, malformed and revoked tokens',
    () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final (pairingId, code) = await issuePairing(testServer, printedCodes);
      final (_, confirmBody) = await callJson(
        testServer.handler,
        'POST',
        '/pair/confirm',
        body: jsonEncode(<String, Object?>{
          'pairingId': pairingId,
          'code': code,
          'deviceName': 'Revocable phone',
        }),
      );
      final token = confirmBody['deviceToken'] as String;

      Future<(int, Map<String, Object?>)> devicesWith(String? header) {
        return callJson(
          testServer.handler,
          'GET',
          '/devices',
          headers: header == null
              ? null
              : <String, String>{'authorization': header},
        );
      }

      var (status, body) = await devicesWith(null);
      expect(status, 401);
      expect(errorCode(body), 'unauthorized');

      (status, body) = await devicesWith('');
      expect(status, 401);

      (status, body) = await devicesWith('Bearer');
      expect(status, 401);

      (status, body) = await devicesWith('Bearer definitely-not-the-token');
      expect(status, 401);

      (status, body) = await devicesWith('Basic dXNlcjpwYXNz');
      expect(status, 401);

      (status, body) = await devicesWith('Bearer $token');
      expect(
        status,
        200,
        reason: 'the fresh token must work before revocation',
      );

      expect(
        testServer.server.deviceStore.revokeByTokenHash(sha256Hex(token)),
        isTrue,
      );

      (status, body) = await devicesWith('Bearer $token');
      expect(status, 401, reason: 'revoked tokens must stop working');
      expect(errorCode(body), 'unauthorized');
    },
  );
}
