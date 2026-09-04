import 'package:flutter/material.dart';
// `Override` is the type of a `ProviderScope` entry, but only this library of
// the package exports the name itself.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/profile/hero_sheet_controller.dart';
import 'package:miko_hero/features/profile/name_spellings_section.dart';

import '../../support/seeded_device.dart';

/// The one child this suite is about: entered in Latin, read in four scripts.
ChildProfile _malika({Map<AppLanguage, String>? spellings}) {
  return child(
    id: 'malika',
    name: 'Malika',
    nameSpellings:
        spellings ??
        const <AppLanguage, String>{
          AppLanguage.arabic: 'مليكة',
          AppLanguage.somali: 'Maliika',
        },
  );
}

/// A PC that always answers with the same four spellings.
Override _suggesterAnswering(Map<AppLanguage, String> spellings) {
  return nameSpellingSuggesterProvider.overrideWithValue(
    ({required String heroName, String? genderContext}) async => spellings,
  );
}

/// A PC that is reachable in settings but cannot answer this call.
Override get _suggesterFailing {
  return nameSpellingSuggesterProvider.overrideWithValue(
    ({required String heroName, String? genderContext}) async =>
        throw const BridgeException(BridgeFailure.unreachable),
  );
}

/// A PC that keeps no drawn-hero sheet for this child.
///
/// This suite is about the four spellings, and the editor's other card asks
/// the PC a question of its own the moment it opens. Answering that one with
/// "there is nothing to show" — a real state, not a failure — keeps the
/// hero-sheet card silent so a message on screen can only have come from the
/// spellings. `hero_sheet_editor_test.dart` is where that card is exercised.
Override get _quietHeroSheet {
  return heroSheetControllerProvider.overrideWithValue(_NoHeroSheet());
}

/// Answers every hero-sheet command with "the PC has nothing for this child".
class _NoHeroSheet implements HeroSheetController {
  @override
  Future<BridgeHeroSheet?> readSheet(String profileId) async => null;

  @override
  Future<BridgeHeroSheet?> saveWardrobe({
    required String profileId,
    required String outfit,
    required String prop,
  }) async => null;

  @override
  Future<BridgeHeroSheet?> rereadFromPhoto(String profileId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await seedDevice();
    appRouter.go('/');
  });

  testWidgets('the Arabic interface reads the Arabic spelling of the name', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[_malika()],
      activeProfileId: 'malika',
      locale: AppLanguage.arabic.locale,
    );

    await pumpApp(tester, route: '/');

    final label = find.text('مليكة');
    expect(label, findsOneWidget);
    expect(Directionality.of(tester.element(label)), TextDirection.rtl);
    expect(
      find.text('Malika'),
      findsNothing,
      reason: 'the Latin spelling has no place in an Arabic interface',
    );
  });

  testWidgets('the same profile still reads Malika in English', (tester) async {
    await seedDevice(
      profiles: <ChildProfile>[_malika()],
      activeProfileId: 'malika',
      locale: AppLanguage.english.locale,
    );

    await pumpApp(tester, route: '/');

    expect(find.text('Malika'), findsOneWidget);
    expect(find.text('مليكة'), findsNothing);
  });

  testWidgets('the hero switcher names every child in the read language', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[_malika()],
      activeProfileId: 'malika',
      locale: AppLanguage.arabic.locale,
    );
    await pumpApp(tester, route: '/');

    await tester.tap(find.byKey(const ValueKey<String>('home-hero-switcher')));
    await tester.pumpAndSettle();

    expect(find.text('مليكة hero'), findsOneWidget);
  });

  testWidgets('a language with no saved spelling keeps the entered name', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[
        _malika(
          spellings: const <AppLanguage, String>{AppLanguage.arabic: 'مليكة'},
        ),
      ],
      activeProfileId: 'malika',
      locale: AppLanguage.swedish.locale,
    );

    await pumpApp(tester, route: '/');

    expect(find.text('Malika'), findsOneWidget);
  });

  testWidgets('an unpaired editor still lets the parent type the spellings', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[
        _malika(spellings: const <AppLanguage, String>{}),
      ],
      activeProfileId: 'malika',
    );
    await pumpApp(tester, route: '/profiles/malika');

    final suggest = find.byKey(
      const ValueKey<String>('suggest-name-spellings'),
    );
    expect(suggest, findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).first).onPressed,
      isNotNull,
      reason: 'the save button is still live; only the PC action is not',
    );
    expect(
      find.text('Connect the family PC to have these filled in for you.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('name-spelling-ar')),
      'مليكة',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();

    // Away and back, so the boxes are seeded from the stored profile rather
    // than from the editor state the typing left behind.
    expect(appRouter.state.uri.path, '/kingdom');
    appRouter.go('/profiles/malika');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('name-spelling-ar')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'مليكة',
    );
  });

  testWidgets('a paired editor with no spellings asks the PC once, itself', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[
        _malika(spellings: const <AppLanguage, String>{}),
      ],
      activeProfileId: 'malika',
      aiConnection: localAiConnection(),
      bridgeCredential: pairedDevice(),
    );

    await pumpApp(
      tester,
      route: '/profiles/malika',
      overrides: <Override>[
        _quietHeroSheet,
        _suggesterAnswering(const <AppLanguage, String>{
          AppLanguage.arabic: 'مليكة',
          AppLanguage.english: 'Malika',
          AppLanguage.swedish: 'Malika',
          AppLanguage.somali: 'Maliika',
        }),
      ],
    );

    for (final entry in const <String, String>{
      'ar': 'مليكة',
      'en': 'Malika',
      'sv': 'Malika',
      'so': 'Maliika',
    }.entries) {
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(ValueKey<String>('name-spelling-${entry.key}')),
                matching: find.byType(TextField),
              ),
            )
            .controller
            ?.text,
        entry.value,
        reason: 'the ${entry.key} box was not filled by the PC',
      );
    }
  });

  testWidgets('a PC that cannot answer never interrupts the edit', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[
        _malika(spellings: const <AppLanguage, String>{}),
      ],
      activeProfileId: 'malika',
      aiConnection: localAiConnection(),
      bridgeCredential: pairedDevice(),
    );

    await pumpApp(
      tester,
      route: '/profiles/malika',
      overrides: <Override>[_quietHeroSheet, _suggesterFailing],
    );

    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('name-spelling-ar')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      isEmpty,
    );
  });
}
