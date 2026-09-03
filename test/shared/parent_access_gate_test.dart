import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies the parent gate from the point of view of someone at the device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const correctPin = '4729';
  const wrongPin = '1111';
  final clock = DateTime.utc(2026, 8, 19, 20);
  final service = ParentSecurityService(deriver: _fakeDeriver);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appRouter.go('/');
  });

  testWidgets('a configured PIN hides settings until it is entered', (
    tester,
  ) async {
    await _configurePin(service, correctPin);
    await tester.pumpWidget(_app(service, clock));
    await tester.pumpAndSettle();
    appRouter.go('/settings');
    await tester.pumpAndSettle();

    expect(find.text('Parent area locked'), findsOneWidget);
    expect(find.text('Settings and privacy'), findsNothing);

    await tester.enterText(find.byType(TextField), wrongPin);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('That PIN is incorrect.'), findsOneWidget);
    expect(find.text('Settings and privacy'), findsNothing);

    await tester.enterText(find.byType(TextField), correctPin);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Settings and privacy'), findsOneWidget);
    expect(find.text('Parent area locked'), findsNothing);
  });

  testWidgets('repeated wrong PINs refuse input with a remaining time', (
    tester,
  ) async {
    await _configurePin(service, correctPin);
    await tester.pumpWidget(_app(service, clock));
    await tester.pumpAndSettle();
    appRouter.go('/settings');
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < parentPinFreeAttempts; attempt++) {
      await tester.enterText(find.byType(TextField), wrongPin);
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Too many attempts. Try again in 30 s.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text('Settings and privacy'), findsNothing);

    await tester.pump(const Duration(seconds: 31));
    await tester.pumpAndSettle();

    expect(find.text('Too many attempts. Try again in 30 s.'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });
}

/// Builds the real application with a controlled clock and fast PIN hashing.
Widget _app(ParentSecurityService service, DateTime clock) {
  return ProviderScope(
    overrides: [
      parentSecurityServiceProvider.overrideWithValue(service),
      parentSecurityClockProvider.overrideWithValue(() => clock),
      bridgeCredentialStorageProvider.overrideWithValue(
        InMemoryBridgeCredentialStorage(),
      ),
    ],
    child: const IamHeroApp(),
  );
}

/// Saves a verifier the way settings would, before the app is first built.
Future<void> _configurePin(ParentSecurityService service, String pin) async {
  final repository = await LocalRepository.open();
  await repository.saveParentSecurity(await service.createRecord(pin));
}

/// Stands in for Argon2id so gate tests stay fast.
///
/// The real derivation is covered by `parent_security_service_test.dart`;
/// running it per attempt here would add minutes of CPU work without proving
/// anything about the gate. Still salt- and PIN-dependent, so only the
/// configured PIN matches.
Future<Uint8List> _fakeDeriver(ParentPinDerivation derivation) async {
  final pinBytes = utf8.encode(derivation.pin);
  return Uint8List.fromList(
    List<int>.generate(
      parentSecurityHashLength,
      (index) =>
          (pinBytes[index % pinBytes.length] +
              derivation.salt[index % derivation.salt.length]) &
          0xFF,
    ),
  );
}
