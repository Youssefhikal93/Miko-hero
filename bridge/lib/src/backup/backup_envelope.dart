import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:iam_hero_bridge/src/backup/backup_errors.dart';
import 'package:iam_hero_bridge/src/common/secrets.dart';

/// File extension of a bridge master-library backup.
const String backupFileExtension = '.ihmb';

/// Magic bytes every master backup file starts with.
///
/// Deliberately unlike the app's own backup files, which are JSON envelopes
/// carrying a `format` field: a master backup is binary and starts with this
/// string, so neither file kind can ever be mistaken for the other, by a
/// program or by a parent looking at a folder.
const String backupMagic = 'IAMHEROMASTERBK1';

/// Container format version written into the header.
const int backupFormatVersion = 1;

/// Minimum password length accepted when creating a backup.
const int minimumBackupPasswordLength = 8;

/// PBKDF2-HMAC-SHA256 iteration count used for new backups.
const int backupPbkdf2Iterations = 200000;

/// Smallest iteration count this build will accept when opening a file.
///
/// A file is data, not a trusted instruction: a header asking for fewer
/// iterations is a weakened file and is refused, and one asking for absurdly
/// many is refused too instead of burning the PC's CPU for hours.
const int minimumBackupPbkdf2Iterations = 200000;

/// Largest iteration count this build will accept when opening a file.
const int maximumBackupPbkdf2Iterations = 5000000;

/// Length of the random PBKDF2 salt in bytes.
const int backupSaltLength = 32;

/// Length of the random AES-GCM nonce in bytes.
const int backupNonceLength = 12;

/// Length of the AES-GCM authentication tag in bytes.
const int backupMacLength = 16;

/// Largest backup file this build will read into memory (256 MB).
const int maximumBackupFileBytes = 256 * 1024 * 1024;

const int _kdfPbkdf2HmacSha256 = 1;
const int _cipherAes256Gcm = 1;

/// The password-protected container a master backup travels in.
///
/// Layout, big-endian, header first:
///
/// ```text
/// 16  magic          "IAMHEROMASTERBK1"
///  1  formatVersion  1
///  1  kdfId          1 = PBKDF2-HMAC-SHA256
///  1  cipherId       1 = AES-256-GCM
///  1  reserved       0
///  4  iterations     PBKDF2 iteration count
///  1  saltLength     32
///  1  nonceLength    12
///  1  macLength      16
///  1  reserved       0
/// 32  salt           random per file
/// 12  nonce          random per file
///  n  ciphertext     AES-256-GCM over the JSON payload
/// 16  mac            GCM tag over ciphertext, with the header as AAD
/// ```
///
/// The whole header is the authenticated associated data, so editing the
/// iteration count, the salt or the magic fails authentication instead of
/// silently changing how the file is read.
abstract final class BackupEnvelope {
  static const int _magicOffset = 0;
  static const int _formatVersionOffset = 16;
  static const int _kdfIdOffset = 17;
  static const int _cipherIdOffset = 18;
  static const int _iterationsOffset = 20;
  static const int _saltLengthOffset = 24;
  static const int _nonceLengthOffset = 25;
  static const int _macLengthOffset = 26;
  static const int _saltOffset = 28;
  static const int _nonceOffset = _saltOffset + backupSaltLength;

  /// Number of header bytes preceding the ciphertext.
  static const int headerLength = _nonceOffset + backupNonceLength;

  /// Encrypts [payloadBytes] under [password] into one complete file.
  ///
  /// Uses a fresh random salt and nonce every time, so two backups of the
  /// same library never produce the same bytes.
  static Future<Uint8List> seal({
    required List<int> payloadBytes,
    required String password,
    int iterations = backupPbkdf2Iterations,
  }) async {
    if (password.length < minimumBackupPasswordLength) {
      throw const BackupException(
        BackupFailureCode.passwordTooShort,
        'The backup password must be at least '
        '$minimumBackupPasswordLength characters long.',
      );
    }
    final salt = secureRandomBytes(backupSaltLength);
    final nonce = secureRandomBytes(backupNonceLength);
    final header = _header(iterations: iterations, salt: salt, nonce: nonce);
    final SecretBox box = await _cipher.encrypt(
      payloadBytes,
      secretKey: await _deriveKey(password, salt, iterations),
      nonce: nonce,
      aad: header,
    );
    final builder = BytesBuilder(copy: false)
      ..add(header)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return builder.takeBytes();
  }

  /// Verifies and decrypts [fileBytes] back into its payload bytes.
  ///
  /// Throws a [BackupException] with [BackupFailureCode.unreadable] for a
  /// file that is not a master backup, [BackupFailureCode.unsupportedVersion]
  /// for one written by a newer bridge, and
  /// [BackupFailureCode.authenticationFailed] when the password is wrong or a
  /// single byte anywhere in the file was changed.
  static Future<Uint8List> open({
    required Uint8List fileBytes,
    required String password,
  }) async {
    if (fileBytes.length > maximumBackupFileBytes) {
      throw const BackupException(
        BackupFailureCode.tooLarge,
        'The backup file is larger than this bridge can read.',
      );
    }
    if (fileBytes.length < headerLength + backupMacLength) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The file is too short to be a master library backup.',
      );
    }
    final magic = utf8.decode(
      fileBytes.sublist(_magicOffset, _magicOffset + backupMagic.length),
      allowMalformed: true,
    );
    if (magic != backupMagic) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The file is not a bridge master library backup.',
      );
    }
    final view = ByteData.sublistView(fileBytes);
    final formatVersion = view.getUint8(_formatVersionOffset);
    if (formatVersion > backupFormatVersion) {
      throw const BackupException(
        BackupFailureCode.unsupportedVersion,
        'The backup file was written by a newer bridge version.',
      );
    }
    if (formatVersion < backupFormatVersion ||
        view.getUint8(_kdfIdOffset) != _kdfPbkdf2HmacSha256 ||
        view.getUint8(_cipherIdOffset) != _cipherAes256Gcm) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup file uses an unsupported format.',
      );
    }
    final iterations = view.getUint32(_iterationsOffset);
    if (iterations < minimumBackupPbkdf2Iterations ||
        iterations > maximumBackupPbkdf2Iterations) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup file declares an unsupported key derivation cost.',
      );
    }
    if (view.getUint8(_saltLengthOffset) != backupSaltLength ||
        view.getUint8(_nonceLengthOffset) != backupNonceLength ||
        view.getUint8(_macLengthOffset) != backupMacLength) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup file header is damaged.',
      );
    }
    final header = fileBytes.sublist(0, headerLength);
    final salt = fileBytes.sublist(_saltOffset, _saltOffset + backupSaltLength);
    final nonce = fileBytes.sublist(
      _nonceOffset,
      _nonceOffset + backupNonceLength,
    );
    final cipherText = fileBytes.sublist(
      headerLength,
      fileBytes.length - backupMacLength,
    );
    final mac = fileBytes.sublist(fileBytes.length - backupMacLength);
    try {
      final clearText = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: await _deriveKey(password, salt, iterations),
        aad: header,
      );
      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw const BackupException(
        BackupFailureCode.authenticationFailed,
        'Wrong password, or the backup file has been altered.',
      );
    }
  }

  static Uint8List _header({
    required int iterations,
    required Uint8List salt,
    required Uint8List nonce,
  }) {
    final header = Uint8List(headerLength);
    header.setRange(
      _magicOffset,
      _magicOffset + backupMagic.length,
      utf8.encode(backupMagic),
    );
    final view = ByteData.sublistView(header);
    view.setUint8(_formatVersionOffset, backupFormatVersion);
    view.setUint8(_kdfIdOffset, _kdfPbkdf2HmacSha256);
    view.setUint8(_cipherIdOffset, _cipherAes256Gcm);
    view.setUint32(_iterationsOffset, iterations);
    view.setUint8(_saltLengthOffset, backupSaltLength);
    view.setUint8(_nonceLengthOffset, backupNonceLength);
    view.setUint8(_macLengthOffset, backupMacLength);
    header.setRange(_saltOffset, _saltOffset + backupSaltLength, salt);
    header.setRange(_nonceOffset, _nonceOffset + backupNonceLength, nonce);
    return header;
  }

  static AesGcm get _cipher => AesGcm.with256bits();

  static Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
    int iterations,
  ) {
    // PBKDF2-HMAC-SHA256 rather than the app's Argon2id: this file is only
    // ever created and read on the family PC by a pure-Dart process, and
    // PBKDF2 needs no native dependency. See the README for the reasoning.
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return pbkdf2.deriveKeyFromPassword(password: password, nonce: salt);
  }
}
