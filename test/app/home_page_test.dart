import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/home/home_greeting.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/in_memory_illustration_store.dart';

/// Verifies the home mosaic through the real application widget.
///
/// Everything runs against the real router, controllers, and preference
/// storage, exactly as the other application-level suites do: only the device
/// boundaries are replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parentPin = '4729';
  final service = ParentSecurityService(deriver: _fakeDeriver);

  setUp(() => appRouter.go('/'));

  testWidgets('the header switcher changes the active child', (tester) async {
    _storeFamily(profiles: <Map<String, Object>>[_miko(), _abbas()]);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Reading as'), findsOneWidget);
    expect(find.text('Miko'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey<String>('home-hero-switcher')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a child'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('home-hero-abbas')));
    await tester.pumpAndSettle();

    final header = find.text('Abbas');
    expect(header, findsOneWidget);
    expect(find.text('Miko'), findsNothing);
    expect(
      Theme.of(tester.element(header)).colorScheme.primary,
      AppTheme.boyCyan,
    );
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.activeProfileId, 'abbas');
  });

  testWidgets('the new story tile opens the creation page', (tester) async {
    _storeFamily(profiles: <Map<String, Object>>[_miko()]);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home-new-story')));
    await tester.pumpAndSettle();

    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Who is the hero'), findsOneWidget);
  });

  testWidgets('keep reading opens the newest unfinished book', (tester) async {
    _storeFamily(
      profiles: <Map<String, Object>>[_miko()],
      stories: <Map<String, Object>>[_story()],
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('KEEP READING'), findsOneWidget);
    expect(find.text('2 pages'), findsOneWidget);
    expect(
      find.textContaining(
        'The moon garden is waiting to be finished.',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-keep-reading')));
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 2'), findsOneWidget);
  });

  testWidgets('a finished book leaves the shelf strip and the tile', (
    tester,
  ) async {
    _storeFamily(
      profiles: <Map<String, Object>>[
        _miko(finishedStoryIds: <String>['story-1']),
      ],
      stories: <Map<String, Object>>[_story()],
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('home-keep-reading')),
      findsNothing,
    );
    expect(find.text('ON THE SHELF'), findsOneWidget);
    expect(find.text('The moon garden'), findsOneWidget);
  });

  testWidgets('the drafts row stays away while nothing waits', (tester) async {
    _storeFamily(
      profiles: <Map<String, Object>>[_miko()],
      stories: <Map<String, Object>>[_story()],
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('home-drafts-waiting')),
      findsNothing,
    );
  });

  testWidgets('the drafts row counts drafts and reaches the review queue', (
    tester,
  ) async {
    _storeFamily(
      profiles: <Map<String, Object>>[_miko()],
      stories: <Map<String, Object>>[_story(reviewStatus: 'draft')],
    );
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Drafts waiting for review: 1'), findsOneWidget);
    expect(
      find.textContaining(
        'New stories are waiting for a parent to read them.',
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-drafts-waiting')));
    await tester.pumpAndSettle();

    expect(find.text('Parent story review'), findsOneWidget);
  });

  testWidgets('the drafts row stops at the parent PIN', (tester) async {
    _storeFamily(
      profiles: <Map<String, Object>>[_miko()],
      stories: <Map<String, Object>>[_story(reviewStatus: 'draft')],
    );
    await _configurePin(service, parentPin);
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('home-drafts-waiting')));
    await tester.pumpAndSettle();

    expect(find.text('Parent area locked'), findsOneWidget);
    expect(find.text('Parent story review'), findsNothing);

    await tester.enterText(find.byType(TextField).last, parentPin);
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Parent story review'), findsOneWidget);
  });

  testWidgets('a family with no profiles is asked for one first', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('Add a hero profile'), findsOneWidget);
    expect(find.text('Add a profile'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('home-new-story')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home-hero-switcher')),
      findsNothing,
    );
  });

  group('the greeting follows the clock', () {
    test('every part of the day has its own hours', () {
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 4, 59)), HomeTimeOfDay.night);
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 5)), HomeTimeOfDay.morning);
      expect(
        homeTimeOfDay(DateTime(2026, 9, 3, 11, 59)),
        HomeTimeOfDay.morning,
      );
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 12)), HomeTimeOfDay.afternoon);
      expect(
        homeTimeOfDay(DateTime(2026, 9, 3, 16, 59)),
        HomeTimeOfDay.afternoon,
      );
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 17)), HomeTimeOfDay.evening);
      expect(
        homeTimeOfDay(DateTime(2026, 9, 3, 21, 59)),
        HomeTimeOfDay.evening,
      );
      expect(homeTimeOfDay(DateTime(2026, 9, 3, 22)), HomeTimeOfDay.night);
    });
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

/// Saves a verifier the way settings would, before the app is first built.
Future<void> _configurePin(ParentSecurityService service, String pin) async {
  final repository = await LocalRepository.open();
  await repository.saveParentSecurity(await service.createRecord(pin));
}

/// Stores one family, with Miko active, and whatever library it should have.
void _storeFamily({
  required List<Map<String, Object>> profiles,
  List<Map<String, Object>> stories = const <Map<String, Object>>[],
}) {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'active_profile_id': 'miko',
    'child_profiles': jsonEncode(profiles),
    'story_library': jsonEncode(stories),
  });
}

/// Stores the girl profile Home reads as, with her reward history.
Map<String, Object> _miko({List<String> finishedStoryIds = const <String>[]}) {
  return <String, Object>{
    'id': 'miko',
    'name': 'Miko',
    'age': 7,
    'photoBase64': _transparentPixel,
    'gender': 'girl',
    'themeColorValue': AppTheme.girlPink.toARGB32(),
    'finishedStoryIds': finishedStoryIds,
  };
}

/// Stores the second child the switcher can hand the app to.
Map<String, Object> _abbas() {
  return <String, Object>{
    'id': 'abbas',
    'name': 'Abbas',
    'age': 9,
    'photoBase64': _transparentPixel,
    'gender': 'boy',
    'themeColorValue': AppTheme.boyCyan.toARGB32(),
  };
}

/// Builds one stored story written by the offline demo generator.
Map<String, Object> _story({String reviewStatus = 'approved'}) {
  return <String, Object>{
    'id': 'story-1',
    'createdAt': DateTime.utc(2026, 8, 17, 12).toIso8601String(),
    'reviewStatus': reviewStatus,
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

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
