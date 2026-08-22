import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies the two very different things "delete" can mean for one story.
///
/// Everything runs through the real library UI behind the real parent gate,
/// with only the PC's HTTP boundary replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a demo story keeps one plain local deletion', (tester) async {
    _storeFamily(hasBridgeProvenance: false);
    await tester.pumpWidget(_app(_unreachableBridge()));
    await tester.pumpAndSettle();

    await _tapDelete(tester);

    expect(find.text('Delete this story?'), findsOneWidget);
    expect(find.text('Remove from this device'), findsNothing);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('The moon garden'), findsNothing);
  });

  testWidgets('removing the offline copy keeps the story on the PC', (
    tester,
  ) async {
    _storeFamily();
    final bridge = _unreachableBridge();
    await tester.pumpWidget(_app(bridge));
    await tester.pumpAndSettle();

    await _tapDelete(tester);
    expect(find.text('Where should this story be deleted?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('remove-story-from-device')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Story removed from this device'), findsOneWidget);
    expect(find.text('The moon garden'), findsNothing);
    expect(bridge.callsTo('/stories/story-1/delete'), 0);

    // The parent-gated settings card now offers those stories back.
    appRouter.go('/settings');
    await tester.pumpAndSettle();
    expect(find.text('Stories removed from this device'), findsOneWidget);
    final redownload = find.byKey(
      const ValueKey<String>('redownload-removed-stories'),
    );
    await tester.ensureVisible(redownload);
    await tester.pumpAndSettle();
    await tester.tap(redownload);
    await tester.pumpAndSettle();
    expect(
      find.text('The next sync will bring those stories back'),
      findsOneWidget,
    );
  });

  testWidgets('deleting everywhere without the PC keeps the story', (
    tester,
  ) async {
    _storeFamily();
    await tester.pumpWidget(_app(_unreachableBridge()));
    await tester.pumpAndSettle();

    await _tapDelete(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('delete-story-everywhere')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'The PC did not answer. Check that the bridge is running and that '
        'the address is correct.',
      ),
      findsOneWidget,
    );
    expect(find.text('The moon garden'), findsWidgets);
  });

  testWidgets('deleting everywhere asks the PC and drops the copy', (
    tester,
  ) async {
    _storeFamily();
    final bridge = FakeBridgeHttpClient((request) async {
      if (request.url.path == '/stories/story-1/delete') {
        return bridgeJsonResponse(<String, Object>{
          'storyId': 'story-1',
          'alreadyDeleted': false,
          'deletedAtUtc': '2026-08-22T11:05:00.000Z',
          'removedFileCount': 6,
        });
      }
      throw http.ClientException('Connection refused.', request.url);
    });
    await tester.pumpWidget(_app(bridge));
    await tester.pumpAndSettle();

    await _tapDelete(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('delete-story-everywhere')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Story deleted on the PC and on every device'),
      findsOneWidget,
    );
    expect(find.text('The moon garden'), findsNothing);
    expect(bridge.callsTo('/stories/story-1/delete'), 1);
  });
}

/// Builds the real application over one scripted PC boundary.
Widget _app(FakeBridgeHttpClient httpClient) {
  return ProviderScope(
    overrides: [bridgeHttpClientProvider.overrideWithValue(httpClient)],
    child: const IamHeroApp(),
  );
}

/// Answers every call as a PC that is switched off.
FakeBridgeHttpClient _unreachableBridge() {
  return FakeBridgeHttpClient((request) async {
    throw http.ClientException('Connection refused.', request.url);
  });
}

/// Opens the story's delete action from the child's shelf.
Future<void> _tapDelete(WidgetTester tester) async {
  final delete = find.byIcon(Icons.delete_outline_rounded).first;
  await tester.ensureVisible(delete);
  await tester.pumpAndSettle();
  await tester.tap(delete);
  await tester.pumpAndSettle();
}

/// Stores one paired Local AI family holding one approved story.
void _storeFamily({bool hasBridgeProvenance = true}) {
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
    'story_library': jsonEncode(<Map<String, Object>>[
      _story(hasBridgeProvenance: hasBridgeProvenance),
    ]),
    'ai_connection': jsonEncode(<String, Object>{
      'mode': 'localAi',
      'baseUrl': defaultBridgeBaseUrl,
    }),
    'bridge_device': jsonEncode(<String, Object>{
      'deviceToken': 'device-token',
      'deviceName': 'Family tablet',
      'pairedAtUtc': '2026-08-22T09:00:00.000Z',
    }),
  });
  appRouter.go('/library');
}

/// Builds one stored approved story, from the PC library or from the demo.
Map<String, Object> _story({required bool hasBridgeProvenance}) {
  final scene = hasBridgeProvenance
      ? const BridgeStoryProvenance(
          scene: 'a glowing garden',
          storyId: 'story-1',
          illustrationId: 'illustration-1',
        ).toSceneDescription()
      : 'a glowing garden';
  return <String, Object>{
    'id': 'story-1',
    'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
    'reviewStatus': 'approved',
    'content': <String, Object>{
      'title': 'The moon garden',
      'request': <String, Object>{
        'profileId': 'miko',
        'heroName': 'Miko',
        'gender': 'girl',
        'prompt': <String, Object>{
          'theme': 'a moon garden',
          'moral': 'kindness',
          'preferences': const ChildStoryPreferences().toJson(),
        },
        'presentation': <String, Object>{
          'language': 'en',
          'length': 'short',
          'style': 'pictureBook',
        },
      },
      'pages': <Map<String, Object>>[
        <String, Object>{
          'number': 1,
          'text': 'Miko woke up. The garden glowed.',
          'sceneDescription': scene,
        },
      ],
    },
  };
}
