import 'dart:io';

import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('an existing v1 library migrates to v2 without losing rows', () async {
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
    old.dispose();

    await library.initialize();
    addTearDown(library.close);

    final versions = library.database.select(
      'SELECT version FROM schema_version',
    );
    expect(versions, hasLength(1), reason: 'one row describes the schema');
    expect(versions.first['version'], 2);

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

    // A second startup on the migrated library must be a no-op.
    await library.initialize();
    expect(
      library.database.select('SELECT version FROM schema_version'),
      hasLength(1),
    );
    expect(library.database.select('SELECT * FROM story_pages'), hasLength(1));
  });
}
