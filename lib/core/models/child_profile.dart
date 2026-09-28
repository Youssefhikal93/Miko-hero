import 'dart:convert';

import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';

/// Largest accepted reference photo after picker-side compression.
const maximumReferencePhotoBytes = 2 * 1024 * 1024;

/// Identity assigned to the profile migrated from the original single-profile schema.
const legacyChildProfileId = 'legacy-child-profile';

/// Default golden theme stored for profiles without a Girl/Boy choice.
const goldenProfileThemeColorValue = 0xFFFFB43A;

/// Default rose theme stored for girl profiles created before customization.
const roseProfileThemeColorValue = 0xFFFF5CA8;

/// Default cyan theme stored for boy profiles created before customization.
const cyanProfileThemeColorValue = 0xFF31D7E8;

/// Youngest reading age a child profile may describe.
const minimumChildAge = 1;

/// Oldest reading age a child profile may describe.
const maximumChildAge = 17;

/// Age used to position the birth-date picker for a brand new profile.
const defaultChildProfileAgeYears = 6;

/// Longest accepted spelling of a child's name in one language.
///
/// The same bound the bridge puts on a hero name, so a spelling the parent was
/// allowed to type can always be sent with a story request.
const maximumChildNameSpellingLength = 60;

/// Drops the time component so birth dates compare as plain calendar days.
DateTime childCalendarDay(DateTime moment) {
  return DateTime(moment.year, moment.month, moment.day);
}

/// Computes the age in whole years on [today], counting the birthday itself.
///
/// The day before a birthday still reports the previous age; the birthday
/// itself reports the new one.
int childAgeOn(DateTime birthDate, DateTime today) {
  final birth = childCalendarDay(birthDate);
  final day = childCalendarDay(today);
  final hadBirthday =
      day.month > birth.month ||
      (day.month == birth.month && day.day >= birth.day);
  return day.year - birth.year - (hadBirthday ? 0 : 1);
}

/// Whether a computed age stays inside the supported child reading range.
bool isValidChildAge(int age) {
  return age >= minimumChildAge && age <= maximumChildAge;
}

/// Encodes a birth date as the stored ISO `yyyy-MM-dd` calendar day.
String formatChildBirthDate(DateTime birthDate) {
  final day = childCalendarDay(birthDate);
  final month = day.month.toString().padLeft(2, '0');
  final dayOfMonth = day.day.toString().padLeft(2, '0');
  return '${day.year.toString().padLeft(4, '0')}-$month-$dayOfMonth';
}

/// Story and color context chosen by the parent for a child profile.
enum ChildGender {
  /// Migration state for profiles saved before this choice existed.
  unspecified,

  /// Girl story wording with rose as the initial application palette.
  girl,

  /// Boy story wording with cyan as the initial application palette.
  boy;

  /// Whether the parent has completed the required Girl/Boy choice.
  bool get isSpecified => this != unspecified;
}

/// Resolves the initial opaque ARGB theme for a newly created or migrated profile.
int defaultProfileThemeColorValue(ChildGender gender) {
  return switch (gender) {
    ChildGender.unspecified => goldenProfileThemeColorValue,
    ChildGender.girl => roseProfileThemeColorValue,
    ChildGender.boy => cyanProfileThemeColorValue,
  };
}

/// Accepts only opaque 32-bit ARGB colors at storage and controller boundaries.
bool isValidProfileThemeColorValue(int colorValue) {
  return colorValue >= 0 &&
      colorValue <= 0xFFFFFFFF &&
      (colorValue & 0xFF000000) == 0xFF000000;
}

/// Validated form values used when adding or editing one child profile.
class ChildProfileDraft {
  /// Groups parent-entered values before a stable profile identity is assigned.
  const ChildProfileDraft({
    required this.name,
    required this.birthDate,
    required this.photoBase64,
    required this.gender,
    this.nameSpellings = const <AppLanguage, String>{},
  });

  /// Child name inserted into stories.
  final String name;

  /// How that name is written in each story language the parent confirmed.
  ///
  /// A language the parent left empty is simply absent, which means "use the
  /// name as it was typed" everywhere that language is read or written.
  final Map<AppLanguage, String> nameSpellings;

  /// Chosen calendar birth date, required for a new profile.
  ///
  /// Null keeps the stored legacy age of an existing profile that was saved
  /// before birth dates existed, so editing a name never forces re-entry.
  final DateTime? birthDate;

  /// Private reference photo encoded for local persistence.
  final String photoBase64;

  /// Parent-confirmed story wording and color context.
  final ChildGender gender;
}

/// One child's private profile stored on the current device.
class ChildProfile {
  /// Creates a profile after form-level or storage-boundary validation.
  const ChildProfile({
    required this.id,
    required this.name,
    required this.legacyAge,
    required this.photoBase64,
    required this.gender,
    required this.themeColorValue,
    required this.hasCustomThemeColor,
    this.birthDate,
    this.nameSpellings = const <AppLanguage, String>{},
    this.storyPreferences = const ChildStoryPreferences(),
    this.kingdomTheme = const KingdomTheme(),
    this.readingSettings = const ChildReadingSettings(),
    this.finishedStoryIds = const <String>[],
  });

  /// Stable local identity used to associate stories with this child.
  final String id;

  /// Name as the parent typed it, in whatever script that was.
  ///
  /// Never render this directly on a localized surface and never send it to
  /// the PC on its own: use [nameIn] and [heroNameIn], which answer with the
  /// spelling the language being read actually uses.
  final String name;

  /// How [name] is written in each language the parent confirmed a spelling
  /// for; a language that is absent uses [name] itself.
  ///
  /// This is what makes Malika appear as مليكة all through an Arabic story and
  /// in the Arabic interface, and stay Malika in English, Swedish and Somali.
  /// Empty on every profile saved before spellings existed, which reads exactly
  /// as it always did.
  final Map<AppLanguage, String> nameSpellings;

  /// Age snapshot kept only as a fallback for profiles saved without a date.
  ///
  /// Never read it directly for display: it stops ageing once written. Use
  /// [age] or [ageOn] so a stored [birthDate] always wins.
  final int legacyAge;

  /// Calendar birth date chosen by the parent, absent on legacy profiles.
  ///
  /// Always a plain calendar day; use [childCalendarDay] before constructing a
  /// profile from a picker or another time-carrying value.
  final DateTime? birthDate;

  /// Base64-encoded reference photo kept in local preferences.
  final String photoBase64;

  /// Parent-selected story wording and application color context.
  final ChildGender gender;

  /// Opaque ARGB color saved separately for this child's application theme.
  final int themeColorValue;

  /// Whether the parent deliberately replaced the profile's initial palette.
  final bool hasCustomThemeColor;

  /// Parent-selected language, inspiration, world, and safety defaults.
  final ChildStoryPreferences storyPreferences;

  /// Castle, photo frame, backdrop, and symbol chosen for this child's kingdom.
  final KingdomTheme kingdomTheme;

  /// Prose size and easy-reading font chosen for this child's reading.
  final ChildReadingSettings readingSettings;

  /// Identities of the distinct stories this child has read to the last page.
  ///
  /// Local reading rewards are derived from this set, so re-reading a story
  /// never counts twice and a deleted story stops counting on this device.
  final List<String> finishedStoryIds;

  /// User-facing personalized label requested for profile selection and tabs.
  ///
  /// Written with the name as the parent typed it. Prefer [heroNameIn] on any
  /// surface that knows which language it is being read in.
  String get heroName => '$name hero';

  /// The child's name as [language] writes it, or [name] when none was saved.
  String nameIn(AppLanguage language) => nameSpellings[language] ?? name;

  /// The personalized hero label written in [language]'s own spelling.
  String heroNameIn(AppLanguage language) => '${nameIn(language)} hero';

  /// Number of distinct finished stories used by the local reading badges.
  int get finishedStoryCount => finishedStoryIds.length;

  /// Age in whole years on [today], derived from [birthDate] when it exists.
  int ageOn(DateTime today) {
    final birth = birthDate;
    return birth == null ? legacyAge : childAgeOn(birth, today);
  }

  /// Age shown to the parent today; the only age any surface should display.
  int get age => ageOn(DateTime.now());

  /// Converts the profile into a JSON-compatible local storage object.
  ///
  /// Keeps writing the legacy `age` snapshot so a profile saved by this
  /// version still decodes in an app build that predates birth dates.
  Map<String, Object> toJson() {
    final birth = birthDate;
    return <String, Object>{
      'id': id,
      'name': name,
      'age': legacyAge,
      // Written only when the family confirmed one, so a profile with no
      // spellings encodes byte for byte the way it always has.
      if (nameSpellings.isNotEmpty)
        'nameSpellings': <String, Object>{
          for (final entry in nameSpellings.entries)
            entry.key.code: entry.value,
        },
      if (birth != null) 'birthDate': formatChildBirthDate(birth),
      'photoBase64': photoBase64,
      'gender': gender.name,
      'themeColorValue': themeColorValue,
      'hasCustomThemeColor': hasCustomThemeColor,
      'storyPreferences': storyPreferences.toJson(),
      'kingdomTheme': kingdomTheme.toJson(),
      'readingSettings': readingSettings.toJson(),
      'finishedStoryIds': finishedStoryIds,
    };
  }

  /// Validates and decodes a profile from the current multi-profile schema.
  factory ChildProfile.fromJson(Map<String, Object?> json) {
    return _validatedProfile(
      json: json,
      profileId: json['id'],
      missingGender: ChildGender.unspecified,
    );
  }

  /// Converts the original single-profile payload without discarding its photo.
  factory ChildProfile.fromLegacyJson(Map<String, Object?> json) {
    return _validatedProfile(
      json: json,
      profileId: legacyChildProfileId,
      missingGender: ChildGender.girl,
    );
  }

  /// Returns the same profile after the parent confirms Girl or Boy.
  ChildProfile withGender(ChildGender selectedGender) {
    return _copy(
      gender: selectedGender,
      themeColorValue: hasCustomThemeColor
          ? themeColorValue
          : defaultProfileThemeColorValue(selectedGender),
    );
  }

  /// Returns the same identity after validating a parent-selected opaque color.
  ChildProfile withThemeColor(int selectedColorValue) {
    if (!isValidProfileThemeColorValue(selectedColorValue)) {
      throw ArgumentError.value(selectedColorValue, 'selectedColorValue');
    }
    return _copy(
      themeColorValue: selectedColorValue,
      hasCustomThemeColor: true,
    );
  }

  /// Returns the same identity with newly confirmed name spellings.
  ///
  /// A blank entry is dropped rather than stored: a language the parent
  /// cleared is a language with no spelling, not one spelled with nothing.
  ChildProfile withNameSpellings(Map<AppLanguage, String> spellings) {
    return _copy(nameSpellings: validChildNameSpellings(spellings));
  }

  /// Returns the same identity with newly confirmed story preferences.
  ChildProfile withStoryPreferences(ChildStoryPreferences preferences) {
    return _copy(storyPreferences: preferences);
  }

  /// Returns the same identity with newly confirmed kingdom decoration.
  ChildProfile withKingdomTheme(KingdomTheme theme) {
    return _copy(kingdomTheme: theme);
  }

  /// Returns the same identity with newly confirmed reading comfort.
  ChildProfile withReadingSettings(ChildReadingSettings settings) {
    return _copy(readingSettings: settings);
  }

  /// Returns the same identity after [storyId] is counted as finished.
  ///
  /// Reading a story again changes nothing, so badges count distinct books.
  ChildProfile withFinishedStory(String storyId) {
    if (storyId.trim().isEmpty) throw ArgumentError.value(storyId, 'storyId');
    if (finishedStoryIds.contains(storyId)) return this;
    return _copy(
      finishedStoryIds: List<String>.unmodifiable(<String>[
        ...finishedStoryIds,
        storyId,
      ]),
    );
  }

  /// Returns the same identity after a story no longer exists on this device.
  ChildProfile withoutFinishedStory(String storyId) {
    if (!finishedStoryIds.contains(storyId)) return this;
    return _copy(
      finishedStoryIds: List<String>.unmodifiable(
        finishedStoryIds.where((identity) => identity != storyId),
      ),
    );
  }

  /// Copies one profile while keeping every field this build persists.
  ///
  /// Centralized so a newly stored field can never be dropped by a
  /// single-purpose transformation such as [withThemeColor].
  ChildProfile _copy({
    ChildGender? gender,
    int? themeColorValue,
    bool? hasCustomThemeColor,
    Map<AppLanguage, String>? nameSpellings,
    ChildStoryPreferences? storyPreferences,
    KingdomTheme? kingdomTheme,
    ChildReadingSettings? readingSettings,
    List<String>? finishedStoryIds,
  }) {
    return ChildProfile(
      id: id,
      name: name,
      legacyAge: legacyAge,
      birthDate: birthDate,
      nameSpellings: nameSpellings ?? this.nameSpellings,
      photoBase64: photoBase64,
      gender: gender ?? this.gender,
      themeColorValue: themeColorValue ?? this.themeColorValue,
      hasCustomThemeColor: hasCustomThemeColor ?? this.hasCustomThemeColor,
      storyPreferences: storyPreferences ?? this.storyPreferences,
      kingdomTheme: kingdomTheme ?? this.kingdomTheme,
      readingSettings: readingSettings ?? this.readingSettings,
      finishedStoryIds: finishedStoryIds ?? this.finishedStoryIds,
    );
  }
}

/// Enforces profile invariants at the local deserialization boundary.
ChildProfile _validatedProfile({
  required Map<String, Object?> json,
  required Object? profileId,
  required ChildGender missingGender,
}) {
  final name = json['name'];
  final age = json['age'];
  final nameSpellings = _decodedNameSpellings(json['nameSpellings']);
  final birthDate = _decodedBirthDate(json['birthDate']);
  final photoBase64 = json['photoBase64'];
  final gender = _decodedGender(json['gender'], missingGender: missingGender);
  final theme = _decodedTheme(
    json['themeColorValue'],
    json['hasCustomThemeColor'],
    gender,
  );
  final storyPreferences = _decodedStoryPreferences(json['storyPreferences']);
  final kingdomTheme = _decodedKingdomTheme(json['kingdomTheme']);
  final readingSettings = _decodedReadingSettings(json['readingSettings']);
  final finishedStoryIds = _decodedFinishedStoryIds(json['finishedStoryIds']);
  if (profileId is! String || profileId.trim().isEmpty) {
    throw const FormatException('Malformed child profile identity.');
  }
  if (name is! String || name.trim().isEmpty || age is! int) {
    throw const FormatException('Malformed child profile.');
  }
  if (!isValidChildAge(age) || photoBase64 is! String) {
    throw const FormatException('Malformed child profile.');
  }
  final photoBytes = base64Decode(photoBase64);
  if (photoBytes.isEmpty || photoBytes.length > maximumReferencePhotoBytes) {
    throw const FormatException('Malformed child profile photo.');
  }
  return ChildProfile(
    id: profileId,
    name: name.trim(),
    legacyAge: age,
    birthDate: birthDate,
    nameSpellings: nameSpellings,
    photoBase64: photoBase64,
    gender: gender,
    themeColorValue: theme.colorValue,
    hasCustomThemeColor: theme.isCustom,
    storyPreferences: storyPreferences,
    kingdomTheme: kingdomTheme,
    readingSettings: readingSettings,
    finishedStoryIds: finishedStoryIds,
  );
}

/// Keeps only the spellings a parent actually filled in, trimmed and bounded.
///
/// Shared by the model's own transformation and by the profile editor, so the
/// rule about what counts as "no spelling for this language" is written once:
/// a blank box is an absent language, never a stored empty string.
Map<AppLanguage, String> validChildNameSpellings(
  Map<AppLanguage, String> spellings,
) {
  final kept = <AppLanguage, String>{};
  for (final entry in spellings.entries) {
    final spelling = entry.value.trim();
    if (spelling.isEmpty) continue;
    if (spelling.length > maximumChildNameSpellingLength) {
      throw const FormatException('Malformed child name spelling.');
    }
    kept[entry.key] = spelling;
  }
  return Map<AppLanguage, String>.unmodifiable(kept);
}

/// Defaults profiles saved before spellings existed and validates the rest.
///
/// A stored key that is not a supported language, or a value that is not a
/// usable name, is refused rather than dropped: a spelling nobody reads is a
/// child's name the family believes is in effect.
Map<AppLanguage, String> _decodedNameSpellings(Object? encodedSpellings) {
  if (encodedSpellings == null) return const <AppLanguage, String>{};
  if (encodedSpellings is! Map<String, Object?>) {
    throw const FormatException('Malformed child name spellings.');
  }
  final spellings = <AppLanguage, String>{};
  for (final entry in encodedSpellings.entries) {
    final spelling = entry.value;
    if (spelling is! String || spelling.trim().isEmpty) {
      throw const FormatException('Malformed child name spelling.');
    }
    spellings[AppLanguage.requireCode(entry.key)] = spelling;
  }
  return validChildNameSpellings(spellings);
}

/// Defaults profiles saved before reading comfort existed and validates the rest.
ChildReadingSettings _decodedReadingSettings(Object? encodedSettings) {
  if (encodedSettings == null) return const ChildReadingSettings();
  if (encodedSettings is! Map<String, Object?>) {
    throw const FormatException('Malformed child reading settings.');
  }
  return ChildReadingSettings.fromJson(encodedSettings);
}

/// Accepts an absent reward history and rejects unusable stored identities.
List<String> _decodedFinishedStoryIds(Object? encodedIdentities) {
  if (encodedIdentities == null) return const <String>[];
  if (encodedIdentities is! List) {
    throw const FormatException('Malformed finished story identities.');
  }
  final identities = <String>[];
  for (final value in encodedIdentities) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Malformed finished story identity.');
    }
    if (!identities.contains(value)) identities.add(value);
  }
  return List<String>.unmodifiable(identities);
}

/// Defaults profiles saved before personalization and validates current ones.
KingdomTheme _decodedKingdomTheme(Object? encodedTheme) {
  if (encodedTheme == null) return const KingdomTheme();
  if (encodedTheme is! Map<String, Object?>) {
    throw const FormatException('Malformed child kingdom theme.');
  }
  return KingdomTheme.fromJson(encodedTheme);
}

/// Accepts a missing legacy birth date but rejects unusable stored dates.
///
/// A stored date must be a real `yyyy-MM-dd` calendar day that is neither in
/// the future nor younger than [minimumChildAge]. The upper age bound is
/// deliberately enforced only where a profile is written, so a family's stored
/// profile never becomes unreadable on the day a child outgrows the range.
DateTime? _decodedBirthDate(Object? encodedBirthDate) {
  if (encodedBirthDate == null) return null;
  if (encodedBirthDate is! String) {
    throw const FormatException('Malformed child birth date.');
  }
  final birthDate = _parsedBirthDate(encodedBirthDate);
  final today = childCalendarDay(DateTime.now());
  if (birthDate.isAfter(today)) {
    throw const FormatException('Child birth date is in the future.');
  }
  if (childAgeOn(birthDate, today) < minimumChildAge) {
    throw const FormatException('Child birth date is too recent.');
  }
  return birthDate;
}

/// Requires the exact stored date format and rejects impossible calendar days.
DateTime _parsedBirthDate(String encodedBirthDate) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(encodedBirthDate);
  if (match == null) {
    throw const FormatException('Malformed child birth date.');
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final birthDate = DateTime(year, month, day);
  if (birthDate.year != year ||
      birthDate.month != month ||
      birthDate.day != day) {
    throw const FormatException('Malformed child birth date.');
  }
  return birthDate;
}

/// Defaults older profiles and validates current preference objects.
ChildStoryPreferences _decodedStoryPreferences(Object? encodedPreferences) {
  if (encodedPreferences == null) return const ChildStoryPreferences();
  if (encodedPreferences is! Map<String, Object?>) {
    throw const FormatException('Malformed child story preferences.');
  }
  return ChildStoryPreferences.fromJson(encodedPreferences);
}

/// Distinguishes migrated defaults from colors deliberately chosen by a parent.
({int colorValue, bool isCustom}) _decodedTheme(
  Object? encodedColor,
  Object? encodedCustomization,
  ChildGender gender,
) {
  if (encodedColor == null) {
    if (encodedCustomization != null) {
      throw const FormatException('Malformed child profile theme state.');
    }
    return (colorValue: defaultProfileThemeColorValue(gender), isCustom: false);
  }
  if (encodedColor is! int || !isValidProfileThemeColorValue(encodedColor)) {
    throw const FormatException('Malformed child profile theme color.');
  }
  if (encodedCustomization != null && encodedCustomization is! bool) {
    throw const FormatException('Malformed child profile theme state.');
  }
  return (
    colorValue: encodedColor,
    isCustom: encodedCustomization as bool? ?? true,
  );
}

/// Accepts a missing legacy choice but rejects unknown stored gender values.
ChildGender _decodedGender(
  Object? encodedGender, {
  required ChildGender missingGender,
}) {
  if (encodedGender == null) return missingGender;
  if (encodedGender is! String) {
    throw const FormatException('Malformed child profile gender.');
  }
  try {
    return ChildGender.values.byName(encodedGender);
  } on ArgumentError {
    throw const FormatException('Unsupported child profile gender.');
  }
}
