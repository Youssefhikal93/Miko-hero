import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';

import '../../support/seeded_device.dart';

/// Verifies that moving the card icons into one overflow menu lost nothing.
///
/// Everything runs through the real library UI, the real parent gate, and the
/// real controllers and storage, exactly as the delete-choice and share tests
/// do: only the platform boundaries are replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parentPin = '4729';
  final service = ParentSecurityService(deriver: _fakeDeriver);

  testWidgets('the overflow delete asks for the parent PIN first', (
    tester,
  ) async {
    await _storeFamily();
    await _configurePin(service, parentPin);
    await _pumpLibrary(tester, service);

    await _openOverflow(tester);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(find.text('Parent area locked'), findsOneWidget);
    expect(find.text('Delete this story?'), findsNothing);
    expect(find.text('The moon garden'), findsWidgets);

    await tester.enterText(find.byType(TextField).last, parentPin);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this story?'), findsOneWidget);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('The moon garden'), findsNothing);
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.stories, isEmpty);
  });

  testWidgets('the overflow favourite runs the same story command', (
    tester,
  ) async {
    await _storeFamily();
    await _pumpLibrary(tester, service);

    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    await _openOverflow(tester);
    await tester.tap(find.text('Add to favorites'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.stories.single.isFavorite, isTrue);
  });

  testWidgets('the large tile carries the badge, the heart and the meta', (
    tester,
  ) async {
    await _storeFamily(isFavorite: true);
    await _pumpLibrary(tester, service);

    expect(find.text('DEMO'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.textContaining('2 pages · '), findsOneWidget);
  });
}

/// Opens the child's shelf behind the real parent gate.
Future<void> _pumpLibrary(WidgetTester tester, ParentSecurityService service) {
  return pumpApp(
    tester,
    route: '/library',
    overrides: [parentSecurityServiceProvider.overrideWithValue(service)],
  );
}

/// Opens the one overflow control the story tile offers.
Future<void> _openOverflow(WidgetTester tester) async {
  final overflow = find.byIcon(Icons.more_horiz_rounded).first;
  await tester.ensureVisible(overflow);
  await tester.pumpAndSettle();
  await tester.tap(overflow);
  await tester.pumpAndSettle();
}

/// Saves a verifier the way settings would, before the app is first built.
Future<void> _configurePin(ParentSecurityService service, String pin) async {
  final repository = await LocalRepository.open();
  await repository.saveParentSecurity(await service.createRecord(pin));
}

/// Stores one family holding a single approved two-page demo story.
Future<void> _storeFamily({bool isFavorite = false}) {
  return seedDevice(
    profiles: <ChildProfile>[child()],
    stories: <StoryBook>[book(profileId: 'miko', isFavorite: isFavorite)],
    activeProfileId: 'miko',
  );
}

/// Stands in for Argon2id so the gate stays fast in a widget test.
///
/// The real derivation is covered by `parent_security_service_test.dart`.
/// Still salt- and PIN-dependent, so only the configured PIN matches.
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
