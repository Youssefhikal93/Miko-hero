import 'dart:convert';

import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  test('the manifest lists profiles, stories, slots and no prose', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final first = seedStory(
      testServer.library,
      profileId: 'profile-1',
      heroName: 'Nour',
      title: 'A Lantern by the Sea',
      pageCount: 2,
    );
    final second = seedStory(
      testServer.library,
      profileId: 'profile-2',
      heroName: 'Adam',
      title: 'The Quiet Mountain',
      pageCount: 3,
    );

    final (status, body) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(token),
    );

    expect(status, 200, reason: 'body was $body');
    expect(body['lastSyncedAtUtc'], isNull, reason: 'first sync ever');
    expect(DateTime.parse(body['generatedAtUtc']! as String), isA<DateTime>());

    final profiles = body['profiles']! as List<Object?>;
    expect(
      profiles.map((entry) => (entry! as Map<String, Object?>)['id']),
      containsAll(<String>['profile-1', 'profile-2']),
    );
    expect(
      profiles
          .map((entry) => (entry! as Map<String, Object?>)['displayName'])
          .toSet(),
      <String>{'Nour', 'Adam'},
    );

    final stories = body['stories']! as List<Object?>;
    expect(stories, hasLength(2));
    final byId = <String, Map<String, Object?>>{
      for (final entry in stories)
        (entry! as Map<String, Object?>)['id']! as String:
            entry as Map<String, Object?>,
    };
    expect(byId[first.id]!['title'], 'A Lantern by the Sea');
    expect(byId[first.id]!['pageCount'], 2);
    expect(byId[first.id]!['profileId'], 'profile-1');
    expect(byId[first.id]!['languageCode'], 'en');
    expect(byId[second.id]!['pageCount'], 3);

    final slots = byId[second.id]!['illustrations']! as List<Object?>;
    expect(slots, hasLength(3));
    expect(
      slots.map((slot) => (slot! as Map<String, Object?>)['status']).toSet(),
      <String>{'pending'},
    );
    expect(
      slots
          .map((slot) => (slot! as Map<String, Object?>)['pageNumber'])
          .toList(),
      <int>[1, 2, 3],
      reason: 'illustration slots must be ordered by page',
    );
    expect(
      slots.map((slot) => (slot! as Map<String, Object?>)['id']).toSet(),
      second.pages.map((page) => page.illustrationId).toSet(),
    );

    expect(body['deletions'], isEmpty);
    expect(
      jsonEncode(body),
      isNot(contains('Distinctive page prose')),
      reason: 'the manifest is metadata only; prose never travels in it',
    );
    expect(jsonEncode(body), isNot(contains('A harbour at dusk')));
  });

  test('a story download matches the persisted content exactly', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    const arabicTitle = 'نور وفوانيس البحر';
    const arabicProse = 'حملت نور فانوسها الصغير إلى الشاطئ ';
    final stored = seedStory(
      testServer.library,
      title: arabicTitle,
      language: StoryLanguage.arabic,
      pageCount: 3,
      prosePrefix: arabicProse,
    );

    final (status, body) = await callJson(
      testServer.handler,
      'GET',
      '/sync/stories/${stored.id}',
      headers: authHeaders(token),
    );

    expect(status, 200, reason: 'body was $body');
    final story = body['story']! as Map<String, Object?>;
    expect(story['id'], stored.id);
    expect(story['profileId'], stored.profileId);
    expect(story['title'], arabicTitle);
    expect(story['languageCode'], 'ar');
    expect(story['createdAtUtc'], stored.createdAtUtc.toIso8601String());
    expect(story['updatedAtUtc'], stored.updatedAtUtc.toIso8601String());

    final pages = story['pages']! as List<Object?>;
    expect(pages, hasLength(3));
    for (var index = 0; index < pages.length; index++) {
      final page = pages[index]! as Map<String, Object?>;
      final expected = stored.pages[index];
      expect(page['id'], expected.id);
      expect(page['pageNumber'], index + 1);
      expect(
        page['text'],
        '$arabicProse${index + 1}',
        reason: 'Arabic prose must survive the round trip byte for byte',
      );
      expect(page['illustrationScene'], expected.illustrationScene);
      expect(page['illustrationId'], expected.illustrationId);
      expect(
        page['illustrationRelativePath'],
        expected.illustrationRelativePath,
      );
      expect(page['illustrationStatus'], 'pending');
    }
  });

  test('an unknown story id answers a typed 404', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (status, body) = await callJson(
      testServer.handler,
      'GET',
      '/sync/stories/no-such-story',
      headers: authHeaders(token),
    );

    expect(status, 404);
    expect(errorCode(body), 'story_not_found');
  });

  test('sync/complete upserts one row and returns the stored time', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (_, manifest) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(token),
    );
    final generatedAt = manifest['generatedAtUtc']! as String;

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/sync/complete',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'manifestGeneratedAtUtc': generatedAt,
      }),
    );
    expect(status, 200, reason: 'body was $body');
    expect(
      DateTime.parse(body['lastSyncedAtUtc']! as String),
      DateTime.parse(generatedAt),
    );
    expect(testServer.countRows('sync_state'), 1);

    final (_, secondManifest) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(token),
    );
    expect(
      DateTime.parse(secondManifest['lastSyncedAtUtc']! as String),
      DateTime.parse(generatedAt),
      reason: 'the manifest reports this device\'s own watermark',
    );

    final later = DateTime.parse(
      generatedAt,
    ).add(const Duration(minutes: 5)).toUtc();
    final (secondStatus, secondBody) = await callJson(
      testServer.handler,
      'POST',
      '/sync/complete',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'manifestGeneratedAtUtc': later.toIso8601String(),
      }),
    );
    expect(secondStatus, 200, reason: 'body was $secondBody');
    expect(DateTime.parse(secondBody['lastSyncedAtUtc']! as String), later);
    expect(
      testServer.countRows('sync_state'),
      1,
      reason: 'a second completion upserts rather than inserting',
    );

    final otherToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: 'Second tablet',
    );
    final (_, otherManifest) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(otherToken),
    );
    expect(
      otherManifest['lastSyncedAtUtc'],
      isNull,
      reason: 'the watermark is per device, never shared',
    );
  });

  test('a malformed sync/complete body is refused', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (status, body) = await callJson(
      testServer.handler,
      'POST',
      '/sync/complete',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'manifestGeneratedAtUtc': 'yesterday',
      }),
    );

    expect(status, 400);
    expect(errorCode(body), 'invalid_field');
    expect(testServer.countRows('sync_state'), 0);
  });

  test('a story edited after a sync shows a newer timestamp', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final stored = seedStory(
      testServer.library,
      writtenAtUtc: DateTime.utc(2026, 8, 1, 9),
    );

    final (_, firstManifest) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(token),
    );
    final generatedAt = firstManifest['generatedAtUtc']! as String;
    await callJson(
      testServer.handler,
      'POST',
      '/sync/complete',
      headers: authHeaders(token),
      body: jsonEncode(<String, Object?>{
        'manifestGeneratedAtUtc': generatedAt,
      }),
    );

    final editedAt = DateTime.parse(
      generatedAt,
    ).add(const Duration(hours: 1)).toUtc();
    testServer.library.database.execute(
      'UPDATE stories SET title = ?, updated_at_utc = ? WHERE id = ?',
      <Object?>['A Brighter Lantern', editedAt.toIso8601String(), stored.id],
    );

    final (status, secondManifest) = await callJson(
      testServer.handler,
      'GET',
      '/sync/manifest',
      headers: authHeaders(token),
    );
    expect(status, 200, reason: 'body was $secondManifest');
    final lastSynced = DateTime.parse(
      secondManifest['lastSyncedAtUtc']! as String,
    );
    final story =
        (secondManifest['stories']! as List<Object?>).single!
            as Map<String, Object?>;
    final updatedAt = DateTime.parse(story['updatedAtUtc']! as String);

    expect(
      updatedAt.isAfter(lastSynced),
      isTrue,
      reason: 'an edit after the recorded sync must be visible as newer',
    );
    expect(
      DateTime.parse(story['createdAtUtc']! as String).isBefore(lastSynced),
      isTrue,
      reason: 'the creation time did not move, so only the edit is new',
    );
    expect(story['title'], 'A Brighter Lantern');
  });

  test('every sync endpoint rejects unauthenticated calls', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);
    final stored = seedStory(testServer.library);

    for (final call in <(String, String, Object?)>[
      ('GET', '/sync/manifest', null),
      ('GET', '/sync/stories/${stored.id}', null),
      (
        'POST',
        '/sync/complete',
        jsonEncode(<String, Object?>{
          'manifestGeneratedAtUtc': '2026-08-22T10:00:00Z',
        }),
      ),
    ]) {
      final (method, path, body) = call;
      final (status, response) = await callJson(
        testServer.handler,
        method,
        path,
        body: body,
      );
      expect(status, 401, reason: '$method $path answered $response');
      expect(errorCode(response), 'unauthorized');
    }
    expect(testServer.countRows('sync_state'), 0);
  });
}
