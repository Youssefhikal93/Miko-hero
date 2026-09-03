import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/files/encrypted_file_flow.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/storage/library_transaction.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';

/// Supplies the authenticated encryption codec used by backup commands.
final encryptedBackupCodecProvider = Provider<EncryptedBackupCodec>((ref) {
  return EncryptedBackupCodec();
});

/// Supplies the whole-family configuration of the shared encrypted-file flow.
///
/// The file is named for the day it was made, because a family snapshot has no
/// title of its own and a date is what a parent looks for months later.
final backupFileFlowProvider = Provider<EncryptedFileFlow<AppState>>((ref) {
  final codec = ref.watch(encryptedBackupCodecProvider);
  return EncryptedFileFlow<AppState>(
    picker: ref.watch(encryptedFilePickerProvider),
    extension: backupFileExtension,
    maximumBytes: maximumBackupBytes,
    encode: codec.encode,
    decode: codec.decode,
    fileStem: (_) {
      final date = DateTime.now().toUtc().toIso8601String().split('T').first;
      return 'iam-hero-backup-$date';
    },
  );
});

/// Supplies portable backup commands to the parent settings feature.
final backupControllerProvider = Provider<BackupController>(
  BackupController.new,
);

/// Decides what a backup contains and what restoring one does to this device.
///
/// The file half — naming, size cap, picking, and every typed failure — belongs
/// to [backupFileFlowProvider]; what is left here is the two decisions only
/// this app can make.
class BackupController {
  /// Retains the provider scope used by the backup transaction.
  BackupController(this._ref);

  final Ref _ref;

  /// Encrypts the current family snapshot without saving plaintext anywhere.
  Future<Uint8List> createBackup(String password) {
    return _flow.encrypt(_currentState, password);
  }

  /// Offers the encrypted bytes to the platform under a dated file name.
  ///
  /// Separate from [createBackup] because the web build confirms the download
  /// only once the encryption a parent is waiting on has finished.
  Future<bool> saveBackup(Uint8List bytes, String dialogTitle) {
    return _flow.save(bytes, _currentState, dialogTitle: dialogTitle);
  }

  /// Picks one backup, asks for its password, and fully validates it.
  ///
  /// Null means the parent dismissed the picker or the password prompt, which
  /// changes nothing on this device.
  Future<AppState?> openBackup({
    required Future<String?> Function(String fileName) askPassword,
  }) {
    return _flow.import(askPassword: askPassword);
  }

  /// Replaces local family state only after decode and parent confirmation.
  ///
  /// The durable generation queue is dropped with it: a queued request from
  /// this device names a profile the restored family may not contain.
  Future<void> restore(AppState restoredState) async {
    await _ref.read(libraryTransactionProvider).replaceState(restoredState);
    _ref.invalidate(generationQueueControllerProvider);
  }

  /// The whole-family configuration of the shared encrypted-file flow.
  EncryptedFileFlow<AppState> get _flow => _ref.read(backupFileFlowProvider);

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }
}
