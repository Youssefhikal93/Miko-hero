import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/seeded_device.dart';

/// Verifies what the parent-gated AI connection card says about syncing.
///
/// The section lives inside the settings route, so nothing here is reachable
/// from a child-facing screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the card reports the automatic sync after a start', (
    tester,
  ) async {
    await _storeFamily();
    await _pumpSettings(tester, _bridgeWithOneStory());

    expect(find.text('Offline story library'), findsOneWidget);
    expect(find.text('1 new · 0 updated · 0 removed'), findsOneWidget);
    expect(
      find.text('This device has not synced with the PC yet.'),
      findsNothing,
    );
    expect(_lastSyncLabel(tester), startsWith('Last sync: '));
  });

  testWidgets('syncing again reports that nothing changed', (tester) async {
    await _storeFamily();
    await _pumpSettings(tester, _bridgeWithOneStory());

    final syncNow = find.byKey(const ValueKey<String>('sync-library-now'));
    await tester.ensureVisible(syncNow);
    await tester.pumpAndSettle();
    await tester.tap(syncNow);
    await tester.pumpAndSettle();

    expect(find.text('This device already matches the PC.'), findsOneWidget);
  });

  testWidgets('a device that never synced says so and reports failures', (
    tester,
  ) async {
    await _storeFamily(isPaired: false);
    await _pumpSettings(
      tester,
      FakeBridgeHttpClient((request) async {
        throw http.ClientException('Connection refused.', request.url);
      }),
    );

    expect(
      _lastSyncLabel(tester),
      'This device has not synced with the PC yet.',
    );
    final syncNow = find.byKey(const ValueKey<String>('sync-library-now'));
    await tester.ensureVisible(syncNow);
    await tester.pumpAndSettle();
    await tester.tap(syncNow);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Pair this device with the PC before generating a story there.',
      ),
      findsOneWidget,
    );
  });
}

/// Opens the parent-gated settings route over one scripted PC boundary.
Future<void> _pumpSettings(
  WidgetTester tester,
  FakeBridgeHttpClient httpClient,
) {
  return pumpApp(
    tester,
    route: '/settings',
    overrides: [bridgeHttpClientProvider.overrideWithValue(httpClient)],
  );
}

/// Reads the sentence stating when this device last agreed with the PC.
String _lastSyncLabel(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey<String>('library-sync-last-run')))
      .data!;
}

/// Answers the three sync calls for a library holding one story.
FakeBridgeHttpClient _bridgeWithOneStory() {
  return FakeBridgeHttpClient((request) async {
    final path = request.url.path;
    if (path == '/sync/manifest') {
      return bridgeJsonResponse(
        bridgeManifestPayload(
          profiles: <Map<String, Object>>[
            bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
          ],
          stories: <Map<String, Object>>[
            bridgeManifestStory(id: 'story-a', profileId: 'miko'),
          ],
        ),
      );
    }
    if (path == '/sync/stories/story-a') {
      return bridgeJsonResponse(<String, Object>{
        'story': bridgeStoryPayload(
          storyId: 'story-a',
          languageCode: 'en',
          pageCount: 6,
        ),
      });
    }
    if (path == '/sync/complete') {
      return bridgeJsonResponse(<String, Object>{
        'deviceId': 'device-1',
        'lastSyncedAtUtc': '2026-08-22T11:00:00.000Z',
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
