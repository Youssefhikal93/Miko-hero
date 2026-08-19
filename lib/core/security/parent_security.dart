import 'dart:convert';

/// Local parent-PIN record format written by this version.
const parentSecurityVersion = 2;

/// Oldest local parent-PIN record format still accepted on read.
const parentSecurityMinimumVersion = 1;

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

/// Consecutive wrong PINs accepted before the first cooldown starts.
const parentPinFreeAttempts = 5;

/// Cooldowns applied from the fifth wrong PIN onward; the last one is the cap.
const parentPinCooldowns = <Duration>[
  Duration(seconds: 30),
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
];

/// Resolves the cooldown earned by [failedAttempts] consecutive wrong PINs.
///
/// Returns null while attempts remain free. Escalates through
/// [parentPinCooldowns] and then stays at its last, capped value.
Duration? parentPinCooldown(int failedAttempts) {
  if (failedAttempts < parentPinFreeAttempts) return null;
  final step = failedAttempts - parentPinFreeAttempts;
  return step >= parentPinCooldowns.length
      ? parentPinCooldowns.last
      : parentPinCooldowns[step];
}

/// Salted, one-way verifier and attempt history stored instead of the PIN.
class ParentSecurityRecord {
  /// Creates a record from encoded values produced by the security service.
  const ParentSecurityRecord({
    required this.saltBase64,
    required this.verifierBase64,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  /// Random Argon2id salt encoded for preferences storage.
  final String saltBase64;

  /// Argon2id output encoded for preferences storage.
  final String verifierBase64;

  /// Consecutive wrong PINs since the last successful unlock.
  final int failedAttempts;

  /// Instant in UTC before which no PIN entry is accepted, if any.
  final DateTime? lockedUntil;

  /// Time left before PIN entry is accepted again, zero when input is open.
  Duration remainingCooldown(DateTime now) {
    final until = lockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(now.toUtc());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Whether PIN entry must be refused right now.
  bool isInCooldown(DateTime now) => remainingCooldown(now) > Duration.zero;

  /// Returns the record after one wrong PIN, applying the escalating cooldown.
  ParentSecurityRecord withFailedAttempt(DateTime now) {
    final attempts = failedAttempts + 1;
    final cooldown = parentPinCooldown(attempts);
    return ParentSecurityRecord(
      saltBase64: saltBase64,
      verifierBase64: verifierBase64,
      failedAttempts: attempts,
      lockedUntil: cooldown == null ? null : now.toUtc().add(cooldown),
    );
  }

  /// Returns the record after a correct PIN clears the attempt history.
  ParentSecurityRecord withoutFailedAttempts() {
    if (failedAttempts == 0 && lockedUntil == null) return this;
    return ParentSecurityRecord(
      saltBase64: saltBase64,
      verifierBase64: verifierBase64,
    );
  }

  /// Converts the verifier and attempt history into versioned storage JSON.
  Map<String, Object> toJson() {
    final until = lockedUntil;
    return <String, Object>{
      'version': parentSecurityVersion,
      'salt': saltBase64,
      'verifier': verifierBase64,
      'failedAttempts': failedAttempts,
      if (until != null) 'lockedUntil': until.toUtc().toIso8601String(),
    };
  }

  /// Validates the version and exact byte lengths of a stored verifier.
  ///
  /// A version-one record decodes unchanged: its absent attempt history counts
  /// as zero failures and no cooldown.
  factory ParentSecurityRecord.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    final salt = json['salt'];
    final verifier = json['verifier'];
    if (version is! int ||
        version < parentSecurityMinimumVersion ||
        version > parentSecurityVersion ||
        salt is! String ||
        verifier is! String) {
      throw const FormatException('Malformed parent security record.');
    }
    if (_decodedLength(salt) != parentSecuritySaltLength ||
        _decodedLength(verifier) != parentSecurityHashLength) {
      throw const FormatException('Malformed parent security bytes.');
    }
    return ParentSecurityRecord(
      saltBase64: salt,
      verifierBase64: verifier,
      failedAttempts: _decodedAttempts(json['failedAttempts']),
      lockedUntil: _decodedLockedUntil(json['lockedUntil']),
    );
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

  /// Time left before PIN entry is accepted again, zero when input is open.
  Duration remainingCooldown(DateTime now) {
    return record?.remainingCooldown(now) ?? Duration.zero;
  }
}

/// Result of one PIN attempt, including why input was refused.
enum ParentUnlockOutcome {
  /// The PIN matched the stored verifier.
  unlocked,

  /// The PIN did not match and further attempts are still accepted.
  incorrectPin,

  /// Too many wrong PINs: entry stays refused until the cooldown ends.
  cooldown,
}

/// Outcome of one PIN attempt plus the cooldown a parent must wait out.
class ParentUnlockResult {
  /// Creates a successful attempt.
  const ParentUnlockResult.unlocked()
    : outcome = ParentUnlockOutcome.unlocked,
      remainingCooldown = Duration.zero;

  /// Creates a wrong-PIN attempt that did not exhaust the free attempts.
  const ParentUnlockResult.incorrectPin()
    : outcome = ParentUnlockOutcome.incorrectPin,
      remainingCooldown = Duration.zero;

  /// Creates a refused attempt with the time left before the next one.
  const ParentUnlockResult.cooldown(this.remainingCooldown)
    : outcome = ParentUnlockOutcome.cooldown;

  /// What happened to the attempt.
  final ParentUnlockOutcome outcome;

  /// Time the parent must wait, zero unless [outcome] is a cooldown.
  final Duration remainingCooldown;

  /// Whether parent controls are now available.
  bool get isUnlocked => outcome == ParentUnlockOutcome.unlocked;
}

/// Treats an absent legacy counter as zero and rejects impossible values.
int _decodedAttempts(Object? encodedAttempts) {
  if (encodedAttempts == null) return 0;
  if (encodedAttempts is! int || encodedAttempts < 0) {
    throw const FormatException('Malformed parent security attempts.');
  }
  return encodedAttempts;
}

/// Accepts an absent cooldown and rejects an unparsable stored timestamp.
DateTime? _decodedLockedUntil(Object? encodedLockedUntil) {
  if (encodedLockedUntil == null) return null;
  if (encodedLockedUntil is! String) {
    throw const FormatException('Malformed parent security cooldown.');
  }
  final lockedUntil = DateTime.tryParse(encodedLockedUntil);
  if (lockedUntil == null) {
    throw const FormatException('Malformed parent security cooldown.');
  }
  return lockedUntil.toUtc();
}

/// Decodes base64 safely and reports invalid storage as a format error.
int _decodedLength(String encodedBytes) {
  try {
    return base64Decode(encodedBytes).length;
  } on FormatException {
    throw const FormatException('Malformed parent security encoding.');
  }
}
