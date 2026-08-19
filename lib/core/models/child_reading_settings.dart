import 'package:miko_hero/core/models/app_language.dart';

/// Bundled font family offered as the optional easy-reading typeface.
///
/// Declared in `pubspec.yaml` from `assets/fonts/AtkinsonHyperlegible-Regular.ttf`,
/// which is licensed under the SIL Open Font License.
const easyReadingFontFamily = 'AtkinsonHyperlegible';

/// Reader prose sizes a parent can pick for one child.
///
/// Each step multiplies the theme's body size instead of hard-coding pixels, so
/// the reader keeps following the shared typography scale.
enum ReaderTextSize {
  /// Slightly smaller prose for a child who prefers more text per page.
  small(0.85),

  /// The default prose size used before a parent changes anything.
  medium(1),

  /// Larger prose for early readers.
  large(1.2),

  /// Largest prose step offered, for the youngest or low-vision readers.
  extraLarge(1.45);

  /// Associates one choice with its multiplier on the theme body size.
  const ReaderTextSize(this.scale);

  /// Factor applied to the theme's body font size when rendering prose.
  final double scale;
}

/// Per-child reading comfort applied when story prose is displayed.
///
/// Kept separate from `ChildStoryPreferences` deliberately: those preferences
/// describe what a story should be about and are copied into every generated
/// story's prompt, while these settings only describe how existing prose is
/// rendered for one child and must never reach a generator.
class ChildReadingSettings {
  /// Creates settings with the default medium size and the theme font.
  const ChildReadingSettings({
    this.textSize = ReaderTextSize.medium,
    this.easyReadingFont = false,
  });

  /// Prose size used by the reader and the parent review preview.
  final ReaderTextSize textSize;

  /// Whether Latin-script prose uses the bundled easy-reading typeface.
  final bool easyReadingFont;

  /// Converts the settings into a JSON-compatible profile field.
  Map<String, Object> toJson() {
    return <String, Object>{
      'textSize': textSize.name,
      'easyReadingFont': easyReadingFont,
    };
  }

  /// Validates stored reading comfort and defaults every absent field.
  ///
  /// An unknown stored size is refused with a [FormatException] rather than
  /// silently replaced, the same way kingdom decoration names are handled.
  factory ChildReadingSettings.fromJson(Map<String, Object?> json) {
    final easyReadingFont = json['easyReadingFont'];
    if (easyReadingFont != null && easyReadingFont is! bool) {
      throw const FormatException('Malformed child reading settings.');
    }
    return ChildReadingSettings(
      textSize: _decodedTextSize(json['textSize']),
      easyReadingFont: easyReadingFont as bool? ?? false,
    );
  }

  /// Returns the same settings with a newly chosen prose size.
  ChildReadingSettings withTextSize(ReaderTextSize size) {
    return ChildReadingSettings(
      textSize: size,
      easyReadingFont: easyReadingFont,
    );
  }

  /// Returns the same settings after the easy-reading font is switched.
  ChildReadingSettings withEasyReadingFont(bool enabled) {
    return ChildReadingSettings(textSize: textSize, easyReadingFont: enabled);
  }

  /// Font family for prose in [language], or null to keep the theme font.
  ///
  /// Arabic prose always keeps the theme font because the bundled
  /// easy-reading face has no Arabic script.
  String? proseFontFamily(AppLanguage language) {
    return easyReadingFont && language.usesLatinScript
        ? easyReadingFontFamily
        : null;
  }
}

/// Resolves one stored size name and rejects sizes this build cannot render.
ReaderTextSize _decodedTextSize(Object? encodedSize) {
  if (encodedSize == null) return ReaderTextSize.medium;
  if (encodedSize is! String) {
    throw const FormatException('Malformed reader text size.');
  }
  try {
    return ReaderTextSize.values.byName(encodedSize);
  } on ArgumentError {
    throw const FormatException('Unsupported reader text size.');
  }
}
