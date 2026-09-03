import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_illustration_store.dart';

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
    _storeFamily();
    await _configurePin(service, parentPin);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

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
    _storeFamily();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

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
    _storeFamily(isFavorite: true);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('DEMO'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.textContaining('2 pages · '), findsOneWidget);
  });
}

/// Builds the real application over in-memory device storage.
///
/// The page-image cache is replaced because the real store reaches for this
/// machine's application folder, which a widget test must never touch.
Widget _app(ParentSecurityService service) {
  return ProviderScope(
    overrides: [
      parentSecurityServiceProvider.overrideWithValue(service),
      bridgeCredentialStorageProvider.overrideWithValue(
        InMemoryBridgeCredentialStorage(),
      ),
      illustrationStoreProvider.overrideWithValue(InMemoryIllustrationStore()),
    ],
    child: const IamHeroApp(),
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

/// Stores one family holding a single approved demo story.
void _storeFamily({bool isFavorite = false}) {
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
      _story(isFavorite: isFavorite),
    ]),
  });
  appRouter.go('/library');
}

/// Builds one stored approved story written by the offline demo generator.
Map<String, Object> _story({required bool isFavorite}) {
  return <String, Object>{
    'id': 'story-1',
    'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
    'reviewStatus': 'approved',
    'isFavorite': isFavorite,
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
          'sceneDescription': 'a glowing garden',
        },
        <String, Object>{
          'number': 2,
          'text': 'The moon said goodnight.',
          'sceneDescription': 'a sleeping garden',
        },
      ],
    },
  };
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
