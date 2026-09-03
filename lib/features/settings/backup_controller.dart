import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/backup/backup_file_service.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/storage/library_transaction.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';

/// Supplies the authenticated encryption codec used by backup commands.
final encryptedBackupCodecProvider = Provider<EncryptedBackupCodec>((ref) {
  return EncryptedBackupCodec();
});

/// Supplies cross-platform backup file selection and saving.
final backupFileServiceProvider = Provider<BackupFileService>((ref) {
  return BackupFileService();
});

/// Supplies portable backup commands to the parent settings feature.
final backupControllerProvider = Provider<BackupController>(
  BackupController.new,
);

/// Coordinates encrypted bytes, platform files, persistence, and app state.
class BackupController {
  /// Retains the provider scope used by the backup transaction.
  BackupController(this._ref);

  final Ref _ref;

  /// Encrypts the current family snapshot without saving plaintext anywhere.
  Future<Uint8List> createBackup(String password) {
    final current = _ref.read(appControllerProvider).requireValue;
    return _ref.read(encryptedBackupCodecProvider).encode(current, password);
  }

  /// Opens the save flow and reports whether a file or download was accepted.
  Future<bool> saveBackup(Uint8List bytes, String dialogTitle) {
    return _ref
        .read(backupFileServiceProvider)
        .saveBackup(bytes, DateTime.now(), dialogTitle);
  }

  /// Opens the platform picker for one portable encrypted backup.
  Future<PickedBackup?> pickBackup() {
    return _ref.read(backupFileServiceProvider).pickBackup();
  }

  /// Decrypts and fully validates a selected backup before confirmation.
  Future<AppState> decodeBackup(Uint8List bytes, String password) {
    return _ref.read(encryptedBackupCodecProvider).decode(bytes, password);
  }

  /// Replaces local family state only after decode and parent confirmation.
  Future<void> restore(AppState restoredState) async {
    await _ref.read(libraryTransactionProvider).replaceState(restoredState);
    _ref.invalidate(generationQueueControllerProvider);
  }
}
