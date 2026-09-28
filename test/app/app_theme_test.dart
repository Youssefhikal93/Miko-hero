import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// Verifies the shared skin: palette tokens, interface type, and the accent.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the palette tokens hold the redesign values', () {
    expect(AppTheme.night, const Color(0xFF0A0D18));
    expect(AppTheme.tile, const Color(0xFF151A2E));
    expect(AppTheme.sunken, const Color(0xFF141930));
    expect(AppTheme.candle, const Color(0xFFFFB43A));
    expect(AppTheme.candleLight, const Color(0xFFFFC469));
    expect(AppTheme.onCandle, const Color(0xFF2A1900));
    expect(AppTheme.light, const Color(0xFFF2EFEA));
    expect(AppTheme.frost, const Color(0xFFC6CBDC));
    expect(AppTheme.muted, const Color(0xFF9AA1B8));
    expect(AppTheme.mutedDeep, const Color(0xFF6E7793));
    expect(AppTheme.hairline, const Color(0xFF262D45));
    expect(AppTheme.hairlineWarm, const Color(0xFF3A3320));
  });

  test('the tokens the features used to spell out hold their old values', () {
    expect(AppTheme.violet, const Color(0xFF8A31CB));
    expect(AppTheme.onCover, const Color(0xFFFFFFFF));
    expect(AppTheme.onCoverMuted, const Color(0xCCFFFFFF));
    expect(AppTheme.onCoverVeil, const Color(0x3DFFFFFF));
    expect(AppTheme.coverShade, const Color(0x73000000));
    expect(AppTheme.coverPill, const Color(0x66000000));
    expect(AppTheme.danger, const Color(0xFFFF5252));
    expect(AppTheme.ready, const Color(0xFF69F0AE));
    expect(AppTheme.attention, const Color(0xFFFFAB40));
    expect(AppTheme.ambientGlow, const Color(0x222F2340));
    expect(AppTheme.mediaWell, const Color(0xFF222635));
    expect(AppTheme.coverScrim.colors, const <Color>[
      Color(0xD106080F),
      Color(0x1406080F),
    ]);
    expect(AppTheme.coverScrim.stops, const <double>[0, 0.65]);
    expect(AppTheme.coverScrim.begin, Alignment.bottomCenter);
    expect(AppTheme.coverScrim.end, Alignment.topCenter);
  });

  test('the caption and overline slots hold their old metrics', () {
    expect(AppTheme.caption.fontSize, 13);
    expect(AppTheme.coverCaption.fontSize, 13);
    expect(AppTheme.overline.fontSize, 13);
    expect(AppTheme.overline.letterSpacing, 1.3);
    expect(AppTheme.overline.fontWeight, FontWeight.w700);
    expect(AppTheme.overlineTile.fontSize, 11);
    expect(AppTheme.overlineTile.letterSpacing, 1.3);
    expect(AppTheme.overlineTile.fontWeight, FontWeight.w700);
    expect(AppTheme.overlineSoft.fontSize, 11);
    expect(AppTheme.overlineSoft.letterSpacing, 1.1);
    expect(AppTheme.badgeLabel.fontSize, 11);
    expect(AppTheme.badgeLabel.fontWeight, FontWeight.w900);
    expect(AppTheme.codeBadge.fontSize, 12);
    expect(AppTheme.codeBadge.letterSpacing, 0.7);
    expect(AppTheme.sectionLabel.letterSpacing, 1.3);
    expect(AppTheme.sectionLabel.fontWeight, FontWeight.w600);
  });

  test('the quiet inks say which surface each of them belongs to', () {
    expect(AppTheme.caption.color, AppTheme.mutedDeep);
    expect(AppTheme.coverCaption.color, AppTheme.frost);
    expect(AppTheme.overline.color, AppTheme.mutedDeep);
    expect(AppTheme.overlineSoft.color, AppTheme.mutedDeep);
    expect(AppTheme.sectionLabel.color, AppTheme.mutedDeep);
    expect(AppTheme.overlineTile.color, AppTheme.candleLight);
    expect(AppTheme.caption.fontSize, AppTheme.coverCaption.fontSize);
  });

  test('a slot carries no family, so it merges into the interface face', () {
    for (final slot in _slots) {
      expect(slot.fontFamily, isNull);
      expect(slot.fontVariations, isNull);
    }
    expect(AppTheme.badgeLabel.color, isNull);
    expect(AppTheme.codeBadge.color, isNull);
  });

  test('the theme owns the script face, so no feature asks for one', () {
    expect(AppTheme.scriptStyleFor(AppLanguage.english), isNull);
    expect(AppTheme.scriptStyleFor(AppLanguage.swedish), isNull);
    expect(AppTheme.scriptStyleFor(AppLanguage.somali), isNull);
    expect(
      AppTheme.scriptStyleFor(AppLanguage.arabic)?.fontFamily,
      arabicInterfaceFontFamily,
    );
    expect(
      AppTheme.scriptStyleFor(AppLanguage.arabic)?.fontVariations,
      isEmpty,
    );
  });

  test('the built theme paints every surface from the tokens', () {
    final theme = AppTheme.dark(null);

    expect(theme.scaffoldBackgroundColor, AppTheme.night);
    expect(theme.canvasColor, AppTheme.night);
    expect(theme.colorScheme.surface, AppTheme.tile);
    expect(theme.colorScheme.onSurface, AppTheme.light);
    expect(theme.colorScheme.onSurfaceVariant, AppTheme.muted);
    expect(theme.colorScheme.outline, AppTheme.hairline);
    expect(theme.dividerColor, AppTheme.hairline);
    expect(theme.appBarTheme.backgroundColor, AppTheme.night);
    expect(theme.appBarTheme.foregroundColor, AppTheme.light);
    expect(theme.appBarTheme.iconTheme?.color, AppTheme.frost);
    expect(theme.appBarTheme.actionsIconTheme?.color, AppTheme.frost);
  });

  test('every component theme reads the tokens', () {
    final theme = AppTheme.dark(null);

    expect(theme.cardTheme.color, AppTheme.tile);
    expect(_cardBorder(theme).color, AppTheme.hairline);
    expect(theme.inputDecorationTheme.fillColor, AppTheme.sunken);
    expect(_inputBorder(theme).color, AppTheme.hairline);
    expect(theme.inputDecorationTheme.labelStyle?.color, AppTheme.muted);
    expect(theme.inputDecorationTheme.hintStyle?.color, AppTheme.mutedDeep);
    expect(theme.chipTheme.backgroundColor, AppTheme.sunken);
    expect(theme.chipTheme.labelStyle?.color, AppTheme.light);
    expect(_chipSide(theme, selected: false).color, AppTheme.hairline);
    expect(theme.dialogTheme.backgroundColor, AppTheme.tile);
    expect(theme.dialogTheme.titleTextStyle?.color, AppTheme.light);
    expect(theme.dialogTheme.contentTextStyle?.color, AppTheme.muted);
    expect(
      theme.textButtonTheme.style?.foregroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppTheme.candleLight,
    );
    expect(
      theme.outlinedButtonTheme.style?.side
          ?.resolve(const <WidgetState>{})
          ?.color,
      AppTheme.hairline,
    );
    expect(
      theme.navigationBarTheme.backgroundColor,
      AppTheme.sunken.withValues(alpha: 0.96),
    );
    expect(theme.navigationRailTheme.backgroundColor, AppTheme.sunken);
    expect(theme.navigationDrawerTheme.backgroundColor, AppTheme.night);
  });

  test('a profile without a saved color is lit by the candle', () {
    final theme = AppTheme.dark(null);

    expect(theme.colorScheme.primary, AppTheme.candle);
    expect(theme.colorScheme.onPrimary, AppTheme.onCandle);
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppTheme.onCandle,
    );
    expect(AppTheme.primaryFor(ChildGender.unspecified), AppTheme.candle);
  });

  test('the active profile colour stays the accent', () {
    final theme = AppTheme.dark(_profile(cyanProfileThemeColorValue));

    expect(theme.colorScheme.primary, AppTheme.boyCyan);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve(
        const <WidgetState>{},
      ),
      AppTheme.boyCyan,
    );
    expect(_chipSide(theme, selected: true).color, AppTheme.boyCyan);
    expect(
      theme.navigationBarTheme.indicatorColor,
      AppTheme.boyCyan.withValues(alpha: 0.18),
    );
    expect(
      theme.navigationRailTheme.selectedIconTheme?.color,
      AppTheme.boyCyan,
    );
  });

  test('the interface speaks in Outfit', () {
    final theme = AppTheme.dark(null);

    for (final style in _interfaceStyles(theme)) {
      expect(style.fontFamily, interfaceFontFamily);
    }
    expect(
      theme.textTheme.titleLarge?.fontVariations,
      contains(const FontVariation('wght', 700)),
    );
    expect(theme.chipTheme.labelStyle?.fontFamily, interfaceFontFamily);
    expect(theme.dialogTheme.titleTextStyle?.fontFamily, interfaceFontFamily);
    expect(
      theme.filledButtonTheme.style?.textStyle
          ?.resolve(const <WidgetState>{})
          ?.fontFamily,
      interfaceFontFamily,
    );
    expect(
      theme.navigationBarTheme.labelTextStyle
          ?.resolve(const <WidgetState>{})
          ?.fontFamily,
      interfaceFontFamily,
    );
  });

  test('the Arabic interface never asks for Outfit', () {
    final theme = AppTheme.dark(null, locale: const Locale('ar'));

    for (final style in _interfaceStyles(theme)) {
      expect(style.fontFamily, isNot(interfaceFontFamily));
      expect(style.fontFamily, arabicInterfaceFontFamily);
      expect(style.fontVariations, isNull);
    }
    expect(theme.chipTheme.labelStyle?.fontFamily, arabicInterfaceFontFamily);
    expect(
      theme.navigationBarTheme.labelTextStyle
          ?.resolve(const <WidgetState>{})
          ?.fontFamily,
      arabicInterfaceFontFamily,
    );
    expect(
      interfaceFontFamilyFor(AppLanguage.arabic),
      isNot(interfaceFontFamily),
    );
    expect(interfaceFontFamilyFor(AppLanguage.english), interfaceFontFamily);
    expect(interfaceFontFamilyFor(AppLanguage.swedish), interfaceFontFamily);
    expect(interfaceFontFamilyFor(AppLanguage.somali), interfaceFontFamily);
  });

  test('every other locale keeps the Latin interface face', () {
    for (final code in const <String>['en', 'sv', 'so']) {
      final theme = AppTheme.dark(null, locale: Locale(code));

      expect(theme.textTheme.bodyLarge?.fontFamily, interfaceFontFamily);
    }
  });

  test('both interface faces are bundled with the app', () async {
    final outfit = await rootBundle.load('assets/fonts/Outfit-Variable.ttf');
    final arabic = await rootBundle.load(
      'assets/fonts/NotoNaskhArabic-Regular.ttf',
    );

    expect(outfit.lengthInBytes, greaterThan(1000));
    expect(arabic.lengthInBytes, greaterThan(1000));
  });

  test('no feature names a Material colour of its own', () {
    final offenders = _offenders(
      RegExp(r'\bColors\.(\w+)'),
      allowed: (file, match) => match.group(1) == 'transparent',
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Colors.* belongs in the palette. Colors.transparent is allowed: it '
          'names the absence of a colour, not a choice of one.\n'
          '${offenders.join('\n')}',
    );
  });

  test('no feature spells a colour out as a hex literal', () {
    final offenders = _offenders(
      RegExp(r'Color\(0x'),
      allowed: (file, match) => file == _kingdomDecorations,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Every colour comes from AppTheme. The one exception is '
          '$_kingdomDecorations, whose backdrop tints are a per-child '
          'decoration table rather than palette tokens.\n'
          '${offenders.join('\n')}',
    );
  });

  test('no feature sets its own tracking', () {
    final offenders = _offenders(RegExp('letterSpacing:'));

    expect(
      offenders,
      isEmpty,
      reason:
          'Tracking is a type-scale decision: use AppTheme.overline, '
          'overlineTile, overlineSoft, codeBadge or sectionLabel.\n'
          '${offenders.join('\n')}',
    );
  });

  test('no feature writes its own caption-sized text style', () {
    final offenders = _offenders(
      RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)'),
      allowed: (file, match) => double.parse(match.group(1)!) >= 14,
    );

    expect(
      offenders,
      isEmpty,
      reason:
          'Anything under 14 is the caption and overline band the theme owns: '
          'use AppTheme.caption, coverCaption or one of the overline slots. '
          'Larger one-off display sizes stay with the widget that needs them.\n'
          '${offenders.join('\n')}',
    );
  });
}

/// Feature and shared source the palette rules are enforced over.
const _scannedDirectories = <String>['lib/features', 'lib/shared'];

/// The one file allowed to spell colours out, and why it is exempt.
const _kingdomDecorations = 'lib/features/kingdom/kingdom_decorations.dart';

/// Whether one match in [file] is a deliberate, documented exception.
typedef _Exemption = bool Function(String file, RegExpMatch match);

/// Every text slot that has to stay free of a face of its own.
const _slots = <TextStyle>[
  AppTheme.caption,
  AppTheme.coverCaption,
  AppTheme.overline,
  AppTheme.overlineTile,
  AppTheme.overlineSoft,
  AppTheme.badgeLabel,
  AppTheme.codeBadge,
  AppTheme.sectionLabel,
];

/// Lists every `path:line` in the scanned tree that breaks one rule.
///
/// Reads the sources rather than a rendered widget, because the rule being
/// checked is about where a value is written down, not about what one screen
/// happens to paint.
List<String> _offenders(RegExp pattern, {_Exemption? allowed}) {
  final offenders = <String>[];
  for (final path in _scannedSources()) {
    final lines = File(path).readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      for (final match in pattern.allMatches(lines[index])) {
        if (allowed != null && allowed(path, match)) continue;
        offenders.add('$path:${index + 1}: ${lines[index].trim()}');
      }
    }
  }
  return offenders;
}

/// Every Dart file under the scanned directories, in a stable order.
List<String> _scannedSources() {
  final paths = <String>[];
  for (final directory in _scannedDirectories) {
    final entries = Directory(directory).listSync(recursive: true);
    for (final entry in entries) {
      if (entry is! File || !entry.path.endsWith('.dart')) continue;
      paths.add(entry.path.replaceAll(r'\', '/'));
    }
  }
  return paths..sort();
}

/// Builds a saved profile carrying one of the offered accent colours.
ChildProfile _profile(int themeColorValue) {
  return ChildProfile(
    id: 'child',
    name: 'Miko',
    legacyAge: 7,
    photoBase64: '',
    gender: ChildGender.unspecified,
    themeColorValue: themeColorValue,
    hasCustomThemeColor: false,
  );
}

/// Every text slot the interface can speak through.
List<TextStyle> _interfaceStyles(ThemeData theme) {
  final text = theme.textTheme;
  return <TextStyle>[
    text.displayLarge!,
    text.displayMedium!,
    text.displaySmall!,
    text.headlineLarge!,
    text.headlineMedium!,
    text.headlineSmall!,
    text.titleLarge!,
    text.titleMedium!,
    text.titleSmall!,
    text.bodyLarge!,
    text.bodyMedium!,
    text.bodySmall!,
    text.labelLarge!,
    text.labelMedium!,
    text.labelSmall!,
  ];
}

/// Reads the hairline a card is outlined with.
BorderSide _cardBorder(ThemeData theme) {
  return (theme.cardTheme.shape! as RoundedRectangleBorder).side;
}

/// Reads the hairline a field is outlined with.
BorderSide _inputBorder(ThemeData theme) {
  return theme.inputDecorationTheme.enabledBorder!.borderSide;
}

/// Resolves the border a chip carries in the requested selection state.
BorderSide _chipSide(ThemeData theme, {required bool selected}) {
  return (theme.chipTheme.side! as WidgetStateBorderSide).resolve(
    selected
        ? const <WidgetState>{WidgetState.selected}
        : const <WidgetState>{},
  )!;
}
