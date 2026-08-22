import 'dart:io';

import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:test/test.dart';

void main() {
  test('initialize creates folder skeleton and v1 schema', () async {
    final root = await Directory.systemTemp.createTemp('iam_hero_bridge_lib');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final library = MasterLibrary(
      rootPath: '${root.path}${Platform.pathSeparator}library',
    );

    await library.initialize();
    addTearDown(library.close);

    for (final folder in LibraryFolder.values) {
      expect(
        Directory(library.folderPath(folder)).existsSync(),
        isTrue,
        reason: 'folder ${folder.folderName} must be created',
      );
    }
    expect(File(library.databaseFilePath).existsSync(), isTrue);

    final tables = library.database
        .select("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row['name'] as String)
        .toSet();
    const expectedTables = <String>{
      'schema_version',
      'profiles',
      'stories',
      'story_pages',
      'illustrations',
      'devices',
      'deletion_records',
      'sync_state',
    };
    expect(tables, containsAllInOrder(expectedTables));

    final versions = library.database.select(
      'SELECT version FROM schema_version',
    );
    expect(versions, hasLength(1));
    expect(versions.first['version'], MasterLibrary.currentSchemaVersion);
  });

  test('a second initialize on the same library changes nothing', () async {
    final root = await Directory.systemTemp.createTemp('iam_hero_bridge_lib');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final library = MasterLibrary(
      rootPath: '${root.path}${Platform.pathSeparator}library',
    );
    await library.initialize();
    addTearDown(library.close);

    library.database.execute(
      'INSERT INTO profiles (id, display_name, created_at_utc, updated_at_utc) '
      'VALUES (?, ?, ?, ?)',
      <Object?>[
        'p-1',
        'Child A',
        '2026-01-01T00:00:00Z',
        '2026-01-01T00:00:00Z',
      ],
    );

    await library.initialize();

    final versions = library.database.select(
      'SELECT version FROM schema_version',
    );
    expect(
      versions,
      hasLength(1),
      reason: 'idempotent migration must not re-insert schema_version',
    );
    final profiles = library.database.select('SELECT * FROM profiles');
    expect(profiles, hasLength(1));
    expect(profiles.first['display_name'], 'Child A');
  });
}
