import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/backup/backup_envelope.dart';
import 'package:iam_hero_bridge/src/backup/backup_errors.dart';
import 'package:iam_hero_bridge/src/backup/library_backup_payload.dart';
import 'package:iam_hero_bridge/src/backup/library_backup_service.dart';
import 'package:iam_hero_bridge/src/common/atomic_files.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

const String _password = 'lantern-by-the-sea';
const String _deviceToken = 'a-device-token-that-was-issued-once';

/// Tables whose rows must come back from a backup byte for byte.
const List<String> _comparedTables = <String>[
  'profiles',
  'stories',
  'story_pages',
  'illustrations',
  'deletion_records',
  'sync_state',
];

void main() {
  test('a backup restores into a second empty library completely', () async {
    final source = await _seededLibrary();
    final creation = await LibraryBackupService(library: source).createBackup(
      password: _password,
      nowUtc: DateTime.utc(2026, 8, 22, 10, 15, 30),
    );

    expect(creation.fileName, 'iam-hero-master-20260822T101530Z.ihmb');
    expect(creation.rowCount, greaterThan(0));
    expect(creation.fileCount, 2);
    final backupFile = File(_exportPath(source, creation.fileName));
    expect(backupFile.lengthSync(), creation.sizeBytes);

    final target = await createTempLibrary();
    await writeFileAtomic(
      _exportPath(target, creation.fileName),
      backupFile.readAsBytesSync(),
    );
    await writeLibraryFile(target, 'photos/stray/not-in-the-backup.jpg', <int>[
      0,
      1,
    ]);

    final restore = await LibraryBackupService(
      library: target,
    ).restoreBackup(fileName: creation.fileName, password: _password);

    expect(restore.restoredRowCount, creation.rowCount);
    expect(restore.restoredFileCount, 2);
    expect(restore.restoredDeviceCount, 1);
    expect(restore.toJson()['devicesMustRePair'], isTrue);

    for (final table in _comparedTables) {
      expect(
        dumpTable(target, table),
        dumpTable(source, table),
        reason: '$table must be identical after a restore',
      );
    }

    expect(
      _devicesWithoutTokenHash(target),
      _devicesWithoutTokenHash(source),
      reason: 'device names and dates survive',
    );
    expect(
      DeviceStore(
        library: source,
      ).findActiveByTokenHash(sha256Hex(_deviceToken)),
      isNotNull,
      reason: 'the original library can still authenticate that device',
    );
    expect(
      DeviceStore(
        library: target,
      ).findActiveByTokenHash(sha256Hex(_deviceToken)),
      isNull,
      reason: 'a restored device is a name only and must pair again',
    );

    final sourceFiles = await listLibraryFiles(source);
    expect(
      await listLibraryFiles(target),
      sourceFiles,
      reason:
          'a file the backup does not hold is not part of the library '
          'the backup describes, so a restore removes it',
    );
    for (final relativePath in sourceFiles) {
      expect(
        _readLibraryFile(target, relativePath),
        _readLibraryFile(source, relativePath),
        reason: '$relativePath must be restored byte for byte',
      );
    }
  });

  test(
    'wrong password, tampered bytes and foreign files are refused',
    () async {
      final library = await _seededLibraryWithoutFiles();
      final before = _snapshot(library);
      final service = LibraryBackupService(library: library);
      final creation = await service.createBackup(
        password: _password,
        nowUtc: DateTime.utc(2026, 8, 22, 11),
      );
      final path = _exportPath(library, creation.fileName);
      final original = File(path).readAsBytesSync();

      await expectLater(
        service.restoreBackup(
          fileName: creation.fileName,
          password: 'not-the-password',
        ),
        throwsA(_backupFailure(BackupFailureCode.authenticationFailed)),
      );

      final flippedCipherText = Uint8List.fromList(original);
      final cipherIndex = BackupEnvelope.headerLength + 4;
      flippedCipherText[cipherIndex] = flippedCipherText[cipherIndex] ^ 0x01;
      await writeFileAtomic(path, flippedCipherText);
      await expectLater(
        service.restoreBackup(fileName: creation.fileName, password: _password),
        throwsA(_backupFailure(BackupFailureCode.authenticationFailed)),
        reason: 'a single flipped bit must fail authentication',
      );

      final flippedHeader = Uint8List.fromList(original);
      flippedHeader[19] = flippedHeader[19] ^ 0x01;
      await writeFileAtomic(path, flippedHeader);
      await expectLater(
        service.restoreBackup(fileName: creation.fileName, password: _password),
        throwsA(_backupFailure(BackupFailureCode.authenticationFailed)),
        reason: 'the header is authenticated too, reserved bytes included',
      );

      await writeFileAtomic(
        path,
        utf8.encode(
          jsonEncode(<String, Object?>{
            'format': 'iam-hero-backup',
            'version': 1,
          }),
        ),
      );
      await expectLater(
        service.restoreBackup(fileName: creation.fileName, password: _password),
        throwsA(_backupFailure(BackupFailureCode.unreadable)),
        reason: 'an app backup file is not a master library backup',
      );

      final weakened = await BackupEnvelope.seal(
        payloadBytes: utf8.encode('{}'),
        password: _password,
        iterations: 1000,
      );
      await writeFileAtomic(path, weakened);
      await expectLater(
        service.restoreBackup(fileName: creation.fileName, password: _password),
        throwsA(_backupFailure(BackupFailureCode.unreadable)),
        reason: 'a file declaring a weakened key derivation is refused',
      );

      expect(
        _snapshot(library),
        before,
        reason: 'no failed restore may change a single row',
      );
    },
  );

  test('a payload from a newer bridge is refused', () async {
    final library = await _seededLibraryWithoutFiles();
    final before = _snapshot(library);
    const fileName = 'iam-hero-master-20260901T000000Z.ihmb';
    await writeFileAtomic(
      _exportPath(library, fileName),
      await BackupEnvelope.seal(
        payloadBytes: LibraryBackupPayload(
          payloadVersion: backupPayloadVersion + 1,
          createdAtUtc: DateTime.utc(2027),
          librarySchemaVersion: MasterLibrary.currentSchemaVersion,
          tables: const <String, List<Map<String, Object?>>>{},
          files: const <BackupFileEntry>[],
        ).toBytes(),
        password: _password,
      ),
    );

    await expectLater(
      LibraryBackupService(
        library: library,
      ).restoreBackup(fileName: fileName, password: _password),
      throwsA(_backupFailure(BackupFailureCode.unsupportedVersion)),
    );
    expect(_snapshot(library), before);
  });

  test('a restore that fails midway changes nothing at all', () async {
    final library = await _seededLibrary();
    final before = _snapshot(library);
    final filesBefore = <String, List<int>>{
      for (final path in await listLibraryFiles(library))
        path: _readLibraryFile(library, path),
    };

    // A structurally valid payload whose story points at a profile that is
    // not in the payload: every row inserts until the foreign key fires.
    const fileName = 'iam-hero-master-20260902T000000Z.ihmb';
    await writeFileAtomic(
      _exportPath(library, fileName),
      await BackupEnvelope.seal(
        payloadBytes: LibraryBackupPayload(
          payloadVersion: backupPayloadVersion,
          createdAtUtc: DateTime.utc(2026, 8, 22),
          librarySchemaVersion: MasterLibrary.currentSchemaVersion,
          tables: <String, List<Map<String, Object?>>>{
            'profiles': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'restored-profile',
                'display_name': 'Restored child',
                'created_at_utc': '2026-08-01T00:00:00.000Z',
                'updated_at_utc': '2026-08-01T00:00:00.000Z',
              },
            ],
            'stories': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'orphan-story',
                'profile_id': 'a-profile-that-is-not-in-this-backup',
                'title': 'Orphan',
                'language_code': 'en',
                'created_at_utc': '2026-08-01T00:00:00.000Z',
                'updated_at_utc': '2026-08-01T00:00:00.000Z',
              },
            ],
          },
          files: <BackupFileEntry>[
            BackupFileEntry(
              relativePath: 'photos/profile-1/reference.jpg',
              bytes: Uint8List.fromList(<int>[9, 9, 9, 9]),
            ),
          ],
        ).toBytes(),
        password: _password,
      ),
    );

    await expectLater(
      LibraryBackupService(
        library: library,
      ).restoreBackup(fileName: fileName, password: _password),
      throwsA(_backupFailure(BackupFailureCode.restoreFailed)),
    );

    expect(
      _snapshot(library),
      before,
      reason: 'the transaction rolled back, so every row is the original one',
    );
    expect(
      await listLibraryFiles(library),
      filesBefore.keys.toList(growable: false),
      reason: 'a failed restore leaves no staged file behind',
    );
    for (final entry in filesBefore.entries) {
      expect(
        _readLibraryFile(library, entry.key),
        entry.value,
        reason: '${entry.key} must still hold its original bytes',
      );
    }
  });

  test('a backup payload never carries a device token hash', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    seedStory(testServer.library);

    final creation = await LibraryBackupService(
      library: testServer.library,
    ).createBackup(password: _password, nowUtc: DateTime.utc(2026, 8, 22, 12));

    final payloadBytes = await BackupEnvelope.open(
      fileBytes: File(
        _exportPath(testServer.library, creation.fileName),
      ).readAsBytesSync(),
      password: _password,
    );
    final payloadText = utf8.decode(payloadBytes);

    expect(payloadText, isNot(contains(token)));
    expect(payloadText, isNot(contains(sha256Hex(token))));
    expect(payloadText, isNot(contains('token_hash')));

    final payload = LibraryBackupPayload.fromBytes(payloadBytes);
    final devices = payload.tables['devices']!;
    expect(devices, hasLength(1));
    expect(devices.single['device_name'], 'Family tablet');
    expect(devices.single.containsKey('token_hash'), isFalse);
  });

  test('the endpoints create and restore one backup over HTTP', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library);

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/library/backup',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{'password': _password}),
    );
    expect(status, 201, reason: 'body was $body');
    final fileName = body['fileName']! as String;
    expect(fileName, startsWith(backupFileNamePrefix));
    expect(fileName, endsWith(backupFileExtension));
    expect(body['sizeBytes'], isA<int>());
    expect(
      File(_exportPath(testServer.library, fileName)).existsSync(),
      isTrue,
      reason: 'the file stays on the PC; only its name travels',
    );

    // Prove the restore really replaces: drop the story first.
    await callJson(
      testServer.handler,
      'POST',
      '/stories/${story.id}/delete',
      headers: authHeaders(token),
    );
    expect(testServer.countRows('stories'), 0);

    final (restoreStatus, restoreBody) = await callJson(
      testServer.handler,
      'POST',
      '/library/restore',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'fileName': fileName,
        'password': _password,
      }),
    );
    expect(restoreStatus, 200, reason: 'body was $restoreBody');
    expect(restoreBody['devicesMustRePair'], isTrue);
    expect(testServer.countRows('stories'), 1);
    expect(
      testServer.countRows('deletion_records'),
      0,
      reason: 'the backup predates the deletion, so its record is gone too',
    );
    expect(
      DeviceStore(
        library: testServer.library,
      ).findActiveByTokenHash(sha256Hex(token)),
      isNull,
      reason: 'even the restoring device has to pair again',
    );
  });

  test('bad backup requests are refused with typed errors', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (shortStatus, shortBody) = await callJson(
      testServer.handler,
      'POST',
      '/library/backup',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{'password': 'short'}),
    );
    expect(shortStatus, 400);
    expect(errorCode(shortBody), 'backup_password_too_short');

    final (missingStatus, missingBody) = await callJson(
      testServer.handler,
      'POST',
      '/library/restore',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'fileName': 'iam-hero-master-20200101T000000Z.ihmb',
        'password': _password,
      }),
    );
    expect(missingStatus, 404);
    expect(errorCode(missingBody), 'backup_not_found');

    final (escapeStatus, escapeBody) = await callJson(
      testServer.handler,
      'POST',
      '/library/restore',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'fileName': '../db/master.db.ihmb',
        'password': _password,
      }),
    );
    expect(escapeStatus, 400);
    expect(errorCode(escapeBody), 'backup_invalid_file_name');

    final (kindStatus, kindBody) = await callJson(
      testServer.handler,
      'POST',
      '/library/restore',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'fileName': 'family-backup.json',
        'password': _password,
      }),
    );
    expect(kindStatus, 400);
    expect(
      errorCode(kindBody),
      'backup_invalid_file_name',
      reason: 'an app backup file can never be handed to the bridge',
    );
  });

  test('the backup endpoints reject unauthenticated calls', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);

    for (final path in <String>['/library/backup', '/library/restore']) {
      final (status, body) = await callJson(
        testServer.handler,
        'POST',
        path,
        body: jsonEncode(<String, Object?>{
          'password': _password,
          'fileName': 'iam-hero-master-20260822T100000Z.ihmb',
        }),
      );
      expect(status, 401, reason: '$path answered $body');
      expect(errorCode(body), 'unauthorized');
    }
    expect(
      Directory(
        testServer.library.folderPath(LibraryFolder.exports),
      ).listSync(),
      isEmpty,
      reason: 'an unauthenticated call must not write a backup',
    );
  });
}

/// A library holding one story, one device, one sync row, one deletion
/// record, one photo and one illustration file.
Future<MasterLibrary> _seededLibrary() async {
  final library = await _seededLibraryWithoutFiles();
  final story =
      library.database.select('SELECT id FROM stories LIMIT 1').first['id']!
          as String;
  await writeLibraryFile(library, 'photos/profile-1/reference.jpg', <int>[
    1,
    2,
    3,
    4,
  ]);
  await writeLibraryFile(library, 'illustrations/$story/0.png', <int>[
    5,
    6,
    7,
    8,
    9,
  ]);
  return library;
}

Future<MasterLibrary> _seededLibraryWithoutFiles() async {
  final library = await createTempLibrary();
  seedStory(library, pageCount: 2, writtenAtUtc: DateTime.utc(2026, 8, 1, 9));
  final device = DeviceStore(
    library: library,
  ).registerDevice(name: 'Family tablet', tokenHash: sha256Hex(_deviceToken));
  library.database.execute(
    'INSERT INTO sync_state (device_id, last_synced_at_utc, updated_at_utc) '
    'VALUES (?, ?, ?)',
    <Object?>[
      device.id,
      '2026-08-01T10:00:00.000Z',
      '2026-08-01T10:00:00.000Z',
    ],
  );
  library.database.execute(
    'INSERT INTO deletion_records '
    '(id, entity_type, entity_id, requested_by_device_id, deleted_at_utc) '
    'VALUES (?, ?, ?, ?, ?)',
    <Object?>[
      'deletion-1',
      'story',
      'a-story-deleted-earlier',
      device.id,
      '2026-08-02T10:00:00.000Z',
    ],
  );
  return library;
}

Map<String, List<Map<String, Object?>>> _snapshot(MasterLibrary library) {
  return <String, List<Map<String, Object?>>>{
    for (final table in <String>[..._comparedTables, 'devices'])
      table: dumpTable(library, table),
  };
}

List<Map<String, Object?>> _devicesWithoutTokenHash(MasterLibrary library) {
  return dumpTable(library, 'devices')
      .map(
        (row) => <String, Object?>{
          for (final entry in row.entries)
            if (entry.key != 'token_hash') entry.key: entry.value,
        },
      )
      .toList(growable: false);
}

String _exportPath(MasterLibrary library, String fileName) {
  return joinPath(library.folderPath(LibraryFolder.exports), fileName);
}

List<int> _readLibraryFile(MasterLibrary library, String relativePath) {
  return File(
    joinPath(library.rootPath, toPlatformRelativePath(relativePath)),
  ).readAsBytesSync();
}

Matcher _backupFailure(BackupFailureCode code) {
  return isA<BackupException>().having((error) => error.code, 'code', code);
}
