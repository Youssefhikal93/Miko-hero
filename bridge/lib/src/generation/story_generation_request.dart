/// Page counts the app may request, matching `StoryLength` on the device.
const List<int> allowedStoryPageCounts = <int>[6, 8, 10];

/// Youngest reader age accepted by the bridge.
const int minimumStoryAgeYears = 1;

/// Oldest reader age accepted by the bridge.
const int maximumStoryAgeYears = 17;

/// Maximum accepted length of the hero name.
const int maximumHeroNameLength = 60;

/// Maximum accepted length of the theme and the moral.
const int maximumStoryIdeaLength = 300;

/// Maximum accepted length of one saved per-child preference field.
///
/// Matches the app's own `maximumPreferenceTextLength`, so a value the parent
/// was allowed to type can always be sent.
const int maximumPreferenceLength = 240;

/// Parent-confirmed Girl/Boy context that drives prose and later imagery.
///
/// The app's `ChildGender.unspecified` is deliberately not accepted: a story
/// is only generated after the parent has made the choice.
enum StoryGenderContext {
  /// Girl wording.
  girl('girl', 'she', 'her'),

  /// Boy wording.
  boy('boy', 'he', 'his');

  const StoryGenderContext(this.wireName, this.subjectPronoun, this.pronoun);

  /// Value accepted on the wire and stored in requests (`girl` or `boy`).
  final String wireName;

  /// English subject pronoun used when instructing the model.
  final String subjectPronoun;

  /// English possessive pronoun used when instructing the model.
  final String pronoun;

  /// Resolves [value] to a context, or `null` when it is not supported.
  static StoryGenderContext? fromWireName(String value) {
    for (final context in StoryGenderContext.values) {
      if (context.wireName == value) {
        return context;
      }
    }
    return null;
  }
}

/// Languages a story may be written in, matching the app's `AppLanguage`.
enum StoryLanguage {
  /// Arabic (right-to-left).
  arabic('ar', 'Arabic'),

  /// English.
  english('en', 'English'),

  /// Swedish.
  swedish('sv', 'Swedish'),

  /// Somali.
  somali('so', 'Somali');

  const StoryLanguage(this.code, this.englishName);

  /// Two-letter code persisted with the story (`ar`, `en`, `sv`, `so`).
  final String code;

  /// English name of the language, used when instructing the model.
  final String englishName;

  /// Resolves [code] to a language, or `null` when it is not supported.
  static StoryLanguage? fromCode(String code) {
    for (final language in StoryLanguage.values) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }
}

/// Illustration directions understood by the later ComfyUI milestone,
/// matching the app's `IllustrationStyle`.
enum StoryIllustrationStyle {
  /// Gentle, rounded children's picture-book art.
  pictureBook('pictureBook', "gentle rounded children's picture-book art"),

  /// Traditional watercolor texture and color blending.
  watercolor('watercolor', 'soft traditional watercolor with paper texture'),

  /// Bright, dimensional animated-film-inspired art.
  colorful3d('colorful3d', 'bright dimensional animated-film styling');

  const StoryIllustrationStyle(this.wireName, this.englishDirection);

  /// Value accepted on the wire, identical to the app's enum name.
  final String wireName;

  /// Short English art direction handed to the model for scene text.
  final String englishDirection;

  /// Resolves [value] to a style, or `null` when it is not supported.
  static StoryIllustrationStyle? fromWireName(String value) {
    for (final style in StoryIllustrationStyle.values) {
      if (style.wireName == value) {
        return style;
      }
    }
    return null;
  }
}

/// Raised when a submitted generation request fails validation.
///
/// The [message] names the offending field but never repeats its value, so
/// it is safe to return over HTTP.
class StoryRequestValidationException implements Exception {
  /// Creates a validation failure for [field].
  const StoryRequestValidationException(this.field, this.message);

  /// Name of the field that failed validation.
  final String field;

  /// Safe explanation of the constraint that was violated.
  final String message;

  @override
  String toString() => 'StoryRequestValidationException($field)';
}

/// Fully validated inputs for one story generation job.
///
/// This is the bridge-side mirror of the app's `StoryRequest`: same hero
/// identity, Girl/Boy context, theme, moral, language, page count and
/// illustration style.
class StoryGenerationRequest {
  /// Creates a request from already validated values.
  ///
  /// Prefer [StoryGenerationRequest.fromJson] at the HTTP boundary; this
  /// constructor performs no validation of its own.
  const StoryGenerationRequest({
    required this.profileId,
    required this.heroName,
    required this.ageYears,
    required this.gender,
    required this.language,
    required this.theme,
    required this.moral,
    required this.pageCount,
    required this.illustrationStyle,
    this.favoriteTopics = '',
    this.recurringWorld = '',
  });

  /// Stable child identity owning the generated story.
  final String profileId;

  /// Child's name used as the story protagonist.
  final String heroName;

  /// Child's age in whole years, used for age-appropriate wording.
  final int ageYears;

  /// Parent-confirmed Girl/Boy context.
  final StoryGenderContext gender;

  /// Language every page of story text must be written in.
  final StoryLanguage language;

  /// Parent-entered setting or adventure idea.
  final String theme;

  /// Parent-entered lesson woven into the plot.
  final String moral;

  /// Exact number of pages to generate; one of [allowedStoryPageCounts].
  final int pageCount;

  /// Illustration direction carried into the scene descriptions.
  final StoryIllustrationStyle illustrationStyle;

  /// Things the child loves, copied from the saved per-child preferences.
  ///
  /// Optional and empty by default: a device that never sends it — or a family
  /// that filled nothing in — simply gets a story without this context, and
  /// the prompt says nothing about favourites at all.
  final String favoriteTopics;

  /// Named world the family's stories keep returning to, when there is one.
  ///
  /// Optional and empty by default, for the same reason as [favoriteTopics].
  final String recurringWorld;

  /// Validates and parses one `POST /stories/generate` body.
  ///
  /// Throws a [StoryRequestValidationException] naming the first offending
  /// field; nothing is queued until every field is accepted.
  factory StoryGenerationRequest.fromJson(Map<String, Object?> json) {
    final profileId = _requireText(json, 'profileId', maxLength: 64);
    final heroName = _requireText(
      json,
      'heroName',
      maxLength: maximumHeroNameLength,
    );
    final ageYears = _requireInt(
      json,
      'ageYears',
      minimum: minimumStoryAgeYears,
      maximum: maximumStoryAgeYears,
    );
    final genderContext = StoryGenderContext.fromWireName(
      _requireText(json, 'genderContext', maxLength: 20),
    );
    if (genderContext == null) {
      throw const StoryRequestValidationException(
        'genderContext',
        'Field "genderContext" must be "girl" or "boy".',
      );
    }
    final language = StoryLanguage.fromCode(
      _requireText(json, 'languageCode', maxLength: 8),
    );
    if (language == null) {
      throw const StoryRequestValidationException(
        'languageCode',
        'Field "languageCode" must be one of ar, en, sv, so.',
      );
    }
    final theme = _requireText(
      json,
      'theme',
      maxLength: maximumStoryIdeaLength,
    );
    final moral = _requireText(
      json,
      'moral',
      maxLength: maximumStoryIdeaLength,
    );
    final pageCount = _requireInt(json, 'pageCount', minimum: 1, maximum: 100);
    if (!allowedStoryPageCounts.contains(pageCount)) {
      throw const StoryRequestValidationException(
        'pageCount',
        'Field "pageCount" must be 6, 8 or 10.',
      );
    }
    final illustrationStyle = StoryIllustrationStyle.fromWireName(
      _requireText(json, 'illustrationStyle', maxLength: 40),
    );
    if (illustrationStyle == null) {
      throw const StoryRequestValidationException(
        'illustrationStyle',
        'Field "illustrationStyle" must be one of pictureBook, watercolor, '
            'colorful3d.',
      );
    }
    return StoryGenerationRequest(
      profileId: profileId,
      heroName: heroName,
      ageYears: ageYears,
      gender: genderContext,
      language: language,
      theme: theme,
      moral: moral,
      pageCount: pageCount,
      illustrationStyle: illustrationStyle,
      favoriteTopics: _readOptionalText(
        json,
        'favoriteTopics',
        maxLength: maximumPreferenceLength,
      ),
      recurringWorld: _readOptionalText(
        json,
        'recurringWorld',
        maxLength: maximumPreferenceLength,
      ),
    );
  }

  /// Reads one optional preference field, treating absence as "not set".
  ///
  /// Absent, null and blank all mean the same thing — the family filled
  /// nothing in — so none of them is an error. A present value of the wrong
  /// type or over the limit still is.
  static String _readOptionalText(
    Map<String, Object?> json,
    String field, {
    required int maxLength,
  }) {
    final value = json[field];
    if (value == null) {
      return '';
    }
    if (value is! String) {
      throw StoryRequestValidationException(
        field,
        'Field "$field" must be a string when present.',
      );
    }
    final trimmed = value.trim();
    if (trimmed.length > maxLength) {
      throw StoryRequestValidationException(
        field,
        'Field "$field" exceeds the $maxLength character limit.',
      );
    }
    return trimmed;
  }

  static String _requireText(
    Map<String, Object?> json,
    String field, {
    required int maxLength,
  }) {
    final value = json[field];
    if (value is! String || value.trim().isEmpty) {
      throw StoryRequestValidationException(
        field,
        'Field "$field" is required and must be a non-empty string.',
      );
    }
    final trimmed = value.trim();
    if (trimmed.length > maxLength) {
      throw StoryRequestValidationException(
        field,
        'Field "$field" exceeds the $maxLength character limit.',
      );
    }
    return trimmed;
  }

  static int _requireInt(
    Map<String, Object?> json,
    String field, {
    required int minimum,
    required int maximum,
  }) {
    final value = json[field];
    if (value is! int || value < minimum || value > maximum) {
      throw StoryRequestValidationException(
        field,
        'Field "$field" must be an integer between $minimum and $maximum.',
      );
    }
    return value;
  }
}
