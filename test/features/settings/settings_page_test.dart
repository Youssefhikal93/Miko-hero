import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/seeded_device.dart';

/// What the Settings root says, and that it says it without asking anything.
///
/// The root is a list of groups over one live line each. Nothing is edited
/// here, so the assertions below are about the sentences a parent reads and
/// about the pages the rows open, never about a control on the root itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the root is six groups and nothing to fill in', (tester) async {
    await _storeFamily();
    await _pumpRoot(tester);

    expect(find.text('Settings and privacy'), findsOneWidget);
    for (final group in _groups) {
      expect(
        find.byKey(ValueKey<String>('settings-group-$group')),
        findsOneWidget,
        reason: '$group is one of the groups the root lists',
      );
    }
    expect(
      find.byType(TextField),
      findsNothing,
      reason: 'the bridge address is on the page that owns it',
    );
    expect(
      find.byType(SwitchListTile),
      findsNothing,
      reason: 'the easy-reading switch is on the Reading page',
    );
    expect(
      find.text('Delete all local data'),
      findsNothing,
      reason: 'the irreversible command never sits on the root list',
    );
  });

  testWidgets('the Family and Reading rows read the saved family', (
    tester,
  ) async {
    await _storeFamily(
      profiles: <ChildProfile>[
        child(readingSettings: const ChildReadingSettings()),
      ],
    );
    await _pumpRoot(tester);

    expect(_summary(tester, 'family'), 'Profiles: 1 · English');
    expect(
      _summary(tester, 'reading'),
      'Text size: Medium · easy-reading font off',
    );
    expect(_summary(tester, 'safety'), 'No parent PIN · Safety exclusions: 0');
    expect(_summary(tester, 'data'), 'Stories on this device: 0');
  });

  testWidgets('the Reading row names a size the family disagrees on', (
    tester,
  ) async {
    await _storeFamily(
      profiles: <ChildProfile>[
        child(readingSettings: const ChildReadingSettings()),
        child(
          id: 'sam',
          name: 'Sam',
          readingSettings: const ChildReadingSettings(
            textSize: ReaderTextSize.large,
            easyReadingFont: true,
          ),
        ),
      ],
    );
    await _pumpRoot(tester);

    expect(
      _summary(tester, 'reading'),
      'Text size: Mixed · easy-reading font for some heroes',
    );
  });

  testWidgets('a demo device says only that about the PC', (tester) async {
    await _storeFamily();
    await _pumpRoot(tester);

    expect(_summary(tester, 'pc'), 'Demo stories');
  });

  testWidgets('a Local AI device that is not paired says so', (tester) async {
    await _storeFamily(usesLocalAi: true);
    await _pumpRoot(tester);

    expect(_summary(tester, 'pc'), 'The PC · not paired yet');
  });

  testWidgets('a paired device that never synced says both', (tester) async {
    await _storeFamily(usesLocalAi: true, isPaired: true);
    await _pumpRoot(
      tester,
      httpClient: FakeBridgeHttpClient((request) async {
        throw http.ClientException('Connection refused.', request.url);
      }),
    );

    expect(_summary(tester, 'pc'), 'Paired with the PC · not synced yet');
  });

  testWidgets('a paired device names the sync it has already had', (
    tester,
  ) async {
    await _storeFamily(usesLocalAi: true, isPaired: true);
    await _pumpRoot(tester, httpClient: _syncedBridge());

    expect(
      _summary(tester, 'pc'),
      startsWith('Paired with the PC · synced '),
      reason: 'the moment comes from the record the automatic sync wrote',
    );
  });

  testWidgets('a row opens its own page, which opens with its own header', (
    tester,
  ) async {
    await _storeFamily(usesLocalAi: true);
    await _pumpRoot(tester);

    await tester.tap(find.byKey(const ValueKey<String>('settings-group-pc')));
    await tester.pumpAndSettle();

    expect(find.text('The PC'), findsWidgets);
    expect(find.text('AI connection'), findsOneWidget);
    expect(
      find.byType(AppBar),
      findsNothing,
      reason: 'the page paints its own header, so the shell adds none',
    );

    await tester.tap(find.byKey(const ValueKey<String>('settings-group-back')));
    await tester.pumpAndSettle();

    expect(find.text('Settings and privacy'), findsOneWidget);
  });

  testWidgets('the destructive command lives at the bottom of Your data', (
    tester,
  ) async {
    await _storeFamily();
    await _pumpRoot(tester);

    await tester.tap(find.byKey(const ValueKey<String>('settings-group-data')));
    await tester.pumpAndSettle();

    final deleteEverything = find.byKey(
      const ValueKey<String>('settings-delete-everything'),
    );
    expect(deleteEverything, findsOneWidget);
    expect(find.text('CANNOT BE UNDONE'), findsOneWidget);
    await tester.ensureVisible(deleteEverything);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete all local data'));
    await tester.pumpAndSettle();

    expect(find.text('Delete everything?'), findsOneWidget);
  });

  testWidgets('the root and The PC page fit a 390 px phone', (tester) async {
    await _storeFamily(usesLocalAi: true, isPaired: true);
    await _pumpRoot(tester, size: _phone, httpClient: _syncedBridge());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('settings-group-pc')));
    await tester.pumpAndSettle();

    expect(find.text('Story generator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the root and The PC page fit a 1280 px desktop window', (
    tester,
  ) async {
    await _storeFamily(usesLocalAi: true, isPaired: true);
    await _pumpRoot(tester, size: _desktop, httpClient: _syncedBridge());

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    for (final group in _groups) {
      expect(find.byKey(ValueKey<String>('settings-group-$group')), findsOne);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey<String>('settings-group-pc')));
    await tester.pumpAndSettle();

    expect(find.text('Story generator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an Arabic family reads the root right to left', (tester) async {
    await _storeFamily(locale: AppLanguage.arabic.locale);
    await _pumpRoot(tester, size: _phone);

    final title = find.text('الإعدادات والخصوصية');
    expect(title, findsOneWidget);
    expect(Directionality.of(tester.element(title)), TextDirection.rtl);
    expect(find.text('العائلة'), findsOneWidget);
    expect(find.text('الكمبيوتر'), findsOneWidget);
    expect(_summary(tester, 'pc'), 'قصص تجريبية');
    expect(tester.takeException(), isNull);
  });
}

/// The six groups the Settings root lists, in the order it lists them.
const _groups = <String>['family', 'reading', 'pc', 'safety', 'data', 'about'];

/// A phone narrow enough to catch anything the root cannot wrap.
const _phone = Size(390, 844);

/// A desktop window wide enough for the rail beside the centred content.
const _desktop = Size(1280, 900);

/// Opens the parent-gated Settings root in a window of the requested size.
Future<void> _pumpRoot(
  WidgetTester tester, {
  Size size = _desktop,
  FakeBridgeHttpClient? httpClient,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpApp(
    tester,
    route: '/settings',
    overrides: httpClient == null
        ? const []
        : [bridgeHttpClientProvider.overrideWithValue(httpClient)],
  );
}

/// Reads the one line the row for [group] currently says.
String _summary(WidgetTester tester, String group) {
  return tester
      .widget<Text>(find.byKey(ValueKey<String>('settings-summary-$group')))
      .data!;
}

/// Stores one family, on the demo or on the PC, paired with it or not.
Future<void> _storeFamily({
  List<ChildProfile>? profiles,
  bool usesLocalAi = false,
  bool isPaired = false,
  Locale? locale,
}) {
  return seedDevice(
    profiles: profiles ?? <ChildProfile>[child()],
    activeProfileId: 'miko',
    locale: locale,
    aiConnection: usesLocalAi ? localAiConnection() : null,
    bridgeCredential: isPaired ? pairedDevice() : null,
  );
}

/// Answers the automatic start-up sync for a PC whose library is empty.
FakeBridgeHttpClient _syncedBridge() {
  return FakeBridgeHttpClient((request) async {
    final path = request.url.path;
    if (path == '/sync/manifest') {
      return bridgeJsonResponse(bridgeManifestPayload());
    }
    if (path == '/sync/complete') {
      return bridgeJsonResponse(<String, Object>{
        'deviceId': 'device-1',
        'lastSyncedAtUtc': '2026-09-01T18:30:00.000Z',
      });
    }
    return bridgeErrorResponse('invalid_request', 400);
  });
}
