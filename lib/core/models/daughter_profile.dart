import 'dart:convert';

/// Largest accepted reference photo after picker-side compression.
const maximumReferencePhotoBytes = 2 * 1024 * 1024;

/// The single child's private profile stored on the current device.
class DaughterProfile {
  /// Creates a validated profile after form-level checks have succeeded.
  const DaughterProfile({
    required this.name,
    required this.age,
    required this.photoBase64,
  });

  /// Name inserted into generated story text.
  final String name;

  /// Reading-age context constrained by the UI to 1 through 17.
  final int age;

  /// Base64-encoded reference photo kept in local preferences.
  final String photoBase64;

  /// Converts the profile into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'name': name,
      'age': age,
      'photoBase64': photoBase64,
    };
  }

  /// Validates and decodes profile input read from local storage.
  factory DaughterProfile.fromJson(Map<String, Object?> json) {
    final name = json['name'];
    final age = json['age'];
    final photoBase64 = json['photoBase64'];
    if (name is! String || name.trim().isEmpty || age is! int) {
      throw const FormatException('Malformed daughter profile.');
    }
    if (age < 1 || age > 17 || photoBase64 is! String) {
      throw const FormatException('Malformed daughter profile.');
    }
    final photoBytes = base64Decode(photoBase64);
    if (photoBytes.isEmpty || photoBytes.length > maximumReferencePhotoBytes) {
      throw const FormatException('Malformed daughter profile photo.');
    }
    return DaughterProfile(name: name, age: age, photoBase64: photoBase64);
  }
}
