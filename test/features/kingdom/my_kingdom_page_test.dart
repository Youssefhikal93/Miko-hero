import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/features/kingdom/kingdom_decorations.dart';

import '../../support/seeded_device.dart';

/// Verifies that each child keeps their own kingdom decoration.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await seedDevice(
      profiles: <ChildProfile>[
        child(),
        child(id: 'abbas', name: 'Abbas', gender: ChildGender.boy),
      ],
      activeProfileId: 'miko',
    );
  });

  testWidgets('choosing a castle, frame, backdrop, and symbol saves them', (
    tester,
  ) async {
    await pumpApp(tester, route: '/kingdom');

    expect(_castle(tester).style, CastleStyle.classicTowers);

    await _choose(tester, 'castle-crystalSpires');
    expect(find.text('Kingdom style saved for Miko'), findsOneWidget);
    expect(_castle(tester).style, CastleStyle.crystalSpires);

    await _choose(tester, 'frame-hearts');
    expect(_summaryAvatar(tester).frame, AvatarFrameStyle.hearts);

    await _choose(tester, 'backdrop-ocean');
    await _choose(tester, 'symbol-rocket');

    expect(_selected(tester, 'backdrop-ocean'), isTrue);
    expect(_selected(tester, 'symbol-rocket'), isTrue);
    expect(find.byIcon(kingdomSymbolIcon(KingdomSymbol.rocket)), findsWidgets);
  });

  testWidgets('a second hero keeps decoration choices of their own', (
    tester,
  ) async {
    await pumpApp(tester, route: '/kingdom');

    await _choose(tester, 'castle-roundDomes');
    await _choose(tester, 'symbol-football');

    await _switchHero(tester, 'abbas');
    expect(_castle(tester).style, CastleStyle.classicTowers);
    expect(_selected(tester, 'symbol-star'), isTrue);

    await _choose(tester, 'castle-forestTreehouse');
    expect(find.text('Kingdom style saved for Abbas'), findsOneWidget);
    expect(_castle(tester).style, CastleStyle.forestTreehouse);

    await _switchHero(tester, 'miko');
    expect(_castle(tester).style, CastleStyle.roundDomes);
    expect(_selected(tester, 'symbol-football'), isTrue);
  });
}

/// Selects one decoration chip and waits for its persisted rebuild.
Future<void> _choose(WidgetTester tester, String chipKey) async {
  final chip = find.byKey(ValueKey<String>(chipKey));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Activates another hero from the kingdom profile switcher.
Future<void> _switchHero(WidgetTester tester, String profileId) async {
  final chooser = find.byKey(ValueKey<String>('kingdom-profile-$profileId'));
  await tester.ensureVisible(chooser);
  await tester.pumpAndSettle();
  await tester.tap(chooser, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Reads the decorative header currently painted for the active hero.
KingdomCastle _castle(WidgetTester tester) {
  return tester.widget<KingdomCastle>(find.byType(KingdomCastle));
}

/// Reads the framed avatar shown in the active hero's summary card.
KingdomAvatar _summaryAvatar(WidgetTester tester) {
  return tester.widget<KingdomAvatar>(find.byType(KingdomAvatar).last);
}

/// Reports whether one decoration chip currently shows as selected.
bool _selected(WidgetTester tester, String chipKey) {
  return tester
      .widget<ChoiceChip>(find.byKey(ValueKey<String>(chipKey)))
      .selected;
}
