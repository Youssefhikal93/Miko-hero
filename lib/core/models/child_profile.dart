import 'dart:convert';

/// Largest accepted reference photo after picker-side compression.
const maximumReferencePhotoBytes = 2 * 1024 * 1024;

/// Identity assigned to the profile migrated from the original single-profile schema.
const legacyChildProfileId = 'legacy-child-profile';

/// One child's private profile stored on the current device.
class ChildProfile {
  /// Creates a profile after form-level or storage-boundary validation.
  const ChildProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.photoBase64,
  });

  /// Stable local identity used to associate stories with this child.
  final String id;

  /// Name inserted into generated story text.
  final String name;

  /// Reading-age context constrained by the UI to 1 through 17.
  final int age;

  /// Base64-encoded reference photo kept in local preferences.
  final String photoBase64;

  /// User-facing personalized label requested for profile selection and tabs.
  String get heroName => '$name hero';

  /// Converts the profile into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'id': id,
      'name': name,
      'age': age,
      'photoBase64': photoBase64,
    };
  }

  /// Validates and decodes a profile from the current multi-profile schema.
  factory ChildProfile.fromJson(Map<String, Object?> json) {
    return _validatedProfile(json: json, profileId: json['id']);
  }

  /// Converts the original single-profile payload without discarding its photo.
  factory ChildProfile.fromLegacyJson(Map<String, Object?> json) {
    return _validatedProfile(json: json, profileId: legacyChildProfileId);
  }
}

/// Enforces profile invariants at the local deserialization boundary.
ChildProfile _validatedProfile({
  required Map<String, Object?> json,
  required Object? profileId,
}) {
  final name = json['name'];
  final age = json['age'];
  final photoBase64 = json['photoBase64'];
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
  );
}
