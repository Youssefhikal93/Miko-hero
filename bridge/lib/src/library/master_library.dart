import 'dart:io';

import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:sqlite3/sqlite3.dart';

/// Standard subfolders of one master library.
enum LibraryFolder {
  /// SQLite database files.
  db('db'),

  /// Original child photos (referenced by relative path only).
  photos('photos'),

  /// Generated story illustrations (referenced by relative path only).
  illustrations('illustrations'),

  /// Finished exports such as PDFs or EPUBs.
  exports('exports');

  const LibraryFolder(this.folderName);

  /// Folder name as it appears under the library root.
  final String folderName;
}

/// Owns the master library on disk: folder skeleton plus SQLite database.
///
/// The library is the durable heart of the bridge. All structured data lives
/// in `db/master.db`; binary assets always live in their folders and are
/// referenced by stable ids and relative paths, never stored as blobs.
class MasterLibrary {
  /// Prepares an unopened library rooted at [rootPath].
  ///
  /// Call [initialize] before using [database].
  MasterLibrary({required this.rootPath});

  /// Schema version implemented by this build of the bridge.
  static const int currentSchemaVersion = 2;

  /// Absolute or relative root folder of this library.
  final String rootPath;

  Database? _database;

  /// Whether [initialize] has completed successfully and not been closed.
  bool get isInitialized => _database != null;

  /// The opened SQLite database.
  ///
  /// Throws a [StateError] when the library is not initialized.
  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError(
        'Master library is not initialized. Call initialize() first.',
      );
    }
    return db;
  }

  /// Absolute path of [folder] under the library root.
  String folderPath(LibraryFolder folder) =>
      joinPath(rootPath, folder.folderName);

  /// Absolute path of the SQLite database file.
  String get databaseFilePath =>
      joinPath(folderPath(LibraryFolder.db), 'master.db');

  /// Creates the folder skeleton, opens the database, and migrates the
  /// schema to the newest version.
  ///
  /// Safe to call repeatedly: existing folders are kept and already-applied
  /// schema versions are skipped, so a second startup on an initialized
  /// library changes nothing. Migration is stepped, so a library created by
  /// an older build is upgraded in place without losing rows. Throws when
  /// folders cannot be created, the database cannot be opened, or its schema
  /// is newer than supported.
  Future<void> initialize() async {
    _database?.dispose();
    _database = null;
    for (final folder in LibraryFolder.values) {
      await Directory(folderPath(folder)).create(recursive: true);
    }
    final opened = sqlite3.open(databaseFilePath);
    try {
      opened.execute('PRAGMA journal_mode = WAL;');
      opened.execute('PRAGMA foreign_keys = ON;');
      opened.execute('PRAGMA busy_timeout = 3000;');
      _migrate(opened);
    } catch (error) {
      opened.dispose();
      rethrow;
    }
    _database = opened;
  }

  /// Closes the database. Idempotent; further use requires [initialize].
  void close() {
    _database?.dispose();
    _database = null;
  }

  void _migrate(Database db) {
    final appliedAt = DateTime.now().toUtc().toIso8601String();
    runInDatabaseTransaction(db, () {
      db.execute(
        'CREATE TABLE IF NOT EXISTS schema_version ('
        ' version INTEGER PRIMARY KEY,'
        ' applied_at_utc TEXT NOT NULL)',
      );
      final rows = db.select(
        'SELECT MAX(version) AS version FROM schema_version',
      );
      final Object? rawVersion = rows.first['version'];
      final int currentVersion = rawVersion is int ? rawVersion : 0;
      if (currentVersion > currentSchemaVersion) {
        throw StateError(
          'Master library schema version $currentVersion is newer than '
          'the maximum supported version $currentSchemaVersion.',
        );
      }
      if (currentVersion == currentSchemaVersion) {
        return;
      }
      for (final step in schemaSteps.entries) {
        if (step.key <= currentVersion) {
          continue;
        }
        for (final statement in step.value) {
          db.execute(statement);
        }
      }
      // One row always describes the schema actually on disk, so a migrated
      // library is indistinguishable from a freshly created one.
      db.execute('DELETE FROM schema_version');
      db.execute(
        'INSERT INTO schema_version (version, applied_at_utc) VALUES (?, ?)',
        <Object?>[currentSchemaVersion, appliedAt],
      );
    });
  }
}

/// DDL of every schema version, keyed by the version it produces.
///
/// Applied in ascending key order, skipping versions a library already has,
/// which is what makes migration of an existing library additive.
const Map<int, List<String>> schemaSteps = <int, List<String>>{
  1: schemaV1Statements,
  2: schemaV2Statements,
};

/// Ordered DDL statements that build schema version 1.
///
/// Kept public so tools (and tests) can inspect exactly what a fresh library
/// contains without opening one.
const List<String> schemaV1Statements = <String>[
  '''
  CREATE TABLE IF NOT EXISTS profiles (
    id TEXT PRIMARY KEY,
    display_name TEXT NOT NULL,
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS stories (
    id TEXT PRIMARY KEY,
    profile_id TEXT NOT NULL REFERENCES profiles(id),
    title TEXT NOT NULL,
    language_code TEXT NOT NULL DEFAULT 'en',
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS story_pages (
    id TEXT PRIMARY KEY,
    story_id TEXT NOT NULL REFERENCES stories(id),
    page_index INTEGER NOT NULL CHECK (page_index >= 0),
    prose TEXT NOT NULL,
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL,
    UNIQUE(story_id, page_index)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS illustrations (
    id TEXT PRIMARY KEY,
    story_page_id TEXT NOT NULL REFERENCES story_pages(id),
    relative_path TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'pending',
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS devices (
    id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    revoked_at_utc TEXT,
    created_at_utc TEXT NOT NULL,
    updated_at_utc TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS deletion_records (
    id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    requested_by_device_id TEXT,
    deleted_at_utc TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS sync_state (
    device_id TEXT PRIMARY KEY REFERENCES devices(id),
    last_synced_at_utc TEXT,
    updated_at_utc TEXT NOT NULL
  )
  ''',
];

/// Ordered DDL statements that upgrade schema version 1 to version 2.
///
/// Version 2 adds the English scene description a page was generated with.
/// It was previously returned to the generating device and then dropped, so a
/// second device downloading the same story through `/sync` could not see it;
/// the illustration milestone needs it on every device. Additive and
/// defaulted, so migrating an existing library keeps every stored row.
const List<String> schemaV2Statements = <String>[
  '''
  ALTER TABLE story_pages
    ADD COLUMN scene_description TEXT NOT NULL DEFAULT ''
  ''',
];
