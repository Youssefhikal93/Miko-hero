import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/shared/screen_layout.dart';

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

  testWidgets('the hero panel is a flat tile ringed by the accent', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(_profile(roseProfileThemeColorValue)),
        home: const Scaffold(body: AccentPanel(child: Text('hero'))),
      ),
    );

    final decoration =
        tester
                .widget<Container>(
                  find.ancestor(
                    of: find.text('hero'),
                    matching: find.byType(Container),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, AppTheme.tile);
    expect(
      decoration.border?.top.color,
      AppTheme.girlPink.withValues(alpha: 0.55),
    );
  });
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
