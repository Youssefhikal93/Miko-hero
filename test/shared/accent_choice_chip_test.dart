import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/shared/accent_choice_chip.dart';

/// Verifies the one chip the shelf and the creation form are chosen from.
///
/// Which chip a tap selects is asserted where the rows live; what is proved
/// here is the chip itself: that a chip left to the theme takes the reading
/// child's accent, that a chip handed an accent of its own is tinted and
/// ringed in that one instead, that neither ever swaps its face for a
/// checkmark, and that a chip with nothing to choose refuses the tap.
void main() {
  const otherAccent = AppTheme.girlPink;

  testWidgets('a chip with no accent of its own leaves both to the theme', (
    tester,
  ) async {
    await _pumpChip(tester, selected: true);

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selectedColor, isNull);
    expect(chip.side, isNull);
    expect(
      _chipTheme(tester).selectedColor,
      AppTheme.candle.withValues(alpha: 0.18),
      reason: 'the theme is what lights it, at the shared fraction',
    );
  });

  testWidgets('a chip lit by another child is tinted and ringed in that '
      'accent', (tester) async {
    await _pumpChip(tester, selected: true, accent: otherAccent);

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.selectedColor, otherAccent.withValues(alpha: 0.18));
    expect(chip.side, const BorderSide(color: otherAccent));
  });

  testWidgets('the same chip unselected keeps the shared hairline ring', (
    tester,
  ) async {
    await _pumpChip(tester, selected: false, accent: otherAccent);

    final chip = tester.widget<ChoiceChip>(find.byType(ChoiceChip));
    expect(chip.side, const BorderSide(color: AppTheme.hairline));
  });

  testWidgets('a selected chip keeps its face instead of a checkmark', (
    tester,
  ) async {
    await _pumpChip(
      tester,
      selected: true,
      accent: otherAccent,
      avatar: const Text('M'),
    );

    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip)).showCheckmark,
      isFalse,
    );
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('a tap chooses the chip', (tester) async {
    var chosen = 0;
    await _pumpChip(tester, selected: false, onSelected: () => chosen++);

    await tester.tap(find.byType(AccentChoiceChip));
    await tester.pumpAndSettle();

    expect(chosen, 1);
  });

  testWidgets('a chip with nothing to choose is disabled', (tester) async {
    await _pumpChip(tester, selected: false, onSelected: null);

    expect(
      tester.widget<ChoiceChip>(find.byType(ChoiceChip)).isEnabled,
      isFalse,
    );
  });
}

/// Places one chip on the real application skin at its natural size.
Future<void> _pumpChip(
  WidgetTester tester, {
  required bool selected,
  Color? accent,
  Widget? avatar,
  VoidCallback? onSelected = _doNothing,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(null),
      home: Scaffold(
        body: Center(
          child: AccentChoiceChip(
            label: const Text('Bedtime'),
            selected: selected,
            onSelected: onSelected,
            accent: accent,
            avatar: avatar,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The chip skin the pumped application is actually wearing.
ChipThemeData _chipTheme(WidgetTester tester) {
  return Theme.of(tester.element(find.byType(AccentChoiceChip))).chipTheme;
}

/// A choice a test does not care about making.
void _doNothing() {}
