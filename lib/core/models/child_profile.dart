import 'dart:convert';

import 'package:miko_hero/core/models/child_story_preferences.dart';

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
  });

  /// Child name inserted into stories.
  final String name;

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
    this.storyPreferences = const ChildStoryPreferences(),
  });

  /// Stable local identity used to associate stories with this child.
  final String id;

  /// Name inserted into generated story text.
  final String name;

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

  /// User-facing personalized label requested for profile selection and tabs.
  String get heroName => '$name hero';

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
      if (birth != null) 'birthDate': formatChildBirthDate(birth),
      'photoBase64': photoBase64,
      'gender': gender.name,
      'themeColorValue': themeColorValue,
      'hasCustomThemeColor': hasCustomThemeColor,
      'storyPreferences': storyPreferences.toJson(),
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
    return ChildProfile(
      id: id,
      name: name,
      legacyAge: legacyAge,
      birthDate: birthDate,
      photoBase64: photoBase64,
      gender: selectedGender,
      themeColorValue: hasCustomThemeColor
          ? themeColorValue
          : defaultProfileThemeColorValue(selectedGender),
      hasCustomThemeColor: hasCustomThemeColor,
      storyPreferences: storyPreferences,
    );
  }

  /// Returns the same identity after validating a parent-selected opaque color.
  ChildProfile withThemeColor(int selectedColorValue) {
    if (!isValidProfileThemeColorValue(selectedColorValue)) {
      throw ArgumentError.value(selectedColorValue, 'selectedColorValue');
    }
    return ChildProfile(
      id: id,
      name: name,
      legacyAge: legacyAge,
      birthDate: birthDate,
      photoBase64: photoBase64,
      gender: gender,
      themeColorValue: selectedColorValue,
      hasCustomThemeColor: true,
      storyPreferences: storyPreferences,
    );
  }

  /// Returns the same identity with newly confirmed story preferences.
  ChildProfile withStoryPreferences(ChildStoryPreferences preferences) {
    return ChildProfile(
      id: id,
      name: name,
      legacyAge: legacyAge,
      birthDate: birthDate,
      photoBase64: photoBase64,
      gender: gender,
      themeColorValue: themeColorValue,
      hasCustomThemeColor: hasCustomThemeColor,
      storyPreferences: preferences,
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
  final birthDate = _decodedBirthDate(json['birthDate']);
  final photoBase64 = json['photoBase64'];
  final gender = _decodedGender(json['gender'], missingGender: missingGender);
  final theme = _decodedTheme(
    json['themeColorValue'],
    json['hasCustomThemeColor'],
    gender,
  );
  final storyPreferences = _decodedStoryPreferences(json['storyPreferences']);
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
    photoBase64: photoBase64,
    gender: gender,
    themeColorValue: theme.colorValue,
    hasCustomThemeColor: theme.isCustom,
    storyPreferences: storyPreferences,
  );
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
