import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/seeded_device.dart';

/// Verifies the two very different things "delete" can mean for one story.
///
/// Everything runs through the real library UI behind the real parent gate,
/// with only the PC's HTTP boundary replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a demo story keeps one plain local deletion', (tester) async {
    await _storeFamily(hasBridgeProvenance: false);
    await _pumpLibrary(tester, _unreachableBridge());

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
    await _storeFamily();
    final bridge = _unreachableBridge();
    await _pumpLibrary(tester, bridge);

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
    await _storeFamily();
    await _pumpLibrary(tester, _unreachableBridge());

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
    await _storeFamily();
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
    await _pumpLibrary(tester, bridge);

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

/// Opens the child's shelf with the real app over one scripted PC boundary.
Future<void> _pumpLibrary(
  WidgetTester tester,
  FakeBridgeHttpClient httpClient,
) {
  return pumpApp(
    tester,
    route: '/library',
    overrides: [bridgeHttpClientProvider.overrideWithValue(httpClient)],
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
  final overflow = find.byIcon(Icons.more_horiz_rounded).first;
  await tester.ensureVisible(overflow);
  await tester.pumpAndSettle();
  await tester.tap(overflow);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete').last);
  await tester.pumpAndSettle();
}

/// Stores one paired Local AI family holding one approved story.
Future<void> _storeFamily({bool hasBridgeProvenance = true}) {
  return seedDevice(
    profiles: <ChildProfile>[child()],
    stories: <StoryBook>[_story(hasBridgeProvenance: hasBridgeProvenance)],
    activeProfileId: 'miko',
    aiConnection: localAiConnection(),
    bridgeCredential: pairedDevice(),
  );
}

/// Builds one stored approved story, from the PC library or from the demo.
///
/// Only the PC's own story carries the identities that let the app ask the
/// bridge to delete it there too; a demo story keeps one plain local deletion.
StoryBook _story({required bool hasBridgeProvenance}) {
  final scene = hasBridgeProvenance
      ? const BridgeStoryProvenance(
          scene: 'a glowing garden',
          storyId: 'story-1',
          illustrationId: 'illustration-1',
        ).toSceneDescription()
      : 'a glowing garden';
  return book(
    profileId: 'miko',
    pages: <StoryPage>[
      storyPage(1, 'Miko woke up. The garden glowed.', scene: scene),
    ],
  );
}
