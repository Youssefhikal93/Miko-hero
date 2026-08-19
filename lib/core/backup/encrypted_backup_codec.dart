import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/models/app_state.dart';

/// Maximum encrypted backup size accepted before parsing or decryption.
const maximumBackupBytes = 64 * 1024 * 1024;

/// Minimum password length required when creating a backup.
const minimumBackupPasswordLength = 8;

const _backupFormat = 'iam-hero-backup';
const _backupVersion = 1;
const _kdfName = 'argon2id';
const _cipherName = 'aes-256-gcm';
const _kdfMemory = 19 * 1024;
const _kdfIterations = 2;
const _kdfParallelism = 1;
const _keyLength = 32;
const _saltLength = 16;
const _macLength = 16;
const _associatedData = 'iam-hero-backup:v1';

/// Reports a malformed or unsupported encrypted backup container.
class BackupFormatException implements Exception {
  /// Creates a stable error without retaining private decoded content.
  const BackupFormatException();
}

/// Reports a wrong password or authenticated-cipher integrity failure.
class BackupAuthenticationException implements Exception {
  /// Creates a stable authentication error.
  const BackupAuthenticationException();
}

/// Reports a backup that exceeds the app's in-memory safety limit.
class BackupTooLargeException implements Exception {
  /// Creates a stable size-limit error.
  const BackupTooLargeException();
}

/// One Argon2id job sent to a background isolate.
class BackupKeyDerivation {
  /// Groups the password and its salt into one message the isolate receives.
  const BackupKeyDerivation({required this.password, required this.salt});

  /// Parent-entered backup password; never stored anywhere.
  final String password;

  /// Random salt saved in the public part of the backup envelope.
  final Uint8List salt;
}

/// Runs one Argon2id derivation, by default on a background isolate.
typedef BackupKeyDeriver =
    Future<Uint8List> Function(BackupKeyDerivation derivation);

/// Derives the AES-256 backup key using fixed, versioned resource parameters.
///
/// Top-level so it can be the entry point of a background isolate. Tests may
/// pass it directly to [EncryptedBackupCodec] to skip the isolate hop.
Future<Uint8List> deriveBackupKey(BackupKeyDerivation derivation) async {
  final argon2id = Argon2id(
    parallelism: _kdfParallelism,
    memory: _kdfMemory,
    iterations: _kdfIterations,
    hashLength: _keyLength,
  );
  final key = await argon2id.deriveKeyFromPassword(
    password: derivation.password,
    nonce: derivation.salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}

/// Encrypts and validates portable, password-protected family snapshots.
class EncryptedBackupCodec {
  /// Creates the version-one Argon2id and AES-GCM codec.
  ///
  /// [deriver] exists so tests can substitute the isolate boundary; production
  /// code keeps the default `compute` hop, which runs inline on Flutter web
  /// because that platform has no isolates.
  EncryptedBackupCodec({BackupKeyDeriver? deriver})
    : _deriveKeyBytes = deriver ?? _computeBackupKey,
      _cipher = AesGcm.with256bits();

  final BackupKeyDeriver _deriveKeyBytes;
  final AesGcm _cipher;

  /// Encrypts one application snapshot with a new random salt and nonce.
  Future<Uint8List> encode(AppState state, String password) async {
    if (password.length < minimumBackupPasswordLength) {
      throw ArgumentError.value(password, 'password');
    }
    final salt = Uint8List.fromList(randomBytes(_saltLength));
    final secretKey = await _deriveKey(password, salt);
    final secretBox = await _cipher.encrypt(
      utf8.encode(jsonEncode(state.toJson())),
      secretKey: secretKey,
      nonce: _cipher.newNonce(),
      aad: utf8.encode(_associatedData),
    );
    final bytes = _encodeEnvelope(secretBox, salt);
    if (bytes.length > maximumBackupBytes) {
      throw const BackupTooLargeException();
    }
    return bytes;
  }

  /// Authenticates, decrypts, and validates one complete backup before use.
  Future<AppState> decode(Uint8List bytes, String password) async {
    if (bytes.length > maximumBackupBytes) {
      throw const BackupTooLargeException();
    }
    try {
      final envelope = _decodeEnvelope(bytes);
      final salt = _validatedSalt(envelope);
      final secretBox = _secretBoxFromEnvelope(envelope);
      return await _decryptState(secretBox, password, salt);
    } on BackupAuthenticationException {
      rethrow;
    } on FormatException {
      throw const BackupFormatException();
    } on ArgumentError {
      throw const BackupFormatException();
    }
  }

  /// Serializes public algorithms, random salt, and authenticated ciphertext.
  Uint8List _encodeEnvelope(SecretBox secretBox, List<int> salt) {
    final envelope = <String, Object>{
      'format': _backupFormat,
      'version': _backupVersion,
      'kdf': _kdfJson(salt),
      'cipher': <String, Object>{
        'name': _cipherName,
        'payload': base64Encode(secretBox.concatenation()),
      },
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  /// Validates cipher metadata and reconstructs its nonce, bytes, and MAC.
  SecretBox _secretBoxFromEnvelope(Map<String, Object?> envelope) {
    final cipherJson = _object(envelope['cipher']);
    if (cipherJson['name'] != _cipherName) {
      throw const FormatException('Unsupported backup cipher.');
    }
    final payload = cipherJson['payload'];
    if (payload is! String) {
      throw const FormatException('Malformed backup payload.');
    }
    return SecretBox.fromConcatenation(
      base64Decode(payload),
      nonceLength: _cipher.nonceLength,
      macLength: _macLength,
    );
  }

  /// Decrypts authenticated bytes and passes JSON through AppState validation.
  Future<AppState> _decryptState(
    SecretBox secretBox,
    String password,
    Uint8List salt,
  ) async {
    final secretKey = await _deriveKey(password, salt);
    try {
      final clearText = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: utf8.encode(_associatedData),
      );
      return AppState.fromJson(_object(jsonDecode(utf8.decode(clearText))));
    } on SecretBoxAuthenticationError {
      throw const BackupAuthenticationException();
    }
  }

  /// Derives the AES-256 key without blocking the interface thread.
  Future<SecretKey> _deriveKey(String password, Uint8List salt) async {
    final keyBytes = await _deriveKeyBytes(
      BackupKeyDerivation(password: password, salt: salt),
    );
    return SecretKey(keyBytes);
  }

  /// Parses the public envelope and verifies its supported schema identity.
  Map<String, Object?> _decodeEnvelope(Uint8List bytes) {
    final envelope = _object(jsonDecode(utf8.decode(bytes)));
    if (envelope['format'] != _backupFormat ||
        envelope['version'] != _backupVersion) {
      throw const FormatException('Unsupported backup format.');
    }
    return envelope;
  }

  /// Accepts only this version's exact KDF parameters before doing costly work.
  Uint8List _validatedSalt(Map<String, Object?> envelope) {
    final kdfJson = _object(envelope['kdf']);
    if (kdfJson['name'] != _kdfName ||
        kdfJson['memory'] != _kdfMemory ||
        kdfJson['iterations'] != _kdfIterations ||
        kdfJson['parallelism'] != _kdfParallelism ||
        kdfJson['hashLength'] != _keyLength) {
      throw const FormatException('Unsupported backup key derivation.');
    }
    final encodedSalt = kdfJson['salt'];
    if (encodedSalt is! String) {
      throw const FormatException('Malformed backup salt.');
    }
    final salt = base64Decode(encodedSalt);
    if (salt.length != _saltLength) {
      throw const FormatException('Malformed backup salt.');
    }
    return salt;
  }

  /// Creates the public, versioned KDF description stored with ciphertext.
  Map<String, Object> _kdfJson(List<int> salt) {
    return <String, Object>{
      'name': _kdfName,
      'salt': base64Encode(salt),
      'memory': _kdfMemory,
      'iterations': _kdfIterations,
      'parallelism': _kdfParallelism,
      'hashLength': _keyLength,
    };
  }

  /// Requires dynamically decoded JSON to contain a string-keyed object.
  Map<String, Object?> _object(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object.');
    }
    return value;
  }
}

/// Moves the Argon2id work off the UI thread so backups never freeze it.
Future<Uint8List> _computeBackupKey(BackupKeyDerivation derivation) {
  return compute(deriveBackupKey, derivation);
}
