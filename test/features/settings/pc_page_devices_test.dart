import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/seeded_device.dart';

/// Verifies the paired-device list the parent manages on The PC page.
///
/// The list lives on the parent-gated `/settings/pc` route, so nothing here is
/// reachable from a child-facing screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the card names every device the PC still trusts', (
    tester,
  ) async {
    await _storeFamily();
    await _pumpSettings(tester, _bridgeWithTwoDevices());

    expect(find.text('Devices paired with the PC'), findsOneWidget);
    expect(find.text('Family tablet · this device'), findsOneWidget);
    expect(find.text("Dad's phone"), findsOneWidget);
    expect(
      find.textContaining('Last seen Sep 1, 2026'),
      findsOneWidget,
      reason: 'a device that has called shows when the PC last heard it',
    );
    expect(
      find.textContaining('Not used since pairing'),
      findsOneWidget,
      reason: 'a device that never called must not claim a last-seen moment',
    );
    expect(find.textContaining('Paired Aug 22, 2026'), findsOneWidget);
  });

  testWidgets('this device offers no remove control', (tester) async {
    await _storeFamily();
    await _pumpSettings(tester, _bridgeWithTwoDevices());

    expect(
      find.byKey(const ValueKey<String>('remove-paired-device-device-a')),
      findsNothing,
      reason: 'the PC refuses a self-removal, so it is never offered',
    );
    expect(
      find.byKey(const ValueKey<String>('remove-paired-device-device-b')),
      findsOneWidget,
    );
  });

  testWidgets('removing another device asks the PC once and reports it', (
    tester,
  ) async {
    await _storeFamily();
    final bridge = _bridgeWithTwoDevices();
    await _pumpSettings(tester, bridge);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('remove-paired-device-device-b')),
    );
    expect(find.text("Remove Dad's phone?"), findsOneWidget);
    await _tap(
      tester,
      find.byKey(const ValueKey<String>('confirm-remove-paired-device')),
    );

    expect(bridge.callsTo('/devices/device-b'), 1);
    expect(
      find.text("Dad's phone can no longer reach the PC"),
      findsOneWidget,
      reason: 'the outcome is reported in the settings snackbar idiom',
    );
    expect(
      find.text("Dad's phone"),
      findsNothing,
      reason: 'the list is read from the PC again after the removal',
    );
    expect(find.text('Family tablet · this device'), findsOneWidget);
  });

  testWidgets('cancelling the confirmation leaves the PC untouched', (
    tester,
  ) async {
    await _storeFamily();
    final bridge = _bridgeWithTwoDevices();
    await _pumpSettings(tester, bridge);

    await _tap(
      tester,
      find.byKey(const ValueKey<String>('remove-paired-device-device-b')),
    );
    await _tap(tester, find.text('Cancel'));

    expect(bridge.callsTo('/devices/device-b'), 0);
    expect(find.text("Dad's phone"), findsOneWidget);
  });

  testWidgets('a PC that cannot be reached says so and offers a retry', (
    tester,
  ) async {
    await _storeFamily();
    await _pumpSettings(
      tester,
      FakeBridgeHttpClient((request) async {
        throw http.ClientException('Connection refused.', request.url);
      }),
    );

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey<String>('paired-devices-failure')),
          )
          .data,
      'The PC did not answer. Check that the bridge is running and that the '
      'address is correct.',
    );
    expect(
      find.byKey(const ValueKey<String>('paired-devices-retry')),
      findsOneWidget,
    );
  });

  testWidgets('an unpaired device is shown no device list at all', (
    tester,
  ) async {
    await _storeFamily(isPaired: false);
    await _pumpSettings(tester, _bridgeWithTwoDevices());

    expect(find.text('Devices paired with the PC'), findsNothing);
  });
}

/// Opens the parent-gated The PC page over one scripted PC boundary.
Future<void> _pumpSettings(
  WidgetTester tester,
  FakeBridgeHttpClient httpClient,
) {
  return pumpApp(
    tester,
    route: '/settings/pc',
    overrides: [bridgeHttpClientProvider.overrideWithValue(httpClient)],
  );
}

/// Scrolls [target] into the long PC page and taps it.
Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// Answers `/devices` for a PC that trusts this tablet and one other phone.
///
/// The list is real state here: a removal drops the row, so the refresh after
/// a removal answers what a running bridge would answer.
FakeBridgeHttpClient _bridgeWithTwoDevices() {
  final devices = <Map<String, Object?>>[
    bridgeDevicePayload(
      id: 'device-a',
      name: 'Family tablet',
      lastSeenAtUtc: '2026-09-01T18:30:00.000Z',
      isCaller: true,
    ),
    bridgeDevicePayload(
      id: 'device-b',
      name: "Dad's phone",
      createdAtUtc: '2026-08-25T10:00:00.000Z',
    ),
  ];
  return FakeBridgeHttpClient((request) async {
    final path = request.url.path;
    if (path == '/devices') {
      return bridgeJsonResponse(<String, Object?>{'devices': devices});
    }
    if (path.startsWith('/devices/')) {
      final removedId = path.substring('/devices/'.length);
      devices.removeWhere((device) => device['id'] == removedId);
      return bridgeJsonResponse(<String, Object?>{
        'id': removedId,
        'removed': true,
      });
    }
    if (path == '/sync/manifest') {
      return bridgeJsonResponse(bridgeManifestPayload());
    }
    if (path == '/sync/complete') {
      return bridgeJsonResponse(<String, Object>{
        'deviceId': 'device-a',
        'lastSyncedAtUtc': '2026-09-01T18:30:00.000Z',
      });
    }
    return bridgeErrorResponse('invalid_request', 400);
  });
}

/// Stores one Local AI family, paired with the PC or not yet.
Future<void> _storeFamily({bool isPaired = true}) {
  return seedDevice(
    profiles: <ChildProfile>[child()],
    activeProfileId: 'miko',
    aiConnection: localAiConnection(),
    bridgeCredential: isPaired ? pairedDevice() : null,
  );
}
