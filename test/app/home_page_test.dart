import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';

import '../support/seeded_device.dart';

/// Verifies that the home mosaic is wired to the real application.
///
/// Everything runs against the real router, controllers, and preference
/// storage, exactly as the other application-level suites do: only the device
/// boundaries are replaced. What Home *decides* — which book is featured, what
/// the strip holds, which line is true, which child "See all" names — is
/// asserted without a widget in `test/features/home/home_view_test.dart`;
/// these tests prove those answers reach the screen and its routes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const parentPin = '4729';
  final service = ParentSecurityService(deriver: _fakeDeriver);

  setUp(() => appRouter.go('/'));

  testWidgets('the header switcher changes the active child', (tester) async {
    await _storeFamily(profiles: <ChildProfile>[_miko(), _abbas()]);
    await _pumpHome(tester, service);

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
    await _storeFamily(profiles: <ChildProfile>[_miko()]);
    await _pumpHome(tester, service);

    await tester.tap(find.byKey(const ValueKey<String>('home-new-story')));
    await tester.pumpAndSettle();

    expect(find.text('New story'), findsOneWidget);
    expect(find.text('Who is the hero'), findsOneWidget);
  });

  testWidgets('keep reading opens the newest unfinished book', (tester) async {
    await _storeFamily(
      profiles: <ChildProfile>[_miko()],
      stories: <StoryBook>[_story()],
    );
    await _pumpHome(tester, service);

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
    await _storeFamily(
      profiles: <ChildProfile>[
        _miko(finishedStoryIds: <String>['story-1']),
      ],
      stories: <StoryBook>[_story()],
    );
    await _pumpHome(tester, service);

    expect(
      find.byKey(const ValueKey<String>('home-keep-reading')),
      findsNothing,
    );
    expect(find.text('ON THE SHELF'), findsOneWidget);
    expect(find.text('The moon garden'), findsOneWidget);
  });

  testWidgets('see all opens the shelf on the child Home is reading as', (
    tester,
  ) async {
    await _storeFamily(
      profiles: <ChildProfile>[_miko(), _abbas()],
      stories: <StoryBook>[
        _story(),
        _story(
          id: 'story-2',
          profileId: 'abbas',
          heroName: 'Abbas',
          title: 'Two kites over the harbour',
          createdAtHour: 14,
        ),
        _story(
          id: 'story-3',
          profileId: 'abbas',
          heroName: 'Abbas',
          title: 'The lantern path',
          createdAtHour: 13,
        ),
      ],
      activeProfileId: 'abbas',
    );
    await _pumpHome(tester, service);

    final seeAll = find.byKey(const ValueKey<String>('home-see-all'));
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.text('The shelf'), findsOneWidget);
    expect(_chipIsSelected(tester, 'abbas'), isTrue);
    expect(_chipIsSelected(tester, 'miko'), isFalse);
    expect(find.text('The lantern path'), findsOneWidget);
    expect(find.text('The moon garden'), findsNothing);
  });

  testWidgets('the drafts row counts drafts and reaches the review queue', (
    tester,
  ) async {
    await _storeFamily(
      profiles: <ChildProfile>[_miko()],
      stories: <StoryBook>[_story(reviewStatus: StoryReviewStatus.draft)],
    );
    await _pumpHome(tester, service);

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
    await _storeFamily(
      profiles: <ChildProfile>[_miko()],
      stories: <StoryBook>[_story(reviewStatus: StoryReviewStatus.draft)],
    );
    await _configurePin(service, parentPin);
    await _pumpHome(tester, service);

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
    await seedDevice();
    await _pumpHome(tester, service);

    expect(find.text('Add a hero profile'), findsOneWidget);
    expect(find.text('Add a profile'), findsWidgets);
    expect(find.byKey(const ValueKey<String>('home-new-story')), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('home-hero-switcher')),
      findsNothing,
    );
  });
}

/// Builds the real application on the home mosaic behind the real parent gate.
///
/// The route is chosen by the suite's own `setUp`, so nothing is passed here.
Future<void> _pumpHome(WidgetTester tester, ParentSecurityService service) {
  return pumpApp(
    tester,
    overrides: [parentSecurityServiceProvider.overrideWithValue(service)],
  );
}

/// Reports whether the shelf chip of one child is the selected one.
bool _chipIsSelected(WidgetTester tester, String profileId) {
  return tester
      .widget<ChoiceChip>(
        find.byKey(ValueKey<String>('shelf-child-$profileId')),
      )
      .selected;
}

/// Saves a verifier the way settings would, before the app is first built.
Future<void> _configurePin(ParentSecurityService service, String pin) async {
  final repository = await LocalRepository.open();
  await repository.saveParentSecurity(await service.createRecord(pin));
}

/// Stores one family, Miko active unless another child is named, and a library.
Future<void> _storeFamily({
  required List<ChildProfile> profiles,
  List<StoryBook> stories = const <StoryBook>[],
  String activeProfileId = 'miko',
}) {
  return seedDevice(
    profiles: profiles,
    stories: stories,
    activeProfileId: activeProfileId,
  );
}

/// Stores the girl profile Home reads as, with her reward history.
ChildProfile _miko({List<String> finishedStoryIds = const <String>[]}) {
  return child(
    themeColorValue: AppTheme.girlPink.toARGB32(),
    finishedStoryIds: finishedStoryIds,
  );
}

/// Stores the second child the switcher can hand the app to.
ChildProfile _abbas() {
  return child(
    id: 'abbas',
    name: 'Abbas',
    legacyAge: 9,
    gender: ChildGender.boy,
    themeColorValue: AppTheme.boyCyan.toARGB32(),
  );
}

/// Builds one stored two-page story written by the offline demo generator.
StoryBook _story({
  StoryReviewStatus reviewStatus = StoryReviewStatus.approved,
  String id = 'story-1',
  String profileId = 'miko',
  String heroName = 'Miko',
  String title = 'The moon garden',
  int createdAtHour = 12,
}) {
  return book(
    id: id,
    profileId: profileId,
    heroName: heroName,
    title: title,
    reviewStatus: reviewStatus,
    createdAt: DateTime.utc(2026, 8, 17, createdAtHour),
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
