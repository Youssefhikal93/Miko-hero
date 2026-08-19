import 'package:miko_hero/core/models/app_language.dart';

/// Maximum parent-authored preference text accepted at storage boundaries.
const maximumPreferenceTextLength = 240;

/// Sensitive themes the parent can exclude from local AI prompts.
enum SafetyTopic {
  /// Avoid frightening scenes, monsters, and intense suspense.
  frighteningContent,

  /// Avoid fighting, weapons, injury, and physical harm.
  violence,

  /// Avoid teasing, exclusion, and bullying story conflicts.
  bullying,

  /// Avoid death, grief, separation, and loss themes.
  griefAndLoss,
}

/// Per-child defaults and prompt boundaries selected by the parent.
class ChildStoryPreferences {
  /// Creates preferences with safe empty context and English as the fallback.
  const ChildStoryPreferences({
    this.defaultLanguage = AppLanguage.english,
    this.favoriteThings = '',
    this.recurringWorld = '',
    this.excludedTopics = const <SafetyTopic>{},
  });

  /// Story language selected initially after choosing this child.
  final AppLanguage defaultLanguage;

  /// Interests local AI may weave naturally into future stories.
  final String favoriteThings;

  /// Named setting or world local AI should reuse across adventures.
  final String recurringWorld;

  /// Themes that future generation prompts must explicitly exclude.
  final Set<SafetyTopic> excludedTopics;

  /// Converts preferences into a JSON-compatible profile field.
  Map<String, Object> toJson() {
    return <String, Object>{
      'defaultLanguage': defaultLanguage.code,
      'favoriteThings': favoriteThings,
      'recurringWorld': recurringWorld,
      'excludedTopics': excludedTopics.map((topic) => topic.name).toList(),
    };
  }

  /// Validates saved text lengths, language, and all safety topic names.
  factory ChildStoryPreferences.fromJson(Map<String, Object?> json) {
    final language = json['defaultLanguage'];
    final favoriteThings = json['favoriteThings'];
    final recurringWorld = json['recurringWorld'];
    final excludedTopics = json['excludedTopics'];
    if (language is! String ||
        favoriteThings is! String ||
        recurringWorld is! String ||
        excludedTopics is! List) {
      throw const FormatException('Malformed child story preferences.');
    }
    final decodedFavorites = _validatedText(favoriteThings);
    final decodedWorld = _validatedText(recurringWorld);
    final decodedTopics = excludedTopics.map(_decodeSafetyTopic).toSet();
    if (decodedTopics.length != excludedTopics.length) {
      throw const FormatException('Duplicate child safety topic.');
    }
    return ChildStoryPreferences(
      defaultLanguage: AppLanguage.requireCode(language),
      favoriteThings: decodedFavorites,
      recurringWorld: decodedWorld,
      excludedTopics: Set<SafetyTopic>.unmodifiable(decodedTopics),
    );
  }
}

/// Trims parent text and rejects payloads too large for prompt context.
String _validatedText(String value) {
  final trimmed = value.trim();
  if (trimmed.length > maximumPreferenceTextLength) {
    throw const FormatException('Child story preference text is too long.');
  }
  return trimmed;
}

/// Resolves one stored enum name and rejects unknown safety controls.
SafetyTopic _decodeSafetyTopic(Object? encodedTopic) {
  if (encodedTopic is! String) {
    throw const FormatException('Malformed child safety topic.');
  }
  try {
    return SafetyTopic.values.byName(encodedTopic);
  } on ArgumentError {
    throw const FormatException('Unsupported child safety topic.');
  }
}
