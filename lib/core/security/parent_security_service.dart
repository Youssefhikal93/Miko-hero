import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/security/parent_security.dart';

/// Minimum accepted local parent PIN length.
const minimumParentPinLength = 4;

/// Maximum accepted local parent PIN length.
const maximumParentPinLength = 8;

/// One Argon2id job sent to a background isolate.
class ParentPinDerivation {
  /// Groups the PIN and its salt into one message the isolate can receive.
  const ParentPinDerivation({required this.pin, required this.salt});

  /// PIN entered by the parent; never stored anywhere.
  final String pin;

  /// Salt saved with the verifier record.
  final Uint8List salt;
}

/// Runs one Argon2id derivation, by default on a background isolate.
typedef ParentPinDeriver =
    Future<Uint8List> Function(ParentPinDerivation derivation);

/// Derives the fixed-length parent-PIN verifier.
///
/// Top-level so it can be the entry point of a background isolate. Tests may
/// pass it directly to [ParentSecurityService] to skip the isolate hop.
Future<Uint8List> deriveParentPinVerifier(
  ParentPinDerivation derivation,
) async {
  final argon2id = Argon2id(
    parallelism: parentSecurityParallelism,
    memory: parentSecurityMemory,
    iterations: parentSecurityIterations,
    hashLength: parentSecurityHashLength,
  );
  final key = await argon2id.deriveKeyFromPassword(
    password: derivation.pin,
    nonce: derivation.salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}

/// Hashes and verifies the optional local parent PIN without retaining it.
class ParentSecurityService {
  /// Creates a service that derives verifiers off the UI thread.
  ///
  /// [deriver] exists so tests can substitute the isolate boundary; production
  /// code keeps the default `compute` hop, which runs inline on Flutter web
  /// because that platform has no isolates.
  ParentSecurityService({ParentPinDeriver? deriver})
    : _derive = deriver ?? _computeParentPinVerifier;

  final ParentPinDeriver _derive;

  /// Whether a PIN contains only four through eight ASCII digits.
  bool isValidPin(String pin) {
    return RegExp(
      '^[0-9]{$minimumParentPinLength,$maximumParentPinLength}\$',
    ).hasMatch(pin);
  }

  /// Creates a salted one-way verifier for a validated PIN.
  Future<ParentSecurityRecord> createRecord(String pin) async {
    _requireValidPin(pin);
    final salt = Uint8List.fromList(randomBytes(parentSecuritySaltLength));
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
  Future<Uint8List> _deriveVerifier(String pin, Uint8List salt) {
    return _derive(ParentPinDerivation(pin: pin, salt: salt));
  }

  /// Rejects invalid PINs at the non-UI service boundary.
  ///
  /// The error deliberately never carries the entered value: a mistyped PIN is
  /// usually one character away from the real one and must not reach logs.
  void _requireValidPin(String pin) {
    if (!isValidPin(pin)) {
      throw ArgumentError(
        'PIN must be $minimumParentPinLength-$maximumParentPinLength digits.',
      );
    }
  }
}

/// Moves the Argon2id work off the UI thread so unlocking never freezes it.
Future<Uint8List> _computeParentPinVerifier(ParentPinDerivation derivation) {
  return compute(deriveParentPinVerifier, derivation);
}
