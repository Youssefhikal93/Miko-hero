import 'package:iam_hero_bridge/src/common/json_reader.dart';

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

/// How a story generation body names its fields and refuses them.
class _StoryRequestFailures extends JsonFieldFailures {
  const _StoryRequestFailures();

  @override
  String describeField(String path) => 'Field "$path"';

  @override
  String describeContainer(String path) =>
      path.isEmpty ? 'The request body' : 'Field "$path"';

  @override
  Object failure(String path, String message) =>
      StoryRequestValidationException(path, message);
}

/// The vocabulary a `POST /stories/generate` body is refused in.
const JsonFieldFailures storyRequestFailures = _StoryRequestFailures();

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
    this.heroNameSpelling = '',
    this.favoriteTopics = '',
    this.recurringWorld = '',
  });

  /// Stable child identity owning the generated story.
  final String profileId;

  /// Child's name as the parent typed it, in whatever script that was.
  final String heroName;

  /// How that name is written in [language], when the family confirmed it.
  ///
  /// Optional and empty by default: a device that never sends it — or a family
  /// that has no spelling saved for this language — gets exactly the behaviour
  /// the bridge had before spellings existed, with [heroName] used as-is.
  ///
  /// Present, it is the only spelling the story may use: the prompts hand the
  /// model this string and forbid any other, and the language check stops
  /// tolerating a Latin name inside Arabic prose (see `checkLanguagePurity`).
  final String heroNameSpelling;

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

  /// The one spelling of the hero's name this story is written with.
  ///
  /// [heroNameSpelling] when the family confirmed one, otherwise [heroName].
  /// Every prompt reads this and nothing else, so there is exactly one answer
  /// to "what is this child called in this book".
  String get storyHeroName =>
      heroNameSpelling.isEmpty ? heroName : heroNameSpelling;

  /// Whether the name is pinned to [language]'s own script by a spelling.
  bool get hasHeroNameSpelling => heroNameSpelling.isNotEmpty;

  /// Validates and parses one `POST /stories/generate` body.
  ///
  /// Throws a [StoryRequestValidationException] naming the first offending
  /// field; nothing is queued until every field is accepted.
  factory StoryGenerationRequest.fromJson(Map<String, Object?> json) {
    // Read in wire order, so a body with more than one problem always names
    // the same field it named before this shared reader existed.
    final reader = JsonReader.root(json, failures: storyRequestFailures);
    final profileId = reader.requireString('profileId', maxLength: 64);
    final heroName = reader.requireString(
      'heroName',
      maxLength: maximumHeroNameLength,
    );
    // Absent, null and blank all mean "no spelling was confirmed for this
    // language", which is the same thing a device that predates spellings
    // says by staying silent.
    final heroNameSpelling = reader.optionalText(
      'heroNameSpelling',
      maxLength: maximumHeroNameLength,
    );
    final ageYears = reader.requireInt(
      'ageYears',
      minimum: minimumStoryAgeYears,
      maximum: maximumStoryAgeYears,
    );
    final gender = reader.namedChoice<StoryGenderContext>(
      'genderContext',
      resolve: StoryGenderContext.fromWireName,
      expected: '"girl" or "boy"',
      maxLength: 20,
    );
    final language = reader.namedChoice<StoryLanguage>(
      'languageCode',
      resolve: StoryLanguage.fromCode,
      expected: 'one of ar, en, sv, so',
      maxLength: 8,
    );
    final theme = reader.requireString(
      'theme',
      maxLength: maximumStoryIdeaLength,
    );
    final moral = reader.requireString(
      'moral',
      maxLength: maximumStoryIdeaLength,
    );
    final pageCount = reader.requireInt('pageCount', minimum: 1, maximum: 100);
    if (!allowedStoryPageCounts.contains(pageCount)) {
      reader.fail('pageCount', 'must be 6, 8 or 10.');
    }
    return StoryGenerationRequest(
      profileId: profileId,
      heroName: heroName,
      heroNameSpelling: heroNameSpelling,
      ageYears: ageYears,
      gender: gender,
      language: language,
      theme: theme,
      moral: moral,
      pageCount: pageCount,
      illustrationStyle: reader.namedChoice<StoryIllustrationStyle>(
        'illustrationStyle',
        resolve: StoryIllustrationStyle.fromWireName,
        expected: 'one of pictureBook, watercolor, colorful3d',
        maxLength: 40,
      ),
      // Absent, null and blank all mean the same thing — the family filled
      // nothing in — so none of them is an error. A present value of the wrong
      // type or over the limit still is.
      favoriteTopics: reader.optionalText(
        'favoriteTopics',
        maxLength: maximumPreferenceLength,
      ),
      recurringWorld: reader.optionalText(
        'recurringWorld',
        maxLength: maximumPreferenceLength,
      ),
    );
  }
}
