import 'dart:convert';

/// Largest accepted reference photo after picker-side compression.
const maximumReferencePhotoBytes = 2 * 1024 * 1024;

/// Identity assigned to the profile migrated from the original single-profile schema.
const legacyChildProfileId = 'legacy-child-profile';

/// Story and color context chosen by the parent for a child profile.
enum ChildGender {
  /// Migration state for profiles saved before this choice existed.
  unspecified,

  /// Girl story wording with the pink application palette.
  girl,

  /// Boy story wording with the cyan and blue application palette.
  boy;

  /// Whether the parent has completed the required Girl/Boy choice.
  bool get isSpecified => this != unspecified;
}

/// Validated form values used when adding or editing one child profile.
class ChildProfileDraft {
  /// Groups parent-entered values before a stable profile identity is assigned.
  const ChildProfileDraft({
    required this.name,
    required this.age,
    required this.photoBase64,
    required this.gender,
  });

  /// Child name inserted into stories.
  final String name;

  /// Reading age constrained to 1 through 17 by the form.
  final int age;

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
    required this.age,
    required this.photoBase64,
    required this.gender,
  });

  /// Stable local identity used to associate stories with this child.
  final String id;

  /// Name inserted into generated story text.
  final String name;

  /// Reading-age context constrained by the UI to 1 through 17.
  final int age;

  /// Base64-encoded reference photo kept in local preferences.
  final String photoBase64;

  /// Parent-selected story wording and application color context.
  final ChildGender gender;

  /// User-facing personalized label requested for profile selection and tabs.
  String get heroName => '$name hero';

  /// Converts the profile into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'age': age,
      'photoBase64': photoBase64,
      'gender': gender.name,
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
      age: age,
      photoBase64: photoBase64,
      gender: selectedGender,
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
  final photoBase64 = json['photoBase64'];
  final gender = _decodedGender(json['gender'], missingGender: missingGender);
  if (profileId is! String || profileId.trim().isEmpty) {
    throw const FormatException('Malformed child profile identity.');
  }
  if (name is! String || name.trim().isEmpty || age is! int) {
    throw const FormatException('Malformed child profile.');
  }
  if (age < 1 || age > 17 || photoBase64 is! String) {
    throw const FormatException('Malformed child profile.');
  }
  final photoBytes = base64Decode(photoBase64);
  if (photoBytes.isEmpty || photoBytes.length > maximumReferencePhotoBytes) {
    throw const FormatException('Malformed child profile photo.');
  }
  return ChildProfile(
    id: profileId,
    name: name.trim(),
    age: age,
    photoBase64: photoBase64,
    gender: gender,
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
