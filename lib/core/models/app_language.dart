import 'dart:ui';

/// Languages available for both application chrome and generated stories.
enum AppLanguage {
  /// English with left-to-right layout.
  english('en', 'en-US'),

  /// Arabic with right-to-left layout.
  arabic('ar', 'ar-SA'),

  /// Swedish with left-to-right layout.
  swedish('sv', 'sv-SE'),

  /// Somali with left-to-right layout.
  somali('so', 'so-SO');

  /// Creates a supported language from its persisted and speech locale codes.
  const AppLanguage(this.code, this.speechLocale);

  /// Stable language code written to local storage.
  final String code;

  /// Locale requested from the platform text-to-speech engine.
  final String speechLocale;

  /// Locale used by Flutter's localization system.
  Locale get locale => Locale(code);

  /// Resolves persisted input and falls back to English for unknown values.
  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (language) => language.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}
