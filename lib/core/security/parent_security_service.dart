import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:miko_hero/core/security/parent_security.dart';

/// Minimum accepted local parent PIN length.
const minimumParentPinLength = 4;

/// Maximum accepted local parent PIN length.
const maximumParentPinLength = 8;

/// Hashes and verifies the optional local parent PIN without retaining it.
class ParentSecurityService {
  /// Creates a service with the versioned Argon2id parameters.
  ParentSecurityService()
    : _argon2id = Argon2id(
        parallelism: parentSecurityParallelism,
        memory: parentSecurityMemory,
        iterations: parentSecurityIterations,
        hashLength: parentSecurityHashLength,
      );

  final Argon2id _argon2id;

  /// Whether a PIN contains only four through eight ASCII digits.
  bool isValidPin(String pin) {
    return RegExp(
      '^[0-9]{$minimumParentPinLength,$maximumParentPinLength}\$',
    ).hasMatch(pin);
  }

  /// Creates a salted one-way verifier for a validated PIN.
  Future<ParentSecurityRecord> createRecord(String pin) async {
    _requireValidPin(pin);
    final salt = randomBytes(parentSecuritySaltLength);
    final verifier = await _deriveVerifier(pin, salt);
    return ParentSecurityRecord(
      saltBase64: base64Encode(salt),
      verifierBase64: base64Encode(verifier),
    );
  }

  /// Compares a PIN against its saved verifier in constant time.
  Future<bool> verify(String pin, ParentSecurityRecord record) async {
    if (!isValidPin(pin)) return false;
    final salt = base64Decode(record.saltBase64);
    final expected = base64Decode(record.verifierBase64);
    final actual = await _deriveVerifier(pin, salt);
    return constantTimeBytesEquality.equals(actual, expected);
  }

  /// Derives the fixed-length verifier used by both setup and unlock.
  Future<List<int>> _deriveVerifier(String pin, List<int> salt) async {
    final key = await _argon2id.deriveKeyFromPassword(
      password: pin,
      nonce: salt,
    );
    return key.extractBytes();
  }

  /// Rejects invalid PINs at the non-UI service boundary.
  void _requireValidPin(String pin) {
    if (!isValidPin(pin)) throw ArgumentError.value(pin, 'pin');
  }
}
