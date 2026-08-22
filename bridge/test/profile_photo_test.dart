import 'dart:io';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/image_bytes.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Absolute path of one library-relative file.
String _libraryPath(TestServer testServer, String relativePath) {
  return joinPath(
    testServer.library.rootPath,
    toPlatformRelativePath(relativePath),
  );
}

void main() {
  test('a PNG reference photo is stored and can be replaced', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    seedStory(testServer.library, profileId: 'profile-1');
    final before = testServer.library.database.select(
      'SELECT updated_at_utc FROM profiles WHERE id = ?',
      <Object?>['profile-1'],
    ).single['updated_at_utc']!;

    final png = onePixelPngBytes();
    final response = await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/profile-1/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      body: png,
    );
    expect(response.statusCode, 200);
    final body = await readJsonBody(response);
    expect(body['profileId'], 'profile-1');
    expect(body['relativePath'], 'photos/profile-1.png');
    expect(body['contentType'], 'image/png');
    expect(body['sizeBytes'], png.length);

    final stored = File(_libraryPath(testServer, 'photos/profile-1.png'));
    expect(stored.existsSync(), isTrue);
    expect(stored.readAsBytesSync(), png);
    expect(
      testServer.library.database.select(
        'SELECT updated_at_utc FROM profiles WHERE id = ?',
        <Object?>['profile-1'],
      ).single['updated_at_utc'],
      isNot(before),
      reason: 'the profile row must move so the next sync notices',
    );

    // A JPEG upload replaces the PNG rather than leaving two photos behind.
    final jpeg = minimalJpegBytes();
    final replaced = await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/profile-1/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/jpeg',
      },
      body: jpeg,
    );
    expect(replaced.statusCode, 200);
    expect(
      (await readJsonBody(replaced))['relativePath'],
      'photos/profile-1.jpg',
    );
    expect(stored.existsSync(), isFalse, reason: 'one photo per profile');
    expect(
      File(_libraryPath(testServer, 'photos/profile-1.jpg')).existsSync(),
      isTrue,
    );
  });

  test('the declared type must match the bytes that arrive', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    seedStory(testServer.library, profileId: 'profile-1');

    final rejected = <String, (String, Object)>{
      'an unsupported content type': (
        'image/gif',
        Uint8List.fromList(<int>[0x47, 0x49, 0x46, 0x38]),
      ),
      'no content type at all': ('', onePixelPngBytes()),
      'a PNG announced as JPEG': ('image/jpeg', onePixelPngBytes()),
      'bytes that are no image': (
        'image/png',
        Uint8List.fromList(<int>[1, 2, 3, 4, 5, 6, 7, 8, 9]),
      ),
    };
    for (final entry in rejected.entries) {
      final (contentType, body) = entry.value;
      final response = await callRaw(
        testServer.handler,
        'PUT',
        '/profiles/profile-1/photo',
        headers: <String, String>{
          ...authHeaders(token),
          if (contentType.isNotEmpty)
            HttpHeaders.contentTypeHeader: contentType,
        },
        body: body,
      );
      expect(response.statusCode, 400, reason: '${entry.key} must be refused');
      expect(
        errorCode(await readJsonBody(response)),
        anyOf(ApiErrorCode.unsupportedImageType, ApiErrorCode.invalidImage),
      );
    }

    expect(
      Directory(
        joinPath(testServer.library.rootPath, 'photos'),
      ).listSync().whereType<File>(),
      isEmpty,
      reason: 'nothing rejected may reach the library',
    );
  });

  test('a photo over the 2 MB limit is refused with 413', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    seedStory(testServer.library, profileId: 'profile-1');

    final oversized = Uint8List(maxReferencePhotoBytes + 1024)
      ..setRange(0, pngMagicBytes.length, pngMagicBytes);
    final response = await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/profile-1/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      body: oversized,
    );

    expect(response.statusCode, 413);
    expect(errorCode(await readJsonBody(response)), ApiErrorCode.photoTooLarge);
    expect(
      File(_libraryPath(testServer, 'photos/profile-1.png')).existsSync(),
      isFalse,
    );
  });

  test('both photo endpoints answer 404 for an unknown profile', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final put = await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/nobody/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      body: onePixelPngBytes(),
    );
    expect(put.statusCode, 404);
    expect(errorCode(await readJsonBody(put)), ApiErrorCode.profileNotFound);

    final (deleteStatus, deleteBody) = await callJson(
      testServer.handler,
      'DELETE',
      '/profiles/nobody/photo',
      headers: authHeaders(token),
    );
    expect(deleteStatus, 404);
    expect(errorCode(deleteBody), ApiErrorCode.profileNotFound);

    // A path-traversing id names no profile either, and never reaches disk.
    final traversal = await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/..%2F..%2Fescape/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      body: onePixelPngBytes(),
    );
    expect(traversal.statusCode, 404);
  });

  test('deleting a photo removes the file and is idempotent', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    seedStory(testServer.library, profileId: 'profile-1');

    await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/profile-1/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/png',
      },
      body: onePixelPngBytes(),
    );
    expect(
      File(_libraryPath(testServer, 'photos/profile-1.png')).existsSync(),
      isTrue,
    );

    final (status, body) = await callJson(
      testServer.handler,
      'DELETE',
      '/profiles/profile-1/photo',
      headers: authHeaders(token),
    );
    expect(status, 200, reason: 'body was $body');
    expect(body['removed'], isTrue);
    expect(
      File(_libraryPath(testServer, 'photos/profile-1.png')).existsSync(),
      isFalse,
    );

    final (repeatStatus, repeatBody) = await callJson(
      testServer.handler,
      'DELETE',
      '/profiles/profile-1/photo',
      headers: authHeaders(token),
    );
    expect(repeatStatus, 200);
    expect(repeatBody['removed'], isFalse);
  });

  test('both photo endpoints require a device token', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);

    for (final method in <String>['PUT', 'DELETE']) {
      final anonymous = await callRaw(
        testServer.handler,
        method,
        '/profiles/profile-1/photo',
        headers: <String, String>{HttpHeaders.contentTypeHeader: 'image/png'},
        body: method == 'PUT' ? onePixelPngBytes() : null,
      );
      expect(anonymous.statusCode, 401, reason: '$method must require auth');
      expect(
        errorCode(await readJsonBody(anonymous)),
        ApiErrorCode.unauthorized,
      );

      final badToken = await callRaw(
        testServer.handler,
        method,
        '/profiles/profile-1/photo',
        headers: <String, String>{
          ...authHeaders('not-a-real-token'),
          HttpHeaders.contentTypeHeader: 'image/png',
        },
        body: method == 'PUT' ? onePixelPngBytes() : null,
      );
      expect(badToken.statusCode, 401);
      expect(
        errorCode(await readJsonBody(badToken)),
        ApiErrorCode.unauthorized,
      );
    }
  });

  test('the store finds a stored photo in either format', () async {
    final library = await createTempLibrary();
    seedStory(library, profileId: 'profile-7');
    final store = ProfilePhotoStore(library: library);
    expect(store.findPhoto('profile-7'), isNull);

    await store.savePhoto(
      profileId: 'profile-7',
      format: ReferenceImageFormat.jpeg,
      bytes: minimalJpegBytes(),
      nowUtc: DateTime.now().toUtc(),
    );

    final photo = store.findPhoto('profile-7');
    expect(photo, isNotNull);
    expect(photo!.fileName, 'profile-7.jpg');
    expect(photo.format, ReferenceImageFormat.jpeg);
    expect(await store.readPhotoBytes(photo), minimalJpegBytes());
    expect(
      () => store.savePhoto(
        profileId: 'ghost',
        format: ReferenceImageFormat.png,
        bytes: onePixelPngBytes(),
        nowUtc: DateTime.now().toUtc(),
      ),
      throwsA(isA<UnknownProfileException>()),
    );
  });
}
