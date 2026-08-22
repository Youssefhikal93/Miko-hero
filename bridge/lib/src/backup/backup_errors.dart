/// Machine-readable reason a backup or restore did not succeed.
///
/// Wrong password and a tampered file deliberately share
/// [BackupFailureCode.authenticationFailed]: AES-GCM cannot tell them apart,
/// and pretending otherwise would leak which of the two happened.
enum BackupFailureCode {
  /// The submitted password is shorter than the required minimum.
  passwordTooShort('backup_password_too_short'),

  /// The requested file name is not a plain name inside `exports/`.
  invalidFileName('backup_invalid_file_name'),

  /// No such backup file exists in the library's `exports/` folder.
  notFound('backup_not_found'),

  /// The file is not a bridge master backup, or its header is damaged.
  unreadable('backup_unreadable'),

  /// The password is wrong or the file's bytes were altered.
  authenticationFailed('backup_authentication_failed'),

  /// The file was written by a newer bridge than this one.
  unsupportedVersion('backup_unsupported_version'),

  /// The library or backup file exceeds the in-memory safety limit.
  tooLarge('backup_too_large'),

  /// The backup file could not be written.
  writeFailed('backup_write_failed'),

  /// The restore was aborted; the library was left exactly as it was.
  restoreFailed('backup_restore_failed');

  const BackupFailureCode(this.wireCode);

  /// Stable snake_case code used in JSON error envelopes.
  final String wireCode;
}

/// Exception raised inside the backup and restore pipeline.
///
/// Every layer (container, payload, file system, database) converts its own
/// failures into this type, so the HTTP handler only maps typed codes and
/// never has to inspect a cause that could quote library content.
class BackupException implements Exception {
  /// Creates an exception carrying a typed [code] and a safe [message].
  const BackupException(this.code, this.message);

  /// Machine-readable reason for the failure.
  final BackupFailureCode code;

  /// Safe explanation; never echoes library content or file contents.
  final String message;

  @override
  String toString() => 'BackupException(${code.wireCode})';
}
