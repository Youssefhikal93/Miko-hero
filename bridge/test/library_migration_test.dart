import 'dart:io';

import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('an existing v1 library migrates forward without losing rows', () async {
    final root = await createTempRoot();
    final library = MasterLibrary(
      rootPath: '${root.path}${Platform.pathSeparator}library',
    );
    await Directory(
      library.folderPath(LibraryFolder.db),
    ).create(recursive: true);

    // Build exactly what an older build left on disk: version 1 DDL only.
    final old = sqlite3.open(library.databaseFilePath);
    old.execute(
      'CREATE TABLE IF NOT EXISTS schema_version ('
      ' version INTEGER PRIMARY KEY, applied_at_utc TEXT NOT NULL)',
    );
    for (final statement in schemaV1Statements) {
      old.execute(statement);
    }
    old.execute(
      'INSERT INTO schema_version (version, applied_at_utc) VALUES (1, ?)',
      <Object?>['2026-07-01T00:00:00.000Z'],
    );
    old.execute(
      'INSERT INTO profiles (id, display_name, created_at_utc, updated_at_utc) '
      "VALUES ('profile-1', 'Nour', '2026-07-01T00:00:00.000Z', "
      "'2026-07-01T00:00:00.000Z')",
    );
    old.execute(
      'INSERT INTO stories '
      '(id, profile_id, title, language_code, created_at_utc, updated_at_utc) '
      "VALUES ('story-1', 'profile-1', 'An Older Story', 'ar', "
      "'2026-07-01T00:00:00.000Z', '2026-07-01T00:00:00.000Z')",
    );
    old.execute(
      'INSERT INTO story_pages '
      '(id, story_id, page_index, prose, created_at_utc, updated_at_utc) '
      "VALUES ('page-1', 'story-1', 0, 'Prose written before the upgrade', "
      "'2026-07-01T00:00:00.000Z', '2026-07-01T00:00:00.000Z')",
    );
    old.execute(
      'INSERT INTO devices '
      '(id, device_name, token_hash, revoked_at_utc, created_at_utc, '
      'updated_at_utc) '
      "VALUES ('device-1', 'Older tablet', 'deadbeef', NULL, "
      "'2026-07-01T00:00:00.000Z', '2026-07-01T00:00:00.000Z')",
    );
    old.dispose();

    await library.initialize();
    addTearDown(library.close);

    final versions = library.database.select(
      'SELECT version FROM schema_version',
    );
    expect(versions, hasLength(1), reason: 'one row describes the schema');
    expect(versions.first['version'], MasterLibrary.currentSchemaVersion);

    final pages = library.database.select('SELECT * FROM story_pages');
    expect(pages, hasLength(1), reason: 'migration must not drop rows');
    expect(pages.first['prose'], 'Prose written before the upgrade');
    expect(
      pages.first['scene_description'],
      '',
      reason: 'the added column defaults for rows that predate it',
    );
    expect(
      library.database.select('SELECT title FROM stories').first['title'],
      'An Older Story',
    );

    final devices = library.database.select('SELECT * FROM devices');
    expect(devices, hasLength(1), reason: 'migration must not drop devices');
    expect(devices.first['device_name'], 'Older tablet');
    expect(
      devices.first['last_seen_at_utc'],
      isNull,
      reason: 'a device that predates last-seen has not been seen',
    );

    // A second startup on the migrated library must be a no-op.
    await library.initialize();
    expect(
      library.database.select('SELECT version FROM schema_version'),
      hasLength(1),
    );
    expect(library.database.select('SELECT * FROM story_pages'), hasLength(1));
  });

  test('an existing v2 library gains last-seen without losing rows', () async {
    final root = await createTempRoot();
    final library = MasterLibrary(
      rootPath: '${root.path}${Platform.pathSeparator}library',
    );
    await Directory(
      library.folderPath(LibraryFolder.db),
    ).create(recursive: true);

    // Build exactly what the previous build left on disk: v1 plus v2 DDL.
    final old = sqlite3.open(library.databaseFilePath);
    old.execute(
      'CREATE TABLE IF NOT EXISTS schema_version ('
      ' version INTEGER PRIMARY KEY, applied_at_utc TEXT NOT NULL)',
    );
    for (final statement in <String>[
      ...schemaV1Statements,
      ...schemaV2Statements,
    ]) {
      old.execute(statement);
    }
    old.execute(
      'INSERT INTO schema_version (version, applied_at_utc) VALUES (2, ?)',
      <Object?>['2026-08-01T00:00:00.000Z'],
    );
    old.execute(
      'INSERT INTO devices '
      '(id, device_name, token_hash, revoked_at_utc, created_at_utc, '
      'updated_at_utc) '
      "VALUES ('device-2', 'Family tablet', 'cafebabe', NULL, "
      "'2026-08-01T00:00:00.000Z', '2026-08-01T00:00:00.000Z')",
    );
    old.dispose();

    await library.initialize();
    addTearDown(library.close);

    expect(
      library.database
          .select('SELECT version FROM schema_version')
          .first['version'],
      3,
    );
    final devices = library.database.select('SELECT * FROM devices');
    expect(devices, hasLength(1));
    expect(devices.first['device_name'], 'Family tablet');
    expect(devices.first['token_hash'], 'cafebabe');
    expect(devices.first['last_seen_at_utc'], isNull);
  });
}
