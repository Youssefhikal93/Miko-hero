import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// Iam - hero visual system shared by every target platform.
abstract final class AppTheme {
  /// Warm amber used for primary actions and story highlights.
  static const amber = Color(goldenProfileThemeColorValue);

  /// Deeper orange used in gradients and focused states.
  static const orange = Color(0xFFFF7426);

  /// Pink accent applied after selecting a girl profile.
  static const girlPink = Color(roseProfileThemeColorValue);

  /// Soft pink used for girl-profile gradients and secondary controls.
  static const girlRose = Color(0xFFFF91C5);

  /// Cyan accent applied after selecting a boy profile.
  static const boyCyan = Color(cyanProfileThemeColorValue);

  /// Purple palette offered as a one-tap My Kingdom choice.
  static const purple = Color(0xFF9C6BFF);

  /// Green palette offered as a one-tap My Kingdom choice.
  static const green = Color(0xFF43D19E);

  /// Blue used for boy-profile gradients and secondary controls.
  static const boyBlue = Color(0xFF3987FF);

  /// Near-black navy used behind the premium storybook surfaces.
  static const ink = Color(0xFF090B12);

  /// Raised surface color that remains distinct from the background.
  static const panel = Color(0xFF151823);

  /// Warm, dimmed prose color used by the reader's bedtime mode.
  ///
  /// Deliberately softer than white while staying well above the contrast a
  /// child needs to keep reading in a dark room.
  static const bedtimeProse = Color(0xFFE9CFA4);

  /// Warm page surface behind bedtime prose.
  static const bedtimeSurface = Color(0xFF1B1409);

  /// Dimming and warming wash drawn over bedtime illustrations.
  static const bedtimeWash = LinearGradient(
    colors: <Color>[Color(0xB3140A02), Color(0x8CFF9A3C)],
  );

  /// Creates a dark Material theme from the active child's saved opaque color.
  static ThemeData dark(ChildProfile? profile) {
    final primary = profile == null ? amber : Color(profile.themeColorValue);
    final secondary = _secondaryForPrimary(primary);
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: panel,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(primary: primary, secondary: secondary),
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      textTheme: _textTheme(),
      cardTheme: _cardTheme(),
      inputDecorationTheme: _inputTheme(),
      filledButtonTheme: _buttonTheme(primary, scheme.onPrimary),
      navigationBarTheme: _navigationTheme(primary),
    );
  }

  /// Resolves the primary accent for neutral, girl, and boy profile states.
  static Color primaryFor(ChildGender gender) {
    return switch (gender) {
      ChildGender.unspecified => amber,
      ChildGender.girl => girlPink,
      ChildGender.boy => boyCyan,
    };
  }

  /// Resolves the secondary gradient color paired with a profile accent.
  static Color secondaryFor(ChildGender gender) {
    return switch (gender) {
      ChildGender.unspecified => orange,
      ChildGender.girl => girlRose,
      ChildGender.boy => boyBlue,
    };
  }

  /// Produces a softer companion shade for arbitrary parent-selected colors.
  static Color _secondaryForPrimary(Color primary) {
    final hsl = HSLColor.fromColor(primary);
    return hsl
        .withSaturation((hsl.saturation * 0.78).clamp(0.35, 0.86))
        .withLightness((hsl.lightness + 0.16).clamp(0.48, 0.82))
        .toColor();
  }

  /// Defines a compact display scale that remains readable on small phones.
  static TextTheme _textTheme() {
    return const TextTheme(
      displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 17, height: 1.55),
      bodyMedium: TextStyle(fontSize: 15, height: 1.5),
    );
  }

  /// Keeps cards visually consistent without hiding focus or content edges.
  static CardThemeData _cardTheme() {
    return CardThemeData(
      color: panel,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF292D3B)),
      ),
    );
  }

  /// Gives forms a clear, high-contrast surface on all breakpoints.
  static InputDecorationTheme _inputTheme() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Color(0xFF303544)),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF10131C),
      border: border,
      enabledBorder: border,
    );
  }

  /// Styles primary calls to action with the active child's saved accent.
  static FilledButtonThemeData _buttonTheme(Color primary, Color foreground) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: foreground,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Highlights the current bottom destination without an opaque bar.
  static NavigationBarThemeData _navigationTheme(Color primary) {
    return NavigationBarThemeData(
      backgroundColor: const Color(0xF20F121A),
      indicatorColor: primary.withValues(alpha: 0.18),
      height: 72,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
