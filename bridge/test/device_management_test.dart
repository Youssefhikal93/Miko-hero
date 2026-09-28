import 'package:test/test.dart';

import 'support/harness.dart';

/// Covers the paired-device list and removal the parent drives from the app.
void main() {
  test('the list marks the caller and reports last seen', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final tabletToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: 'Family tablet',
    );
    await pairDevice(testServer, printedCodes, deviceName: "Dad's phone");

    final devices = await listDevices(testServer, tabletToken);

    expect(devices, hasLength(2));
    final tablet = deviceNamed(devices, 'Family tablet');
    final phone = deviceNamed(devices, "Dad's phone");
    expect(tablet['isCaller'], isTrue);
    expect(phone['isCaller'], isFalse, reason: 'only one row is the caller');
    expect(
      tablet['lastSeenAtUtc'],
      isA<String>(),
      reason: 'the calling device was seen by this very call',
    );
    expect(
      phone['lastSeenAtUtc'],
      isNull,
      reason: 'a device that only paired has made no authenticated call',
    );
    expect(tablet['createdAtUtc'], isA<String>());
  });

  test('every authenticated call moves the last-seen moment', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final tabletToken = await pairDevice(testServer, printedCodes);
    final phoneToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: "Dad's phone",
    );

    final before = await listDevices(testServer, tabletToken);
    expect(deviceNamed(before, "Dad's phone")['lastSeenAtUtc'], isNull);

    final (phoneStatus, _) = await callJson(
      testServer.handler,
      'GET',
      '/devices',
      headers: authHeaders(phoneToken),
    );
    expect(phoneStatus, 200);

    final after = await listDevices(testServer, tabletToken);
    final seenAt = deviceNamed(after, "Dad's phone")['lastSeenAtUtc'];
    expect(
      seenAt,
      isA<String>(),
      reason: 'the phone authenticated, so the PC has now seen it',
    );
    expect(DateTime.parse(seenAt! as String).isUtc, isTrue);
  });

  test('a removed device is refused on its very next call', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final tabletToken = await pairDevice(testServer, printedCodes);
    final phoneToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: "Dad's phone",
    );
    final phoneId =
        deviceNamed(
              await listDevices(testServer, tabletToken),
              "Dad's phone",
            )['id']!
            as String;

    final (removeStatus, removeBody) = await callJson(
      testServer.handler,
      'DELETE',
      '/devices/$phoneId',
      headers: authHeaders(tabletToken),
    );
    expect(removeStatus, 200, reason: 'body was $removeBody');
    expect(removeBody['removed'], isTrue);
    expect(removeBody['id'], phoneId);

    final (refusedStatus, refusedBody) = await callJson(
      testServer.handler,
      'GET',
      '/devices',
      headers: authHeaders(phoneToken),
    );
    expect(refusedStatus, 401, reason: 'the removed token must stop working');
    expect(errorCode(refusedBody), 'unauthorized');

    final remaining = await listDevices(testServer, tabletToken);
    expect(remaining, hasLength(1));
    expect(remaining.single['name'], 'Family tablet');
  });

  test('a device cannot remove itself and keeps working', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final tabletToken = await pairDevice(testServer, printedCodes);
    final tabletId =
        (await listDevices(testServer, tabletToken)).single['id']! as String;

    final (status, body) = await callJson(
      testServer.handler,
      'DELETE',
      '/devices/$tabletId',
      headers: authHeaders(tabletToken),
    );

    expect(status, 409, reason: 'body was $body');
    expect(errorCode(body), 'cannot_remove_self');
    final devices = await listDevices(testServer, tabletToken);
    expect(devices, hasLength(1), reason: 'the caller must still be paired');
  });

  test('removing an unknown device is a typed 404', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final tabletToken = await pairDevice(testServer, printedCodes);

    final (status, body) = await callJson(
      testServer.handler,
      'DELETE',
      '/devices/device-that-never-existed',
      headers: authHeaders(tabletToken),
    );

    expect(status, 404, reason: 'body was $body');
    expect(errorCode(body), 'device_not_found');
  });

  test('an unauthenticated removal is refused and changes nothing', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final tabletToken = await pairDevice(testServer, printedCodes);
    final phoneToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: "Dad's phone",
    );
    final phoneId =
        deviceNamed(
              await listDevices(testServer, tabletToken),
              "Dad's phone",
            )['id']!
            as String;

    final (status, body) = await callJson(
      testServer.handler,
      'DELETE',
      '/devices/$phoneId',
    );

    expect(status, 401, reason: 'body was $body');
    expect(errorCode(body), 'unauthorized');
    final (phoneStatus, _) = await callJson(
      testServer.handler,
      'GET',
      '/devices',
      headers: authHeaders(phoneToken),
    );
    expect(phoneStatus, 200, reason: 'the phone must still be paired');
  });
}

/// Reads the active device list as seen by the holder of [token].
Future<List<Map<String, Object?>>> listDevices(
  TestServer testServer,
  String token,
) async {
  final (status, body) = await callJson(
    testServer.handler,
    'GET',
    '/devices',
    headers: authHeaders(token),
  );
  expect(status, 200, reason: 'body was $body');
  return (body['devices']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .toList(growable: false);
}

/// Picks the one listed device called [name], failing when it is absent.
Map<String, Object?> deviceNamed(
  List<Map<String, Object?>> devices,
  String name,
) {
  return devices.firstWhere(
    (device) => device['name'] == name,
    orElse: () => fail('No device named "$name" in $devices'),
  );
}
