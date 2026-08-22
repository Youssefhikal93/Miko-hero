import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies what the parent-gated AI connection card says about syncing.
///
/// The section lives inside the settings route, so nothing here is reachable
/// from a child-facing screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the card reports the automatic sync after a start', (
    tester,
  ) async {
    _storeFamily();
    await tester.pumpWidget(_app(_bridgeWithOneStory()));
    await tester.pumpAndSettle();

    expect(find.text('Offline story library'), findsOneWidget);
    expect(find.text('1 new · 0 updated · 0 removed'), findsOneWidget);
    expect(
      find.text('This device has not synced with the PC yet.'),
      findsNothing,
    );
    expect(_lastSyncLabel(tester), startsWith('Last sync: '));
  });

  testWidgets('syncing again reports that nothing changed', (tester) async {
    _storeFamily();
    await tester.pumpWidget(_app(_bridgeWithOneStory()));
    await tester.pumpAndSettle();

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
    _storeFamily(isPaired: false);
    await tester.pumpWidget(
      _app(
        FakeBridgeHttpClient((request) async {
          throw http.ClientException('Connection refused.', request.url);
        }),
      ),
    );
    await tester.pumpAndSettle();

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

/// Builds the real application over one scripted PC boundary.
Widget _app(FakeBridgeHttpClient httpClient) {
  return ProviderScope(
    overrides: [bridgeHttpClientProvider.overrideWithValue(httpClient)],
    child: const IamHeroApp(),
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

/// Stores one Local AI family and opens the parent-gated settings route.
void _storeFamily({bool isPaired = true}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'active_profile_id': 'miko',
    'child_profiles': jsonEncode(<Map<String, Object>>[
      <String, Object>{
        'id': 'miko',
        'name': 'Miko',
        'age': 7,
        'photoBase64': 'cGhvdG8=',
        'gender': 'girl',
      },
    ]),
    'ai_connection': jsonEncode(<String, Object>{
      'mode': 'localAi',
      'baseUrl': defaultBridgeBaseUrl,
    }),
    if (isPaired)
      'bridge_device': jsonEncode(<String, Object>{
        'deviceToken': 'device-token',
        'deviceName': 'Family tablet',
        'pairedAtUtc': '2026-08-22T09:00:00.000Z',
      }),
  });
  appRouter.go('/settings');
}
