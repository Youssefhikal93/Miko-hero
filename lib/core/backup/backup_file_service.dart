import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';

/// Selected encrypted backup bytes and their original display name.
class PickedBackup {
  /// Creates a selected backup after its bytes pass the size boundary.
  const PickedBackup({required this.name, required this.bytes});

  /// Original file name shown during restore confirmation.
  final String name;

  /// Complete encrypted container held only for the restore flow.
  final Uint8List bytes;
}

/// Reports a platform picker result whose bytes could not be read.
class BackupFileReadException implements Exception {
  /// Creates a stable file-read error.
  const BackupFileReadException();
}

/// Opens and saves portable backup files on Android, iOS, and web.
class BackupFileService {
  /// Lets the parent choose one encrypted Iam - hero backup file.
  Future<PickedBackup?> pickBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['iamhero'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > maximumBackupBytes) {
      throw const BackupTooLargeException();
    }
    final bytes = file.bytes;
    if (bytes == null) throw const BackupFileReadException();
    return PickedBackup(name: file.name, bytes: bytes);
  }

  /// Opens the save flow and reports success, including web download dispatch.
  Future<bool> saveBackup(
    Uint8List bytes,
    DateTime currentTime,
    String dialogTitle,
  ) async {
    final date = currentTime.toUtc().toIso8601String().split('T').first;
    final savedPath = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: 'iam-hero-backup-$date.iamhero',
      type: FileType.custom,
      allowedExtensions: const <String>['iamhero'],
      bytes: bytes,
    );
    return kIsWeb || savedPath != null;
  }
}
