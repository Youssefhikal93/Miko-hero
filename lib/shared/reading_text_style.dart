import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';

/// Fallback prose size used when the theme defines no body style.
const _fallbackProseFontSize = 17.0;

/// Resolves story prose typography from one child's saved reading comfort.
///
/// Scales the theme's body size instead of replacing it, and only asks for the
/// bundled easy-reading family when [language] is written in Latin script, so
/// Arabic prose keeps the rendering it always had. Shared by the reader and the
/// parent review preview so both show a child the same words the same way.
TextStyle readingProseStyle(
  BuildContext context, {
  required ChildReadingSettings settings,
  required AppLanguage language,
}) {
  final base =
      Theme.of(context).textTheme.bodyLarge ??
      const TextStyle(fontSize: _fallbackProseFontSize);
  return base.copyWith(
    fontSize:
        (base.fontSize ?? _fallbackProseFontSize) * settings.textSize.scale,
    fontFamily: settings.proseFontFamily(language),
  );
}
