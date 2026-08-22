import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/backup/backup_envelope.dart';
import 'package:iam_hero_bridge/src/backup/backup_errors.dart';
import 'package:iam_hero_bridge/src/backup/library_backup_payload.dart';
import 'package:iam_hero_bridge/src/common/atomic_files.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';

/// Prefix of every master-library backup file name.
const String backupFileNamePrefix = 'iam-hero-master-';

/// Token hash written for a device row that came out of a backup.
///
/// Backups never carry token hashes, but the column is `NOT NULL UNIQUE`, so
/// a restored device gets this placeholder plus its own id. It can never
/// equal a SHA-256 digest, so a restored device is a name in the list and
/// nothing more: it has to pair again.
String restoredDeviceTokenHash(String deviceId) =>
    'restored-device-no-token:$deviceId';

/// Result of creating one backup file.
class BackupCreation {
  /// Creates a backup result.
  const BackupCreation({
    required this.fileName,
    required this.sizeBytes,
    required this.createdAtUtc,
    required this.rowCount,
    required this.fileCount,
  });

  /// Name of the written file inside the library's `exports/` folder.
  final String fileName;

  /// Size of the written file in bytes.
  final int sizeBytes;

  /// When the backup was taken.
  final DateTime createdAtUtc;

  /// Number of database rows inside the backup.
  final int rowCount;

  /// Number of photo and illustration files inside the backup.
  final int fileCount;

  /// JSON shape returned by `POST /library/backup`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fileName': fileName,
      'sizeBytes': sizeBytes,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'rowCount': rowCount,
      'fileCount': fileCount,
    };
  }
}

/// Result of restoring one backup file.
class BackupRestore {
  /// Creates a restore result.
  const BackupRestore({
    required this.fileName,
    required this.backupCreatedAtUtc,
    required this.restoredRowCount,
    required this.restoredFileCount,
    required this.restoredDeviceCount,
  });

  /// Name of the file that was restored.
  final String fileName;

  /// When that backup had been created.
  final DateTime backupCreatedAtUtc;

  /// Number of database rows written.
  final int restoredRowCount;

  /// Number of photo and illustration files written.
  final int restoredFileCount;

  /// Number of device rows that came back as names only.
  final int restoredDeviceCount;

  /// JSON shape returned by `POST /library/restore`.
  ///
  /// `devicesMustRePair` is always true and always sent: it is the one
  /// consequence of a restore a parent has to act on.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fileName': fileName,
      'backupCreatedAtUtc': backupCreatedAtUtc.toIso8601String(),
      'restoredRowCount': restoredRowCount,
      'restoredFileCount': restoredFileCount,
      'restoredDeviceCount': restoredDeviceCount,
      'devicesMustRePair': true,
    };
  }
}

/// Creates and restores encrypted snapshots of the whole master library.
///
/// A backup is one authenticated file: every database row (device token
/// hashes excluded) plus every photo and illustration, encrypted under a
/// password the parent chooses in the app. A restore is all-or-nothing —
/// files are staged next to their targets, the database is replaced inside
/// one transaction, and only a committed transaction is followed by the
/// renames — so a failure anywhere leaves the library exactly as it was.
class LibraryBackupService {
  /// Creates a service over [library].
  const LibraryBackupService({required this.library});

  /// The initialized master library this service snapshots.
  final MasterLibrary library;

  /// Writes one encrypted backup of the complete library into `exports/`.
  ///
  /// Throws a [BackupException] with [BackupFailureCode.passwordTooShort] for
  /// a password under [minimumBackupPasswordLength] characters,
  /// [BackupFailureCode.tooLarge] for a library that does not fit in memory,
  /// and [BackupFailureCode.writeFailed] when the file cannot be written.
  Future<BackupCreation> createBackup({
    required String password,
    required DateTime nowUtc,
  }) async {
    if (password.length < minimumBackupPasswordLength) {
      throw const BackupException(
        BackupFailureCode.passwordTooShort,
        'The backup password must be at least '
        '$minimumBackupPasswordLength characters long.',
      );
    }
    final createdAt = nowUtc.toUtc();
    final payload = LibraryBackupPayload(
      payloadVersion: backupPayloadVersion,
      createdAtUtc: createdAt,
      librarySchemaVersion: MasterLibrary.currentSchemaVersion,
      tables: _snapshotTables(),
      files: await _snapshotFiles(),
    );
    final Uint8List payloadBytes = payload.toBytes();
    if (payloadBytes.length > maximumBackupFileBytes) {
      throw const BackupException(
        BackupFailureCode.tooLarge,
        'The library is too large to back up in one file.',
      );
    }
    final Uint8List fileBytes = await BackupEnvelope.seal(
      payloadBytes: payloadBytes,
      password: password,
    );
    final fileName = await _reserveFileName(createdAt);
    try {
      await writeFileAtomic(_exportPath(fileName), fileBytes);
    } on FileSystemException {
      throw const BackupException(
        BackupFailureCode.writeFailed,
        'The backup file could not be written to the exports folder.',
      );
    }
    return BackupCreation(
      fileName: fileName,
      sizeBytes: fileBytes.length,
      createdAtUtc: createdAt,
      rowCount: payload.rowCount,
      fileCount: payload.files.length,
    );
  }

  /// Replaces the whole library with the contents of [fileName].
  ///
  /// [fileName] must be a plain name inside the library's `exports/` folder.
  /// Every failure mode is typed and leaves the library untouched; the only
  /// exception is a file-system failure during the final rename phase, after
  /// the database transaction has already committed, which is reported as
  /// [BackupFailureCode.restoreFailed] with the database already restored.
  Future<BackupRestore> restoreBackup({
    required String fileName,
    required String password,
  }) async {
    _requireBackupFileName(fileName);
    final file = File(_exportPath(fileName));
    if (!await file.exists()) {
      throw const BackupException(
        BackupFailureCode.notFound,
        'No backup with this name exists in the exports folder.',
      );
    }
    if (await file.length() > maximumBackupFileBytes) {
      throw const BackupException(
        BackupFailureCode.tooLarge,
        'The backup file is larger than this bridge can read.',
      );
    }
    final Uint8List fileBytes = await file.readAsBytes();
    final payload = LibraryBackupPayload.fromBytes(
      await BackupEnvelope.open(fileBytes: fileBytes, password: password),
    );

    final staged = <_StagedFile>[];
    try {
      for (final entry in payload.files) {
        final targetPath = joinPath(
          library.rootPath,
          toPlatformRelativePath(entry.relativePath),
        );
        staged.add(
          _StagedFile(
            temporary: await writeTemporarySibling(targetPath, entry.bytes),
            targetPath: targetPath,
            relativePath: entry.relativePath,
          ),
        );
      }
      _replaceRows(payload);
    } catch (error) {
      for (final entry in staged) {
        await deleteTemporaryFile(entry.temporary);
      }
      if (error is BackupException) {
        rethrow;
      }
      // The transaction rolled back and no staged file was moved into place,
      // so the library is untouched. The cause is dropped on purpose: it can
      // quote row values.
      throw const BackupException(
        BackupFailureCode.restoreFailed,
        'The backup could not be restored; the library was left unchanged.',
      );
    }

    try {
      for (final entry in staged) {
        await replaceWithTemporaryFile(entry.temporary, entry.targetPath);
      }
      await _removeFilesOutside(
        staged.map((entry) => entry.relativePath).toSet(),
      );
    } on FileSystemException {
      throw const BackupException(
        BackupFailureCode.restoreFailed,
        'The database was restored but some files could not be replaced.',
      );
    }

    return BackupRestore(
      fileName: fileName,
      backupCreatedAtUtc: payload.createdAtUtc,
      restoredRowCount: payload.rowCount,
      restoredFileCount: payload.files.length,
      restoredDeviceCount:
          (payload.tables['devices'] ?? const <Map<String, Object?>>[]).length,
    );
  }

  Map<String, List<Map<String, Object?>>> _snapshotTables() {
    final db = library.database;
    // One transaction so a story cannot be written between two of the
    // selects and land in the backup with only half of its pages.
    return runInDatabaseTransaction(db, () {
      final snapshot = <String, List<Map<String, Object?>>>{};
      for (final spec in backupTableSpecs) {
        final rows = db.select(
          'SELECT ${spec.columns.join(', ')} FROM ${spec.name}',
        );
        snapshot[spec.name] = rows
            .map(
              (row) => <String, Object?>{
                for (final column in spec.columns) column: row[column],
              },
            )
            .toList(growable: false);
      }
      return snapshot;
    });
  }

  Future<List<BackupFileEntry>> _snapshotFiles() async {
    final entries = <BackupFileEntry>[];
    for (final root in backedUpFileRoots) {
      final directory = Directory(joinPath(library.rootPath, root));
      if (!await directory.exists()) {
        continue;
      }
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relativePath = _libraryRelativePath(entity.path);
        if (relativePath == null) {
          continue;
        }
        entries.add(
          BackupFileEntry(
            relativePath: relativePath,
            bytes: await entity.readAsBytes(),
          ),
        );
      }
    }
    entries.sort((a, b) => a.relativePath.compareTo(b.relativePath));
    return entries;
  }

  void _replaceRows(LibraryBackupPayload payload) {
    final db = library.database;
    runInDatabaseTransaction(db, () {
      for (final spec in backupTableSpecs.reversed) {
        db.execute('DELETE FROM ${spec.name}');
      }
      for (final spec in backupTableSpecs) {
        final rows =
            payload.tables[spec.name] ?? const <Map<String, Object?>>[];
        for (final row in rows) {
          final columns = spec.columns
              .where(row.containsKey)
              .toList(growable: true);
          final values = columns.map((column) => row[column]).toList();
          if (spec.name == 'devices') {
            columns.add('token_hash');
            values.add(restoredDeviceTokenHash(row['id']! as String));
          }
          final placeholders = List<String>.filled(columns.length, '?');
          db.execute(
            'INSERT INTO ${spec.name} (${columns.join(', ')}) '
            'VALUES (${placeholders.join(', ')})',
            values,
          );
        }
      }
    });
  }

  Future<void> _removeFilesOutside(Set<String> keptRelativePaths) async {
    // The listing is drained before anything is deleted: mutating a directory
    // while walking it is not safe on every platform.
    final doomed = <File>[];
    for (final root in backedUpFileRoots) {
      final directory = Directory(joinPath(library.rootPath, root));
      if (!await directory.exists()) {
        continue;
      }
      await for (final entity in directory.list(recursive: true)) {
        if (entity is! File) {
          continue;
        }
        final relativePath = _libraryRelativePath(entity.path);
        if (relativePath == null || keptRelativePaths.contains(relativePath)) {
          continue;
        }
        doomed.add(entity);
      }
    }
    for (final file in doomed) {
      await file.delete();
    }
  }

  String? _libraryRelativePath(String absolutePath) {
    final prefix = joinPath(library.rootPath, '');
    if (!absolutePath.startsWith(prefix)) {
      return null;
    }
    final relative = absolutePath
        .substring(prefix.length)
        .replaceAll(r'\', '/');
    return isSafeLibraryRelativePath(relative, allowedRoots: backedUpFileRoots)
        ? relative
        : null;
  }

  String _exportPath(String fileName) {
    return joinPath(library.folderPath(LibraryFolder.exports), fileName);
  }

  Future<String> _reserveFileName(DateTime createdAt) async {
    final stamp = _compactTimestamp(createdAt);
    for (var attempt = 1; attempt <= 100; attempt++) {
      final suffix = attempt == 1 ? '' : '-$attempt';
      final candidate =
          '$backupFileNamePrefix$stamp$suffix'
          '$backupFileExtension';
      if (!await File(_exportPath(candidate)).exists()) {
        return candidate;
      }
    }
    throw const BackupException(
      BackupFailureCode.writeFailed,
      'Too many backups already exist for this second.',
    );
  }

  void _requireBackupFileName(String fileName) {
    if (fileName.isEmpty ||
        fileName.length > 200 ||
        !fileName.endsWith(backupFileExtension) ||
        fileName.contains('/') ||
        fileName.contains(r'\') ||
        fileName.contains(':') ||
        fileName.startsWith('.')) {
      throw const BackupException(
        BackupFailureCode.invalidFileName,
        'The backup name must be a plain file name inside the exports '
        'folder.',
      );
    }
  }

  String _compactTimestamp(DateTime utc) {
    String pad(int value, [int width = 2]) =>
        value.toString().padLeft(width, '0');
    return '${pad(utc.year, 4)}${pad(utc.month)}${pad(utc.day)}'
        'T${pad(utc.hour)}${pad(utc.minute)}${pad(utc.second)}Z';
  }
}

class _StagedFile {
  const _StagedFile({
    required this.temporary,
    required this.targetPath,
    required this.relativePath,
  });

  final File temporary;
  final String targetPath;
  final String relativePath;
}
