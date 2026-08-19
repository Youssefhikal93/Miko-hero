import 'dart:convert';

/// Current local parent-PIN record format.
const parentSecurityVersion = 1;

/// Memory blocks used by Argon2id for local PIN verification.
const parentSecurityMemory = 19 * 1024;

/// Passes used by Argon2id for local PIN verification.
const parentSecurityIterations = 2;

/// Parallel lanes used by Argon2id for local PIN verification.
const parentSecurityParallelism = 1;

/// Derived verifier size in bytes.
const parentSecurityHashLength = 32;

/// Random salt size in bytes.
const parentSecuritySaltLength = 16;

/// Salted, one-way verifier stored instead of the parent's PIN.
class ParentSecurityRecord {
  /// Creates a record from encoded values produced by the security service.
  const ParentSecurityRecord({
    required this.saltBase64,
    required this.verifierBase64,
  });

  /// Random Argon2id salt encoded for preferences storage.
  final String saltBase64;

  /// Argon2id output encoded for preferences storage.
  final String verifierBase64;

  /// Converts the verifier into a versioned JSON storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'version': parentSecurityVersion,
      'salt': saltBase64,
      'verifier': verifierBase64,
    };
  }

  /// Validates the version and exact byte lengths of a stored verifier.
  factory ParentSecurityRecord.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final salt = json['salt'];
    final verifier = json['verifier'];
    if (version != parentSecurityVersion ||
        salt is! String ||
        verifier is! String) {
      throw const FormatException('Malformed parent security record.');
    }
    if (_decodedLength(salt) != parentSecuritySaltLength ||
        _decodedLength(verifier) != parentSecurityHashLength) {
      throw const FormatException('Malformed parent security bytes.');
    }
    return ParentSecurityRecord(saltBase64: salt, verifierBase64: verifier);
  }
}

/// Current in-memory access state for parent-only controls.
class ParentAccessState {
  /// Creates a state from persisted setup and this app session's unlock flag.
  const ParentAccessState({required this.record, required this.isUnlocked});

  /// Persisted verifier, or null when the optional PIN is disabled.
  final ParentSecurityRecord? record;

  /// Whether parent-only controls are available in this app session.
  final bool isUnlocked;

  /// Whether a local parent PIN has been configured.
  bool get isConfigured => record != null;
}

/// Decodes base64 safely and reports invalid storage as a format error.
int _decodedLength(String encodedBytes) {
  try {
    return base64Decode(encodedBytes).length;
  } on FormatException {
    throw const FormatException('Malformed parent security encoding.');
  }
}
