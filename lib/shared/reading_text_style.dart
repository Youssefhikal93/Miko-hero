import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';

/// Bundled serif family used for Latin-script story prose.
///
/// Declared in `pubspec.yaml` from the Newsreader variable asset, which is
/// licensed under the SIL Open Font License.
const newsreaderFontFamily = 'Newsreader';

/// Fallback prose size used when the theme defines no body style.
const _fallbackProseFontSize = 17.0;

/// Size increase that separates book prose from the interface body scale.
const _proseFontSizeScale = 1.15;

/// Comfortable line height used for continuous story reading.
const _proseLineHeight = 1.6;

/// Resolves story prose typography from one child's saved reading comfort.
///
/// Steps up from the theme's interface body metrics, then applies the child's
/// saved size. Latin-script prose uses Newsreader unless the child selected the
/// easy-reading family. Arabic keeps the theme's existing body face. Shared by
/// the reader and the parent review preview so both show the same typography.
TextStyle readingProseStyle(
  BuildContext context, {
  required ChildReadingSettings settings,
  required AppLanguage language,
}) {
  final base =
      Theme.of(context).textTheme.bodyLarge ??
      const TextStyle(fontSize: _fallbackProseFontSize);
  final fontFamily = language.usesLatinScript
      ? settings.proseFontFamily(language) ?? newsreaderFontFamily
      : base.fontFamily;
  return base.copyWith(
    fontSize:
        (base.fontSize ?? _fallbackProseFontSize) *
        _proseFontSizeScale *
        settings.textSize.scale,
    fontFamily: fontFamily,
    fontVariations: language.usesLatinScript
        ? const <FontVariation>[]
        : base.fontVariations,
    height: _proseLineHeight,
  );
}
