import 'dart:convert';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/backup/backup_errors.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';

/// Payload schema version written into every new backup.
const int backupPayloadVersion = 1;

/// Library folders whose files travel inside a backup payload.
///
/// `db/` is excluded on purpose — the database is carried as rows, not as a
/// file — and so is `exports/`, which holds the backups themselves.
const Set<String> backedUpFileRoots = <String>{'photos', 'illustrations'};

/// Which columns of one table a backup carries.
class BackupTableSpec {
  /// Describes one backed-up table.
  const BackupTableSpec({
    required this.name,
    required this.columns,
    required this.requiredColumns,
  });

  /// Table name in the master library.
  final String name;

  /// Every column a backup may carry for this table.
  ///
  /// Any other key in a payload row is refused, which is what keeps a
  /// hand-edited backup from smuggling a value into a column this build does
  /// not expect — `devices.token_hash` above all.
  final List<String> columns;

  /// Columns that must be present and non-null in every payload row.
  ///
  /// The remaining [columns] are nullable or carry a schema default, so an
  /// older payload that predates them restores cleanly.
  final List<String> requiredColumns;
}

/// Every backed-up table, ordered so inserting them in sequence never
/// violates a foreign key.
const List<BackupTableSpec> backupTableSpecs = <BackupTableSpec>[
  BackupTableSpec(
    name: 'profiles',
    columns: <String>['id', 'display_name', 'created_at_utc', 'updated_at_utc'],
    requiredColumns: <String>[
      'id',
      'display_name',
      'created_at_utc',
      'updated_at_utc',
    ],
  ),
  BackupTableSpec(
    name: 'stories',
    columns: <String>[
      'id',
      'profile_id',
      'title',
      'language_code',
      'created_at_utc',
      'updated_at_utc',
    ],
    requiredColumns: <String>[
      'id',
      'profile_id',
      'title',
      'created_at_utc',
      'updated_at_utc',
    ],
  ),
  BackupTableSpec(
    name: 'story_pages',
    columns: <String>[
      'id',
      'story_id',
      'page_index',
      'prose',
      'scene_description',
      'created_at_utc',
      'updated_at_utc',
    ],
    requiredColumns: <String>[
      'id',
      'story_id',
      'page_index',
      'prose',
      'created_at_utc',
      'updated_at_utc',
    ],
  ),
  BackupTableSpec(
    name: 'illustrations',
    columns: <String>[
      'id',
      'story_page_id',
      'relative_path',
      'status',
      'created_at_utc',
      'updated_at_utc',
    ],
    requiredColumns: <String>[
      'id',
      'story_page_id',
      'relative_path',
      'created_at_utc',
      'updated_at_utc',
    ],
  ),
  BackupTableSpec(
    // token_hash is deliberately absent: a backup must never be able to
    // authenticate a device, so restored devices are names only.
    name: 'devices',
    columns: <String>[
      'id',
      'device_name',
      'last_seen_at_utc',
      'revoked_at_utc',
      'created_at_utc',
      'updated_at_utc',
    ],
    requiredColumns: <String>[
      'id',
      'device_name',
      'created_at_utc',
      'updated_at_utc',
    ],
  ),
  BackupTableSpec(
    name: 'deletion_records',
    columns: <String>[
      'id',
      'entity_type',
      'entity_id',
      'requested_by_device_id',
      'deleted_at_utc',
    ],
    requiredColumns: <String>[
      'id',
      'entity_type',
      'entity_id',
      'deleted_at_utc',
    ],
  ),
  BackupTableSpec(
    name: 'sync_state',
    columns: <String>['device_id', 'last_synced_at_utc', 'updated_at_utc'],
    requiredColumns: <String>['device_id', 'updated_at_utc'],
  ),
];

/// One library file carried inside a backup payload.
class BackupFileEntry {
  /// Creates a file entry.
  const BackupFileEntry({required this.relativePath, required this.bytes});

  /// Library-relative, forward-slash path under `photos/` or
  /// `illustrations/`.
  final String relativePath;

  /// Complete file contents.
  final Uint8List bytes;
}

/// The complete, decrypted contents of one master-library backup.
///
/// Rows plus files, nothing else: no bridge configuration, no device tokens,
/// no absolute paths. Base64 inside the JSON keeps the container a single
/// authenticated blob at the cost of a third more size, which is the right
/// trade at family-library scale.
class LibraryBackupPayload {
  /// Creates a payload.
  const LibraryBackupPayload({
    required this.payloadVersion,
    required this.createdAtUtc,
    required this.librarySchemaVersion,
    required this.tables,
    required this.files,
  });

  /// Parses and validates one decrypted payload.
  ///
  /// Throws a [BackupException] with
  /// [BackupFailureCode.unsupportedVersion] for a payload or library schema
  /// this build does not know, and [BackupFailureCode.unreadable] for a
  /// structurally broken one. Nothing is touched before this succeeds.
  factory LibraryBackupPayload.fromBytes(Uint8List payloadBytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(payloadBytes));
    } on FormatException {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup payload is not valid JSON.',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup payload is not a JSON object.',
      );
    }
    final payloadVersion = _requireInt(decoded['payloadVersion'], 'version');
    if (payloadVersion > backupPayloadVersion) {
      throw const BackupException(
        BackupFailureCode.unsupportedVersion,
        'The backup was written by a newer bridge and cannot be restored.',
      );
    }
    final schemaVersion = _requireInt(
      decoded['librarySchemaVersion'],
      'library schema version',
    );
    if (schemaVersion > MasterLibrary.currentSchemaVersion) {
      throw const BackupException(
        BackupFailureCode.unsupportedVersion,
        'The backup holds a newer library schema than this bridge supports.',
      );
    }
    return LibraryBackupPayload(
      payloadVersion: payloadVersion,
      createdAtUtc: _requireTimestamp(decoded['createdAtUtc']),
      librarySchemaVersion: schemaVersion,
      tables: _parseTables(decoded['tables']),
      files: _parseFiles(decoded['files']),
    );
  }

  /// Payload schema version this backup was written with.
  final int payloadVersion;

  /// When the backup was created.
  final DateTime createdAtUtc;

  /// Master library schema version the rows came from.
  final int librarySchemaVersion;

  /// Table rows keyed by table name; every key is a [backupTableSpecs] name.
  final Map<String, List<Map<String, Object?>>> tables;

  /// Every photo and illustration file in the library.
  final List<BackupFileEntry> files;

  /// Total number of rows across all tables.
  int get rowCount =>
      tables.values.fold<int>(0, (total, rows) => total + rows.length);

  /// Serializes this payload to the exact JSON bytes a backup encrypts.
  Uint8List toBytes() {
    final json = <String, Object?>{
      'payloadVersion': payloadVersion,
      'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
      'librarySchemaVersion': librarySchemaVersion,
      'tables': <String, Object?>{
        for (final spec in backupTableSpecs)
          spec.name: tables[spec.name] ?? const <Map<String, Object?>>[],
      },
      'files': files
          .map(
            (file) => <String, Object?>{
              'path': file.relativePath,
              'bytesBase64': base64Encode(file.bytes),
            },
          )
          .toList(growable: false),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(json)));
  }

  static Map<String, List<Map<String, Object?>>> _parseTables(Object? raw) {
    if (raw is! Map<String, Object?>) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup payload has no table section.',
      );
    }
    final specsByName = <String, BackupTableSpec>{
      for (final spec in backupTableSpecs) spec.name: spec,
    };
    for (final key in raw.keys) {
      if (!specsByName.containsKey(key)) {
        throw const BackupException(
          BackupFailureCode.unreadable,
          'The backup payload holds an unknown table.',
        );
      }
    }
    final parsed = <String, List<Map<String, Object?>>>{};
    for (final spec in backupTableSpecs) {
      parsed[spec.name] = _parseRows(spec, raw[spec.name]);
    }
    return parsed;
  }

  static List<Map<String, Object?>> _parseRows(
    BackupTableSpec spec,
    Object? raw,
  ) {
    if (raw == null) {
      return const <Map<String, Object?>>[];
    }
    if (raw is! List<Object?>) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'A backup table section is not a list of rows.',
      );
    }
    final rows = <Map<String, Object?>>[];
    for (final entry in raw) {
      if (entry is! Map<String, Object?>) {
        throw const BackupException(
          BackupFailureCode.unreadable,
          'A backup row is not a JSON object.',
        );
      }
      final row = <String, Object?>{};
      for (final key in entry.keys) {
        if (!spec.columns.contains(key)) {
          throw const BackupException(
            BackupFailureCode.unreadable,
            'A backup row holds a column this bridge does not restore.',
          );
        }
        final value = entry[key];
        if (value != null && value is! String && value is! int) {
          throw const BackupException(
            BackupFailureCode.unreadable,
            'A backup row holds a value of an unsupported type.',
          );
        }
        row[key] = value;
      }
      for (final required in spec.requiredColumns) {
        if (row[required] == null) {
          throw const BackupException(
            BackupFailureCode.unreadable,
            'A backup row is missing a required column.',
          );
        }
      }
      rows.add(row);
    }
    return rows;
  }

  static List<BackupFileEntry> _parseFiles(Object? raw) {
    if (raw == null) {
      return const <BackupFileEntry>[];
    }
    if (raw is! List<Object?>) {
      throw const BackupException(
        BackupFailureCode.unreadable,
        'The backup payload file section is not a list.',
      );
    }
    final seen = <String>{};
    final files = <BackupFileEntry>[];
    for (final entry in raw) {
      if (entry is! Map<String, Object?>) {
        throw const BackupException(
          BackupFailureCode.unreadable,
          'A backup file entry is not a JSON object.',
        );
      }
      final path = entry['path'];
      final encoded = entry['bytesBase64'];
      if (path is! String ||
          encoded is! String ||
          !isSafeLibraryRelativePath(path, allowedRoots: backedUpFileRoots)) {
        throw const BackupException(
          BackupFailureCode.unreadable,
          'A backup file entry has no usable library-relative path.',
        );
      }
      if (!seen.add(path)) {
        throw const BackupException(
          BackupFailureCode.unreadable,
          'The backup payload lists the same file twice.',
        );
      }
      final Uint8List bytes;
      try {
        bytes = base64Decode(encoded);
      } on FormatException {
        throw const BackupException(
          BackupFailureCode.unreadable,
          'A backup file entry is not valid base64.',
        );
      }
      files.add(BackupFileEntry(relativePath: path, bytes: bytes));
    }
    return files;
  }

  static int _requireInt(Object? value, String what) {
    if (value is! int) {
      throw BackupException(
        BackupFailureCode.unreadable,
        'The backup payload has no $what.',
      );
    }
    return value;
  }

  static DateTime _requireTimestamp(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    throw const BackupException(
      BackupFailureCode.unreadable,
      'The backup payload has no creation timestamp.',
    );
  }
}
