import 'package:iam_hero_bridge/src/backup/backup_envelope.dart';
import 'package:iam_hero_bridge/src/backup/backup_errors.dart';
import 'package:iam_hero_bridge/src/backup/library_backup_service.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the two authenticated master-library backup endpoints.
///
/// The parent drives both from the app on a paired device; the file itself
/// never travels over HTTP. It is written into, and read from, the library's
/// own `exports/` folder on the PC, so a password-protected snapshot of the
/// whole family library never has to pass through a phone.
///
/// Error codes come from [BackupFailureCode], so the app sees the same stable
/// strings the bridge reasons with.
class BackupHandlers {
  /// Creates handlers over [service].
  const BackupHandlers({required this._service});

  final LibraryBackupService _service;

  /// Handles `POST /library/backup`.
  Future<Response> createBackup(Request request) async {
    requireAuthenticatedDevice(request);
    final body = await parseJsonObjectBody(request);
    final password = _requiredPassword(body);
    try {
      final creation = await _service.createBackup(
        password: password,
        nowUtc: DateTime.now().toUtc(),
      );
      return jsonResponse(201, creation.toJson());
    } on BackupException catch (error) {
      throw _asApiError(error);
    }
  }

  /// Handles `POST /library/restore`.
  Future<Response> restoreBackup(Request request) async {
    requireAuthenticatedDevice(request);
    final body = await parseJsonObjectBody(request);
    final fileName = requiredStringField(body, 'fileName');
    final password = _requiredPassword(body);
    try {
      final restore = await _service.restoreBackup(
        fileName: fileName,
        password: password,
      );
      return jsonResponse(200, restore.toJson());
    } on BackupException catch (error) {
      throw _asApiError(error);
    }
  }

  /// Reads the password without trimming or length-capping it: a passphrase
  /// may legitimately start or end with a space.
  String _requiredPassword(Map<String, Object?> body) {
    final value = body['password'];
    if (value is! String || value.length < minimumBackupPasswordLength) {
      throw ApiError(
        400,
        BackupFailureCode.passwordTooShort.wireCode,
        'Field "password" must be at least '
        '$minimumBackupPasswordLength characters long.',
      );
    }
    return value;
  }

  ApiError _asApiError(BackupException error) {
    return ApiError(_statusFor(error.code), error.code.wireCode, error.message);
  }

  int _statusFor(BackupFailureCode code) {
    switch (code) {
      case BackupFailureCode.passwordTooShort:
      case BackupFailureCode.invalidFileName:
      case BackupFailureCode.unreadable:
      case BackupFailureCode.unsupportedVersion:
        return 400;
      case BackupFailureCode.authenticationFailed:
        return 403;
      case BackupFailureCode.notFound:
        return 404;
      case BackupFailureCode.tooLarge:
        return 413;
      case BackupFailureCode.writeFailed:
      case BackupFailureCode.restoreFailed:
        return 500;
    }
  }
}
