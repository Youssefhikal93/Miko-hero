import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('deleting a story removes every row, file and nothing else', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final doomed = seedStory(testServer.library, pageCount: 2);
    final kept = seedStory(
      testServer.library,
      profileId: 'profile-2',
      heroName: 'Adam',
      title: 'The Quiet Mountain',
      pageCount: 2,
    );
    for (final page in doomed.pages) {
      await writeLibraryFile(
        testServer.library,
        page.illustrationRelativePath,
        <int>[1, 2, 3],
      );
    }
    for (final page in kept.pages) {
      await writeLibraryFile(
        testServer.library,
        page.illustrationRelativePath,
        <int>[4, 5, 6],
      );
    }
    await writeLibraryFile(
      testServer.library,
      'photos/profile-1/reference.jpg',
      <int>[7, 8, 9],
    );

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/stories/${doomed.id}/delete',
      headers: authHeaders(token),
    );

    expect(status, 200, reason: 'body was $body');
    expect(body['storyId'], doomed.id);
    expect(body['alreadyDeleted'], isFalse);
    expect(body['removedFileCount'], 2);

    expect(testServer.countRows('stories'), 1, reason: 'only the other story');
    expect(testServer.countRows('story_pages'), 2);
    expect(testServer.countRows('illustrations'), 2);
    expect(
      testServer.countRows('profiles'),
      2,
      reason: 'a story deletion never deletes a profile',
    );
    expect(testServer.countRows('deletion_records'), 1);

    final record = dumpTable(testServer.library, 'deletion_records').single;
    expect(record['entity_type'], 'story');
    expect(record['entity_id'], doomed.id);
    expect(record['requested_by_device_id'], isNotNull);

    expect(
      await listLibraryFiles(testServer.library),
      <String>[
        ...kept.pages.map((page) => page.illustrationRelativePath),
        'photos/profile-1/reference.jpg',
      ]..sort(),
      reason: 'only the deleted story\'s illustrations may disappear',
    );
    expect(
      Directory(
        joinPath(
          testServer.library.rootPath,
          toPlatformRelativePath('illustrations/${doomed.id}'),
        ),
      ).existsSync(),
      isFalse,
      reason: 'the emptied story folder is pruned',
    );

    final (downloadStatus, downloadBody) = await callJson(
      testServer.handler,
      'GET',
      '/sync/stories/${doomed.id}',
      headers: authHeaders(token),
    );
    expect(downloadStatus, 404);
    expect(errorCode(downloadBody), 'story_not_found');
  });

  test('deleting the same story twice is idempotent', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library);

    final (firstStatus, firstBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/${story.id}/delete',
      headers: authHeaders(token),
    );
    expect(firstStatus, 200, reason: 'body was $firstBody');
    expect(firstBody['alreadyDeleted'], isFalse);

    final (secondStatus, secondBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/${story.id}/delete',
      headers: authHeaders(token),
    );
    expect(secondStatus, 200, reason: 'body was $secondBody');
    expect(secondBody['alreadyDeleted'], isTrue);
    expect(
      secondBody['deletedAtUtc'],
      firstBody['deletedAtUtc'],
      reason: 'the original deletion time is reported, not a new one',
    );
    expect(
      testServer.countRows('deletion_records'),
      1,
      reason: 'a retry must not add a second deletion record',
    );
  });

  test('a story id that never existed answers a typed 404', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/stories/never-existed/delete',
      headers: authHeaders(token),
    );

    expect(status, 404);
    expect(errorCode(body), 'story_not_found');
    expect(testServer.countRows('deletion_records'), 0);
  });

  test('another device learns about the deletion from its manifest', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final phoneToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: 'Phone',
    );
    final tabletToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: 'Tablet',
    );
    final story = seedStory(testServer.library);

    final (_, tabletBefore) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(tabletToken),
    );
    expect((tabletBefore['stories']! as List<Object?>), hasLength(1));

    await callJson(
      testServer.handler,
      'POST',
      '/stories/${story.id}/delete',
      headers: authHeaders(phoneToken),
    );

    final (status, tabletAfter) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(tabletToken),
    );
    expect(status, 200, reason: 'body was $tabletAfter');
    expect(tabletAfter['stories'], isEmpty);
    final deletions = tabletAfter['deletions']! as List<Object?>;
    expect(deletions, hasLength(1));
    final deletion = deletions.single! as Map<String, Object?>;
    expect(deletion['entityType'], 'story');
    expect(deletion['entityId'], story.id);
    expect(
      deletion.containsKey('requestedByDeviceId'),
      isFalse,
      reason: 'which device deleted it is not another device\'s business',
    );
  });

  test('the delete endpoint rejects unauthenticated calls', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);
    final story = seedStory(testServer.library);

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/stories/${story.id}/delete',
    );

    expect(status, 401);
    expect(errorCode(body), 'unauthorized');
    expect(testServer.countRows('stories'), 1);
    expect(testServer.countRows('deletion_records'), 0);
  });

  test('the generation endpoints keep working next to delete', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/stories/generate',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'profileId': 'profile-1',
        'heroName': 'Nour',
        'ageYears': 6,
        'genderContext': 'girl',
        'languageCode': 'en',
        'theme': 'A lantern festival by the sea',
        'moral': 'Sharing a small light makes it bigger',
        'pageCount': 6,
        'illustrationStyle': 'pictureBook',
      }),
    );

    expect(
      status,
      202,
      reason:
          'the new /stories/<id>/delete route must not shadow '
          '/stories/generate; body was $body',
    );
  });
}
