import 'dart:io';

import 'package:iam_hero_bridge/src/common/image_bytes.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Marks the illustration of page [pageNumber] of [storyId] as [status].
void _markIllustration(
  TestServer testServer,
  String storyId,
  int pageNumber,
  String status,
) {
  testServer.library.database.execute(
    'UPDATE illustrations SET status = ? WHERE story_page_id = '
    '(SELECT id FROM story_pages WHERE story_id = ? AND page_index = ?)',
    <Object?>[status, storyId, pageNumber - 1],
  );
}

void main() {
  group('GET /profiles', () {
    test('lists every child with photo presence and story count', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      seedStory(
        testServer.library,
        title: 'A Lantern by the Sea',
        writtenAtUtc: DateTime.utc(2026, 8, 1),
      );
      seedStory(
        testServer.library,
        title: 'The Second Lantern',
        writtenAtUtc: DateTime.utc(2026, 8, 2),
      );
      seedStory(
        testServer.library,
        profileId: 'profile-2',
        heroName: 'Adam',
        title: 'The Quiet Mountain',
        writtenAtUtc: DateTime.utc(2026, 8, 3),
      );
      await callRaw(
        testServer.handler,
        'PUT',
        '/profiles/profile-1/photo',
        headers: <String, String>{
          ...authHeaders(token),
          'content-type': ReferenceImageFormat.png.contentType,
        },
        body: onePixelPngBytes(),
      );

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/profiles',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      final profiles = body['profiles']! as List<Object?>;
      expect(profiles, hasLength(2));
      final first = profiles.first! as Map<String, Object?>;
      expect(first['id'], 'profile-1');
      expect(first['displayName'], 'Nour');
      expect(first['hasPhoto'], isTrue);
      expect(first['storyCount'], 2);
      expect(first['createdAtUtc'], isA<String>());
      expect(first['updatedAtUtc'], isA<String>());

      final second = profiles[1]! as Map<String, Object?>;
      expect(second['id'], 'profile-2');
      expect(second['hasPhoto'], isFalse);
      expect(second['storyCount'], 1);

      expect(
        body.toString(),
        isNot(contains('Distinctive page prose')),
        reason: 'a profile listing must never carry page prose',
      );
    });

    test('answers an empty list for an empty library', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/profiles',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      expect(body['profiles'], isEmpty);
    });

    test('refuses an unauthenticated call', () async {
      final testServer = await createTestServer();
      addTearDown(testServer.close);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/profiles',
      );

      expect(status, 401);
      expect(errorCode(body), 'unauthorized');
    });
  });

  group('GET /stories', () {
    test('lists titles, page counts and an illustration tally', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final story = seedStory(testServer.library, pageCount: 3);
      _markIllustration(testServer, story.id, 1, completedIllustrationStatus);
      _markIllustration(testServer, story.id, 2, failedIllustrationStatus);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      final stories = body['stories']! as List<Object?>;
      expect(stories, hasLength(1));
      final listed = stories.single! as Map<String, Object?>;
      expect(listed['id'], story.id);
      expect(listed['profileId'], 'profile-1');
      expect(listed['title'], 'A Lantern by the Sea');
      expect(listed['languageCode'], 'en');
      expect(listed['pageCount'], 3);
      expect(listed['illustrations'], <String, Object?>{
        'pending': 1,
        'completed': 1,
        'failed': 1,
      });
      expect(listed.containsKey('pages'), isFalse);
      expect(
        body.toString(),
        isNot(contains('Distinctive page prose')),
        reason: 'a story listing is a table of contents, not the book',
      );
    });

    test('a story with no illustration rows tallies zeroes', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final story = seedStory(testServer.library, pageCount: 2);
      testServer.library.database.execute(
        'DELETE FROM illustrations WHERE story_page_id IN '
        '(SELECT id FROM story_pages WHERE story_id = ?)',
        <Object?>[story.id],
      );

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      final listed =
          (body['stories']! as List<Object?>).single! as Map<String, Object?>;
      expect(listed['pageCount'], 2);
      expect(listed['illustrations'], <String, Object?>{
        'pending': 0,
        'completed': 0,
        'failed': 0,
      });
    });

    test('the profileId filter narrows the listing to one shelf', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final hers = seedStory(
        testServer.library,
        pageCount: 2,
        writtenAtUtc: DateTime.utc(2026, 8, 1),
      );
      final his = seedStory(
        testServer.library,
        profileId: 'profile-2',
        heroName: 'Adam',
        title: 'The Quiet Mountain',
        pageCount: 2,
        writtenAtUtc: DateTime.utc(2026, 8, 2),
      );
      _markIllustration(testServer, his.id, 1, completedIllustrationStatus);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories?profileId=profile-2',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      final stories = body['stories']! as List<Object?>;
      expect(stories, hasLength(1));
      final listed = stories.single! as Map<String, Object?>;
      expect(listed['id'], his.id);
      expect(listed['illustrations'], <String, Object?>{
        'pending': 1,
        'completed': 1,
        'failed': 0,
      });
      expect(
        body.toString(),
        isNot(contains(hers.id)),
        reason: 'the other child\'s shelf must not leak through the filter',
      );
    });

    test('a profileId naming no profile is a 400 naming the field', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories?profileId=profile-404',
        headers: authHeaders(token),
      );

      expect(status, 400);
      expect(errorCode(body), 'invalid_field');
      final message = (body['error']! as Map<String, Object?>)['message']!;
      expect(message, contains('profileId'));
      expect(
        message,
        isNot(contains('profile-404')),
        reason: 'a refusal names the parameter, never the value',
      );
    });

    test('a blank profileId is refused rather than ignored', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories?profileId=',
        headers: authHeaders(token),
      );

      expect(status, 400);
      expect(errorCode(body), 'invalid_field');
    });

    test('an unknown query parameter is refused by name', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories?profileID=profile-1',
        headers: authHeaders(token),
      );

      expect(status, 400);
      expect(errorCode(body), 'invalid_field');
      expect(
        (body['error']! as Map<String, Object?>)['message'],
        contains('profileID'),
      );
    });

    test('refuses an unauthenticated call', () async {
      final testServer = await createTestServer();
      addTearDown(testServer.close);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories',
      );

      expect(status, 401);
      expect(errorCode(body), 'unauthorized');
    });

    test('does not shadow the story generation or job endpoints', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final (jobStatus, jobBody) = await callJson(
        testServer.handler,
        'GET',
        '/stories/jobs/never-existed',
        headers: authHeaders(token),
      );
      expect(
        errorCode(jobBody),
        'job_not_found',
        reason:
            'GET /stories/<storyId> must not swallow GET /stories/jobs/<id>',
      );
      expect(jobStatus, 404);
    });
  });

  group('GET /stories/<storyId>', () {
    test('answers exactly what the sync download answers', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final story = seedStory(testServer.library, pageCount: 2);
      _markIllustration(testServer, story.id, 1, completedIllustrationStatus);

      final (managementStatus, managementBody) = await callJson(
        testServer.handler,
        'GET',
        '/stories/${story.id}',
        headers: authHeaders(token),
      );
      final (syncStatus, syncBody) = await callJson(
        testServer.handler,
        'GET',
        '/sync/stories/${story.id}',
        headers: authHeaders(token),
      );

      expect(managementStatus, 200, reason: 'body was $managementBody');
      expect(syncStatus, 200);
      expect(
        managementBody,
        syncBody,
        reason: 'one story has one shape, whoever asked for it',
      );
      final read = managementBody['story']! as Map<String, Object?>;
      expect(read['id'], story.id);
      final pages = read['pages']! as List<Object?>;
      expect(pages, hasLength(2));
      expect(
        (pages.first! as Map<String, Object?>)['illustrationStatus'],
        completedIllustrationStatus,
      );
    });

    test('an unknown story id answers a typed 404', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories/never-existed',
        headers: authHeaders(token),
      );

      expect(status, 404);
      expect(errorCode(body), 'story_not_found');
    });

    test('refuses an unauthenticated call', () async {
      final testServer = await createTestServer();
      addTearDown(testServer.close);
      final story = seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/stories/${story.id}',
      );

      expect(status, 401);
      expect(errorCode(body), 'unauthorized');
    });
  });

  group('DELETE /profiles/<profileId>', () {
    test('removes the child, every book, every file and no more', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final doomedFirst = seedStory(testServer.library, pageCount: 2);
      final doomedSecond = seedStory(
        testServer.library,
        title: 'The Second Lantern',
        pageCount: 2,
      );
      final kept = seedStory(
        testServer.library,
        profileId: 'profile-2',
        heroName: 'Adam',
        title: 'The Quiet Mountain',
        pageCount: 2,
      );
      for (final page in <GeneratedStoryPage>[
        ...doomedFirst.pages,
        ...doomedSecond.pages,
        ...kept.pages,
      ]) {
        await writeLibraryFile(
          testServer.library,
          page.illustrationRelativePath,
          <int>[1, 2, 3],
        );
      }
      await callRaw(
        testServer.handler,
        'PUT',
        '/profiles/profile-1/photo',
        headers: <String, String>{
          ...authHeaders(token),
          'content-type': ReferenceImageFormat.png.contentType,
        },
        body: onePixelPngBytes(),
      );
      await callRaw(
        testServer.handler,
        'PUT',
        '/profiles/profile-2/photo',
        headers: <String, String>{
          ...authHeaders(token),
          'content-type': ReferenceImageFormat.png.contentType,
        },
        body: onePixelPngBytes(),
      );

      final (status, body) = await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/profile-1',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      expect(body['profileId'], 'profile-1');
      expect(body['deletedStoryCount'], 2);
      expect(body['deletedPageCount'], 4);
      expect(body['deletedIllustrationCount'], 4);
      expect(body['removedFileCount'], 4);
      expect(body['photoRemoved'], isTrue);

      expect(testServer.countRows('profiles'), 1, reason: 'only the other');
      expect(testServer.countRows('stories'), 1);
      expect(testServer.countRows('story_pages'), 2);
      expect(
        testServer.countRows('illustrations'),
        2,
        reason: 'no orphan illustration row may survive its story',
      );
      expect(
        testServer.countRows('deletion_records'),
        2,
        reason: 'one record per deleted story, so devices learn about each',
      );

      expect(
        await listLibraryFiles(testServer.library),
        <String>[
          ...kept.pages.map((page) => page.illustrationRelativePath),
          'photos/profile-2.png',
        ]..sort(),
        reason: 'only the deleted child\'s files may disappear',
      );
      expect(
        Directory(
          joinPath(
            testServer.library.rootPath,
            toPlatformRelativePath('illustrations/${doomedFirst.id}'),
          ),
        ).existsSync(),
        isFalse,
        reason: 'the emptied story folders are pruned',
      );
    });

    test('paired devices learn about it from the next manifest', () async {
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

      await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/profile-1',
        headers: authHeaders(phoneToken),
      );

      final (status, manifest) = await callJson(
        testServer.handler,
        'GET',
        '/sync/manifest',
        headers: authHeaders(tabletToken),
      );

      expect(status, 200, reason: 'body was $manifest');
      expect(manifest['profiles'], isEmpty);
      expect(manifest['stories'], isEmpty);
      final deletions = manifest['deletions']! as List<Object?>;
      expect(deletions, hasLength(1));
      final deletion = deletions.single! as Map<String, Object?>;
      expect(deletion['entityType'], 'story');
      expect(deletion['entityId'], story.id);
    });

    test('a profile with no stories is still deletable', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final story = seedStory(testServer.library);
      await callJson(
        testServer.handler,
        'POST',
        '/stories/${story.id}/delete',
        headers: authHeaders(token),
      );

      final (status, body) = await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/profile-1',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      expect(body['deletedStoryCount'], 0);
      expect(body['photoRemoved'], isFalse);
      expect(testServer.countRows('profiles'), 0);
      expect(
        testServer.countRows('deletion_records'),
        1,
        reason: 'the story\'s own record stands; the profile adds none',
      );
    });

    test('an unknown profile id answers the app\'s typed 404', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/never-existed',
        headers: authHeaders(token),
      );

      expect(status, 404);
      expect(errorCode(body), 'profile_not_found');
      expect(testServer.countRows('profiles'), 1);
      expect(testServer.countRows('stories'), 1);
    });

    test(
      'deleting the same profile twice answers 404 the second time',
      () async {
        final printedCodes = <String>[];
        final testServer = await createTestServer(notifyCode: printedCodes.add);
        addTearDown(testServer.close);
        final token = await pairDevice(testServer, printedCodes);
        seedStory(testServer.library);

        final (firstStatus, _) = await callJson(
          testServer.handler,
          'DELETE',
          '/profiles/profile-1',
          headers: authHeaders(token),
        );
        final (secondStatus, secondBody) = await callJson(
          testServer.handler,
          'DELETE',
          '/profiles/profile-1',
          headers: authHeaders(token),
        );

        expect(firstStatus, 200);
        expect(secondStatus, 404);
        expect(errorCode(secondBody), 'profile_not_found');
      },
    );

    test('a malformed profile id is unknown, not invalid', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/not%20a%20profile',
        headers: authHeaders(token),
      );

      expect(status, 404);
      expect(errorCode(body), 'profile_not_found');
      expect(testServer.countRows('profiles'), 1);
    });

    test('refuses an unauthenticated call and changes nothing', () async {
      final testServer = await createTestServer();
      addTearDown(testServer.close);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/profile-1',
      );

      expect(status, 401);
      expect(errorCode(body), 'unauthorized');
      expect(testServer.countRows('profiles'), 1);
      expect(testServer.countRows('stories'), 1);
      expect(testServer.countRows('story_pages'), 2);
      expect(testServer.countRows('illustrations'), 2);
      expect(testServer.countRows('deletion_records'), 0);
    });

    test('does not shadow the reference photo delete', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library);

      final (status, body) = await callJson(
        testServer.handler,
        'DELETE',
        '/profiles/profile-1/photo',
        headers: authHeaders(token),
      );

      expect(status, 200, reason: 'body was $body');
      expect(body['removed'], isFalse);
      expect(
        testServer.countRows('profiles'),
        1,
        reason: 'deleting a photo must never delete the child',
      );
    });
  });
}
