import 'package:flutter/material.dart';

/// Iam - hero visual system shared by every target platform.
abstract final class AppTheme {
  /// Warm amber used for primary actions and story highlights.
  static const amber = Color(0xFFFFB43A);

  /// Deeper orange used in gradients and focused states.
  static const orange = Color(0xFFFF7426);

  /// Near-black navy used behind the premium storybook surfaces.
  static const ink = Color(0xFF090B12);

  /// Raised surface color that remains distinct from the background.
  static const panel = Color(0xFF151823);

  /// Creates the accessible dark Material theme used throughout the app.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: amber,
      brightness: Brightness.dark,
      surface: panel,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(primary: amber, secondary: orange),
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      textTheme: _textTheme(),
      cardTheme: _cardTheme(),
      inputDecorationTheme: _inputTheme(),
      filledButtonTheme: _buttonTheme(),
      navigationBarTheme: _navigationTheme(),
    );
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

  /// Styles primary calls to action as warm storybook highlights.
  static FilledButtonThemeData _buttonTheme() {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: amber,
        foregroundColor: const Color(0xFF211400),
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Highlights the current bottom destination without an opaque bar.
  static NavigationBarThemeData _navigationTheme() {
    return NavigationBarThemeData(
      backgroundColor: const Color(0xF20F121A),
      indicatorColor: amber.withValues(alpha: 0.18),
      height: 72,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }
}
