import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/helpers.dart';
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

/// Encrypts and validates portable, password-protected family snapshots.
class EncryptedBackupCodec {
  /// Creates the version-one Argon2id and AES-GCM codec.
  EncryptedBackupCodec()
    : _keyDerivation = Argon2id(
        parallelism: _kdfParallelism,
        memory: _kdfMemory,
        iterations: _kdfIterations,
        hashLength: _keyLength,
      ),
      _cipher = AesGcm.with256bits();

  final Argon2id _keyDerivation;
  final AesGcm _cipher;

  /// Encrypts one application snapshot with a new random salt and nonce.
  Future<Uint8List> encode(AppState state, String password) async {
    if (password.length < minimumBackupPasswordLength) {
      throw ArgumentError.value(password, 'password');
    }
    final salt = randomBytes(_saltLength);
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
    List<int> salt,
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

  /// Derives the AES-256 key using fixed, versioned resource parameters.
  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _keyDerivation.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
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
  List<int> _validatedSalt(Map<String, Object?> envelope) {
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
