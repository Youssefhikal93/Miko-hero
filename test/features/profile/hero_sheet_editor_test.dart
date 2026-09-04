import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/seeded_device.dart';

/// Verifies what a parent can actually see and change about their drawn hero.
///
/// The whole editor runs for real — the typed client, the controller, the
/// parent gate and preference storage — with only the PC's HTTP boundary
/// replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the look the PC read and the wardrobe it stored', (
    tester,
  ) async {
    await _storeFamily();
    await _openEditor(tester, _bridgeHolding(_sheet()));

    expect(find.text('How the hero is drawn'), findsOneWidget);
    expect(find.text('short curly black hair'), findsOneWidget);
    expect(find.text('warm brown'), findsOneWidget);
    expect(find.text('dark brown'), findsOneWidget);
    expect(
      _fieldText(tester, 'hero-sheet-outfit'),
      'wearing a red knitted cardigan',
    );
    expect(_fieldText(tester, 'hero-sheet-prop'), 'carrying a brass lantern');
    // The three the PC read are shown, never offered as fields to type into.
    expect(
      find.widgetWithText(TextFormField, 'short curly black hair'),
      findsNothing,
    );
  });

  testWidgets('says so plainly when the PC has not read the photo yet', (
    tester,
  ) async {
    await _storeFamily();
    await _openEditor(tester, _bridgeHolding(null));

    expect(find.text('The PC has not read this photo yet.'), findsOneWidget);
    expect(_fieldText(tester, 'hero-sheet-outfit'), '');
  });

  testWidgets('sends the outfit the parent typed when the profile is saved', (
    tester,
  ) async {
    await _storeFamily();
    final bridge = _bridgeHolding(_sheet());
    await _openEditor(tester, bridge);

    await _type(tester, 'hero-sheet-outfit', 'wearing a silver space suit');
    await _save(tester);

    final sent = bridge.requests
        .where((request) => request.method == 'PUT')
        .single;
    expect(sent.url.path, '/profiles/miko/hero-sheet');
    final body =
        jsonDecode(utf8.decode(sent.bodyBytes)) as Map<String, Object?>;
    expect(body['outfit'], 'wearing a silver space suit');
    expect(
      body['prop'],
      'carrying a brass lantern',
      reason: 'both halves of the wardrobe belong to the parent',
    );
    expect(find.text('Profile saved'), findsOneWidget);
  });

  testWidgets('leaves the PC alone when nobody touched the wardrobe', (
    tester,
  ) async {
    await _storeFamily();
    final bridge = _bridgeHolding(_sheet());
    await _openEditor(tester, bridge);

    await _save(tester);

    expect(
      bridge.requests.where((request) => request.method == 'PUT'),
      isEmpty,
      reason: 'rewriting the sheet unchanged would move its stamp for nothing',
    );
  });

  testWidgets('asks the PC once to read the photo again and shows it', (
    tester,
  ) async {
    await _storeFamily();
    final bridge = _bridgeHolding(
      _sheet(),
      rederived: _sheet(
        hair: 'long straight brown hair',
        updatedAtUtc: '2026-09-03T21:00:00.000Z',
      ),
    );
    await _openEditor(tester, bridge);
    expect(find.text('short curly black hair'), findsOneWidget);

    final readAgain = find.byKey(
      const ValueKey<String>('hero-sheet-read-again'),
    );
    await tester.ensureVisible(readAgain);
    await tester.pumpAndSettle();
    await tester.tap(readAgain);
    await tester.pumpAndSettle();

    expect(bridge.callsTo('/profiles/miko/hero-sheet/rederive'), 1);
    expect(find.text('long straight brown hair'), findsOneWidget);
    expect(find.text('short curly black hair'), findsNothing);
    expect(find.text('The PC read the photo again.'), findsOneWidget);
  });

  testWidgets('hides the whole section on a device that is not paired', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[child()],
      activeProfileId: 'miko',
      aiConnection: localAiConnection(),
    );
    final bridge = _bridgeHolding(_sheet());
    await _openEditor(tester, bridge);

    expect(
      find.byKey(const ValueKey<String>('hero-sheet-section')),
      findsNothing,
    );
    expect(find.text('How the hero is drawn'), findsNothing);
    expect(
      bridge.requests,
      isEmpty,
      reason: 'a device with no token has no PC to ask',
    );
  });
}

/// One hero sheet exactly as the bridge answers it.
Map<String, Object?> _sheet({
  String hair = 'short curly black hair',
  String outfit = 'wearing a red knitted cardigan',
  String prop = 'carrying a brass lantern',
  String updatedAtUtc = '2026-09-03T20:14:02.000Z',
}) {
  return <String, Object?>{
    'hair': hair,
    'skinTone': 'warm brown',
    'eyeColor': 'dark brown',
    'outfit': outfit,
    'prop': prop,
    'photoHash': 'photo-hash-a',
    'updatedAtUtc': updatedAtUtc,
  };
}

/// A PC that holds [stored] and answers a re-read with [rederived].
///
/// A `PUT` answers with what it was sent, exactly as the bridge does; anything
/// the editor is not supposed to ask for is a refused connection, so a stray
/// call fails the test rather than passing quietly.
FakeBridgeHttpClient _bridgeHolding(
  Map<String, Object?>? stored, {
  Map<String, Object?>? rederived,
}) {
  return FakeBridgeHttpClient((request) async {
    final path = request.url.path;
    if (path == '/profiles/miko/hero-sheet' && request.method == 'GET') {
      return bridgeJsonResponse(<String, Object?>{
        'profileId': 'miko',
        'sheet': stored,
      });
    }
    if (path == '/profiles/miko/hero-sheet' && request.method == 'PUT') {
      final sent =
          jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, Object?>;
      return bridgeJsonResponse(<String, Object?>{
        'profileId': 'miko',
        'sheet': <String, Object?>{...?stored, ...sent},
      });
    }
    if (path == '/profiles/miko/hero-sheet/rederive') {
      return bridgeJsonResponse(<String, Object?>{
        'profileId': 'miko',
        'started': true,
        'sheet': rederived ?? stored,
      }, statusCode: 202);
    }
    throw http.ClientException('Connection refused.', request.url);
  });
}

/// Stores one paired Local AI family holding one child.
Future<void> _storeFamily() {
  return seedDevice(
    profiles: <ChildProfile>[child()],
    activeProfileId: 'miko',
    aiConnection: localAiConnection(),
    bridgeCredential: pairedDevice(),
  );
}

/// Opens the editor of that child over one scripted PC boundary.
Future<void> _openEditor(WidgetTester tester, FakeBridgeHttpClient httpClient) {
  return pumpApp(
    tester,
    route: '/profiles/miko',
    overrides: [bridgeHttpClientProvider.overrideWithValue(httpClient)],
  );
}

/// Current text of the field keyed [key].
String _fieldText(WidgetTester tester, String key) {
  return tester
      .widget<TextFormField>(find.byKey(ValueKey<String>(key)))
      .controller!
      .text;
}

/// Replaces the text of the field keyed [key].
Future<void> _type(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

/// Saves the profile from the editor's own button.
Future<void> _save(WidgetTester tester) async {
  final save = find.text('Save profile');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.tap(save);
  await tester.pumpAndSettle();
}
