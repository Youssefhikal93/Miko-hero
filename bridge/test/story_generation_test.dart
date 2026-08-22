import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// Body of a valid `POST /stories/generate` request.
Map<String, Object?> generateRequestBody({
  String profileId = 'profile-1',
  String heroName = 'Nour',
  int ageYears = 6,
  String genderContext = 'girl',
  String languageCode = 'en',
  String theme = 'A lantern festival by the sea',
  String moral = 'Sharing a small light makes it bigger',
  int pageCount = 6,
  String illustrationStyle = 'pictureBook',
}) {
  return <String, Object?>{
    'profileId': profileId,
    'heroName': heroName,
    'ageYears': ageYears,
    'genderContext': genderContext,
    'languageCode': languageCode,
    'theme': theme,
    'moral': moral,
    'pageCount': pageCount,
    'illustrationStyle': illustrationStyle,
  };
}

/// A schema-valid model answer with [pageCount] pages.
///
/// [text] builds the prose of the one-based page number; [includeTitle] can
/// be turned off to reproduce the model's observed habit of dropping it.
String storyPayload({
  required int pageCount,
  String title = 'Nour and the Sea Lanterns',
  String Function(int pageNumber)? text,
  bool includeTitle = true,
}) {
  return jsonEncode(<String, Object?>{
    if (includeTitle) 'title': title,
    'pages': List<Object?>.generate(
      pageCount,
      (index) => <String, Object?>{
        'pageNumber': index + 1,
        'text':
            text?.call(index + 1) ??
            'Page ${index + 1}: Nour lit one small lantern and smiled.',
        'illustrationScene':
            'A child on a moonlit beach holding paper lantern '
            '${index + 1}.',
      },
    ),
  });
}

/// A fake Ollama call that blocks until released or cancelled.
///
/// It lets a test hold the single worker busy while it inspects the queue.
class _GatedOllamaCall {
  _GatedOllamaCall(this.payload);

  /// Answer returned once the call is released.
  final String payload;

  /// Completes as soon as the worker has entered the call.
  final Completer<void> started = Completer<void>();

  /// Completed by the test to let the call finish.
  final Completer<void> release = Completer<void>();

  /// The responder handed to [FakeOllamaStoryClient].
  Future<OllamaGenerateResponse> call(
    OllamaGenerateRequest request,
    CancellationToken cancellation,
  ) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await Future.any(<Future<void>>[
      release.future,
      cancellation.whenCancelled,
    ]);
    if (cancellation.isCancelled) {
      throw const GenerationException(
        GenerationFailureCode.cancelled,
        'The bridge aborted this call.',
      );
    }
    return ollamaEnvelope(payload);
  }
}

/// Starts one generation job and returns its id.
Future<String> startJob(
  TestServer testServer,
  String token, {
  Map<String, Object?>? body,
  int expectedQueuePosition = 1,
}) async {
  final (status, response) = await callJson(
    testServer.handler,
    'POST',
    '/stories/generate',
    headers: authHeaders(token),
    body: jsonEncode(body ?? generateRequestBody()),
  );
  expect(status, 202, reason: 'body was $response');
  expect(response['queuePosition'], expectedQueuePosition);
  return response['jobId']! as String;
}

/// Reads one job over HTTP.
Future<Map<String, Object?>> readJob(
  TestServer testServer,
  String token,
  String jobId,
) async {
  final (status, body) = await callJson(
    testServer.handler,
    'GET',
    '/stories/jobs/$jobId',
    headers: authHeaders(token),
  );
  expect(status, 200, reason: 'body was $body');
  return body;
}

void main() {
  for (final pageCount in <int>[6, 8, 10]) {
    test(
      'a $pageCount-page story is stored with pending illustrations',
      () async {
        final printedCodes = <String>[];
        final client = FakeOllamaStoryClient.answering(
          storyPayload(pageCount: pageCount),
        );
        final testServer = await createTestServer(
          ollamaClient: client,
          notifyCode: printedCodes.add,
        );
        addTearDown(testServer.close);
        final token = await pairDevice(testServer, printedCodes);

        final jobId = await startJob(
          testServer,
          token,
          body: generateRequestBody(pageCount: pageCount),
        );
        final settled = await testServer.server.generationQueue.whenSettled(
          jobId,
        );
        expect(settled.status, GenerationJobStatus.completed);

        final jobBody = await readJob(testServer, token, jobId);
        expect(jobBody['status'], 'completed');
        expect(
          jobBody.containsKey('queuePosition'),
          isFalse,
          reason: 'a finished job is not in line any more',
        );
        expect(
          jobBody.containsKey('request'),
          isFalse,
          reason: 'the request holds the child name and is never echoed',
        );

        final story = jobBody['story']! as Map<String, Object?>;
        expect(story['title'], 'Nour and the Sea Lanterns');
        expect(story['languageCode'], 'en');
        expect(story['profileId'], 'profile-1');
        final pages = story['pages']! as List<Object?>;
        expect(pages, hasLength(pageCount));
        for (var index = 0; index < pageCount; index++) {
          final page = pages[index]! as Map<String, Object?>;
          expect(page['pageNumber'], index + 1);
          expect(page['text'] as String, isNotEmpty);
          expect(page['illustrationScene'] as String, isNotEmpty);
          expect(page['illustrationId'] as String, isNotEmpty);
          expect(page['illustrationStatus'], 'pending');
          expect(
            page['illustrationRelativePath'],
            'illustrations/${story['id']}/$index.png',
          );
        }

        expect(testServer.countRows('profiles'), 1);
        expect(testServer.countRows('stories'), 1);
        expect(testServer.countRows('story_pages'), pageCount);
        expect(testServer.countRows('illustrations'), pageCount);
        final statuses = testServer.library.database
            .select('SELECT status FROM illustrations')
            .map((row) => row['status'])
            .toList();
        expect(statuses, everyElement('pending'));
        final profile = testServer.library.database
            .select('SELECT id, display_name FROM profiles')
            .single;
        expect(profile['id'], 'profile-1');
        expect(profile['display_name'], 'Nour');
      },
    );
  }

  test(
    'language and gender context reach Ollama and survive into the library',
    () async {
      const arabicTitle = 'نور وفوانيس البحر';
      const arabicPage = 'مشى يوسف على الشاطئ ورأى فانوسًا صغيرًا يضيء.';
      const arabicTheme = 'مهرجان الفوانيس على البحر';
      final printedCodes = <String>[];
      final client = FakeOllamaStoryClient.answering(
        storyPayload(
          pageCount: 8,
          title: arabicTitle,
          text: (pageNumber) => '$arabicPage ($pageNumber)',
        ),
      );
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final jobId = await startJob(
        testServer,
        token,
        body: generateRequestBody(
          heroName: 'Yusuf',
          genderContext: 'boy',
          languageCode: 'ar',
          theme: arabicTheme,
          pageCount: 8,
          illustrationStyle: 'watercolor',
        ),
      );
      final settled = await testServer.server.generationQueue.whenSettled(
        jobId,
      );
      expect(settled.status, GenerationJobStatus.completed);

      final call = client.requests.single;
      expect(call.model, 'gemma3:4b');
      expect(call.endpoint.path, '/api/generate');
      expect(call.prompt, contains('Arabic'));
      expect(call.prompt, contains('boy'));
      expect(call.prompt, contains('Yusuf'));
      expect(call.prompt, contains(arabicTheme));
      expect(call.prompt, contains('watercolor'));

      final encoded = utf8.decode(call.encodeBody());
      expect(
        encoded,
        contains(arabicTheme),
        reason: 'Arabic must survive explicit UTF-8 encoding',
      );
      final decoded = jsonDecode(encoded)! as Map<String, Object?>;
      expect(decoded['stream'], isFalse);
      final format = decoded['format']! as Map<String, Object?>;
      final properties = format['properties']! as Map<String, Object?>;
      final pagesSchema = properties['pages']! as Map<String, Object?>;
      expect(pagesSchema['minItems'], 8);
      expect(pagesSchema['maxItems'], 8);

      final storyRow = testServer.library.database
          .select('SELECT language_code, title FROM stories')
          .single;
      expect(storyRow['language_code'], 'ar');
      expect(storyRow['title'], arabicTitle);
      final prose = testServer.library.database
          .select('SELECT prose FROM story_pages ORDER BY page_index')
          .map((row) => row['prose'])
          .toList();
      expect(prose, hasLength(8));
      expect(prose.first, '$arabicPage (1)');

      final jobBody = await readJob(testServer, token, jobId);
      final story = jobBody['story']! as Map<String, Object?>;
      expect(story['languageCode'], 'ar');
      expect(story['title'], arabicTitle);
    },
  );

  final malformedAnswers = <String, String>{
    'a missing title': storyPayload(pageCount: 6, includeTitle: false),
    'the wrong page count': storyPayload(pageCount: 4),
    'output that is not JSON': 'Sure! Here is a lovely story for Nour.',
  };
  malformedAnswers.forEach((description, payload) {
    test(
      '$description is retried and then fails with nothing stored',
      () async {
        final printedCodes = <String>[];
        final client = FakeOllamaStoryClient.answering(payload);
        final testServer = await createTestServer(
          ollamaClient: client,
          notifyCode: printedCodes.add,
        );
        addTearDown(testServer.close);
        final token = await pairDevice(testServer, printedCodes);

        final jobId = await startJob(testServer, token);
        final settled = await testServer.server.generationQueue.whenSettled(
          jobId,
        );

        expect(settled.status, GenerationJobStatus.failed);
        expect(
          client.requests,
          hasLength(testServer.server.config.maxGenerationAttempts),
          reason: 'the whole generation is retried',
        );
        final jobBody = await readJob(testServer, token, jobId);
        expect(jobBody['status'], 'failed');
        final error = jobBody['error']! as Map<String, Object?>;
        expect(error['code'], 'invalid_model_output');
        expect(jobBody.containsKey('story'), isFalse);
        testServer.expectEmptyLibrary();
      },
    );
  });

  test(
    'a retry after one malformed answer still completes the story',
    () async {
      final printedCodes = <String>[];
      var calls = 0;
      final client = FakeOllamaStoryClient((request, cancellation) async {
        calls++;
        return ollamaEnvelope(
          calls == 1 ? 'not a story at all' : storyPayload(pageCount: 6),
        );
      });
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final jobId = await startJob(testServer, token);
      final settled = await testServer.server.generationQueue.whenSettled(
        jobId,
      );

      expect(settled.status, GenerationJobStatus.completed);
      expect(client.requests, hasLength(2));
      expect(testServer.countRows('stories'), 1);
      expect(testServer.countRows('story_pages'), 6);
    },
  );

  test(
    'an unreachable Ollama fails the job and leaves the library alone',
    () async {
      final printedCodes = <String>[];
      final client = FakeOllamaStoryClient.failing(
        const SocketException('Connection refused.'),
      );
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final jobId = await startJob(testServer, token);
      final settled = await testServer.server.generationQueue.whenSettled(
        jobId,
      );

      expect(settled.status, GenerationJobStatus.failed);
      final jobBody = await readJob(testServer, token, jobId);
      final error = jobBody['error']! as Map<String, Object?>;
      expect(error['code'], 'ollama_unavailable');
      expect(
        client.requests,
        hasLength(1),
        reason: 'a down server is not retried',
      );
      testServer.expectEmptyLibrary();
    },
  );

  test('a generation timeout fails the job with a typed error', () async {
    final printedCodes = <String>[];
    final client = FakeOllamaStoryClient.failing(
      TimeoutException('Ollama did not answer.', const Duration(minutes: 10)),
    );
    final testServer = await createTestServer(
      ollamaClient: client,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final jobId = await startJob(testServer, token);
    final settled = await testServer.server.generationQueue.whenSettled(jobId);

    expect(settled.status, GenerationJobStatus.failed);
    final jobBody = await readJob(testServer, token, jobId);
    final error = jobBody['error']! as Map<String, Object?>;
    expect(error['code'], 'ollama_timeout');
    testServer.expectEmptyLibrary();
  });

  test('a queued job can be cancelled before it ever reaches Ollama', () async {
    final printedCodes = <String>[];
    final gate = _GatedOllamaCall(storyPayload(pageCount: 6));
    final client = FakeOllamaStoryClient(gate.call);
    final testServer = await createTestServer(
      ollamaClient: client,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final runningJobId = await startJob(testServer, token);
    await gate.started.future;
    final queuedJobId = await startJob(
      testServer,
      token,
      expectedQueuePosition: 2,
    );

    final (cancelStatus, cancelBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/jobs/$queuedJobId/cancel',
      headers: authHeaders(token),
    );
    expect(cancelStatus, 200, reason: 'body was $cancelBody');
    expect(cancelBody['status'], 'cancelled');

    gate.release.complete();
    await testServer.server.generationQueue.whenSettled(runningJobId);
    final cancelled = await testServer.server.generationQueue.whenSettled(
      queuedJobId,
    );

    expect(cancelled.status, GenerationJobStatus.cancelled);
    expect(
      client.requests,
      hasLength(1),
      reason: 'the cancelled job never called the model',
    );
    expect(testServer.countRows('stories'), 1);
    expect(testServer.countRows('story_pages'), 6);
  });

  test('cancelling the running job stores nothing and is idempotent', () async {
    final printedCodes = <String>[];
    final gate = _GatedOllamaCall(storyPayload(pageCount: 6));
    final client = FakeOllamaStoryClient(gate.call);
    final testServer = await createTestServer(
      ollamaClient: client,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final jobId = await startJob(testServer, token);
    await gate.started.future;

    final (cancelStatus, cancelBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/jobs/$jobId/cancel',
      headers: authHeaders(token),
    );
    expect(cancelStatus, 200, reason: 'body was $cancelBody');
    expect(cancelBody['status'], 'cancelled');

    final settled = await testServer.server.generationQueue.whenSettled(jobId);
    expect(settled.status, GenerationJobStatus.cancelled);
    testServer.expectEmptyLibrary();

    final (repeatStatus, repeatBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/jobs/$jobId/cancel',
      headers: authHeaders(token),
    );
    expect(repeatStatus, 200);
    expect(repeatBody['status'], 'cancelled');

    final jobBody = await readJob(testServer, token, jobId);
    expect(jobBody['status'], 'cancelled');
    expect(jobBody.containsKey('story'), isFalse);
  });

  test('a second job waits its turn and reports its queue position', () async {
    final printedCodes = <String>[];
    final gate = _GatedOllamaCall(storyPayload(pageCount: 6));
    final client = FakeOllamaStoryClient(gate.call);
    final testServer = await createTestServer(
      ollamaClient: client,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final firstJobId = await startJob(testServer, token);
    await gate.started.future;
    final secondJobId = await startJob(
      testServer,
      token,
      expectedQueuePosition: 2,
    );

    final queuedBody = await readJob(testServer, token, secondJobId);
    expect(queuedBody['status'], 'queued');
    expect(queuedBody['queuePosition'], 2);
    final runningBody = await readJob(testServer, token, firstJobId);
    expect(runningBody['status'], 'generating');
    expect(runningBody.containsKey('queuePosition'), isFalse);
    expect(
      client.requests,
      hasLength(1),
      reason: 'only one generation runs at a time',
    );

    gate.release.complete();
    final first = await testServer.server.generationQueue.whenSettled(
      firstJobId,
    );
    final second = await testServer.server.generationQueue.whenSettled(
      secondJobId,
    );

    expect(first.status, GenerationJobStatus.completed);
    expect(second.status, GenerationJobStatus.completed);
    expect(client.requests, hasLength(2));
    expect(testServer.countRows('stories'), 2);
    expect(testServer.countRows('story_pages'), 12);
    expect(testServer.countRows('illustrations'), 12);
    expect(
      testServer.countRows('profiles'),
      1,
      reason: 'the profile row is upserted, not duplicated',
    );
  });

  test('a device cannot read or cancel another device\'s job', () async {
    final printedCodes = <String>[];
    final client = FakeOllamaStoryClient.answering(storyPayload(pageCount: 6));
    final testServer = await createTestServer(
      ollamaClient: client,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final ownerToken = await pairDevice(testServer, printedCodes);
    final otherToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: 'Second phone',
    );

    final jobId = await startJob(testServer, ownerToken);
    await testServer.server.generationQueue.whenSettled(jobId);

    final (readStatus, readBody) = await callJson(
      testServer.handler,
      'GET',
      '/stories/jobs/$jobId',
      headers: authHeaders(otherToken),
    );
    expect(readStatus, 404);
    expect(errorCode(readBody), ApiErrorCode.jobNotFound);

    final (cancelStatus, cancelBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/jobs/$jobId/cancel',
      headers: authHeaders(otherToken),
    );
    expect(cancelStatus, 404);
    expect(errorCode(cancelBody), ApiErrorCode.jobNotFound);

    final ownerBody = await readJob(testServer, ownerToken, jobId);
    expect(ownerBody['status'], 'completed');
  });

  test('every generation endpoint requires a device token', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);

    final calls = <(String, String, Object?)>[
      ('POST', '/stories/generate', jsonEncode(generateRequestBody())),
      ('GET', '/stories/jobs/any-job', null),
      ('POST', '/stories/jobs/any-job/cancel', null),
    ];
    for (final (method, path, body) in calls) {
      final (status, response) = await callJson(
        testServer.handler,
        method,
        path,
        body: body,
      );
      expect(status, 401, reason: '$method $path must require auth');
      expect(errorCode(response), ApiErrorCode.unauthorized);

      final (badTokenStatus, badTokenBody) = await callJson(
        testServer.handler,
        method,
        path,
        headers: authHeaders('not-a-real-token'),
        body: body,
      );
      expect(badTokenStatus, 401, reason: '$method $path rejects bad tokens');
      expect(errorCode(badTokenBody), ApiErrorCode.unauthorized);
    }
  });

  test('unknown job ids are reported as not found', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(notifyCode: printedCodes.add);
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);

    final (readStatus, readBody) = await callJson(
      testServer.handler,
      'GET',
      '/stories/jobs/does-not-exist',
      headers: authHeaders(token),
    );
    expect(readStatus, 404);
    expect(errorCode(readBody), ApiErrorCode.jobNotFound);

    final (cancelStatus, cancelBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/jobs/does-not-exist/cancel',
      headers: authHeaders(token),
    );
    expect(cancelStatus, 404);
    expect(errorCode(cancelBody), ApiErrorCode.jobNotFound);
  });

  test(
    'invalid generation requests are rejected before anything is queued',
    () async {
      final printedCodes = <String>[];
      final client = FakeOllamaStoryClient.answering(
        storyPayload(pageCount: 6),
      );
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final invalidBodies = <String, Map<String, Object?>>{
        'page count': generateRequestBody(pageCount: 7),
        'language': generateRequestBody(languageCode: 'de'),
        'gender': generateRequestBody(genderContext: 'unspecified'),
        'age': generateRequestBody(ageYears: 0),
        'style': generateRequestBody(illustrationStyle: 'photoreal'),
      };
      for (final entry in invalidBodies.entries) {
        final body = Map<String, Object?>.of(entry.value);
        final (status, response) = await callJson(
          testServer.handler,
          'POST',
          '/stories/generate',
          headers: authHeaders(token),
          body: jsonEncode(body),
        );
        expect(status, 400, reason: 'invalid ${entry.key} must be rejected');
        expect(errorCode(response), ApiErrorCode.invalidField);
      }

      final missingHeroName = generateRequestBody()..remove('heroName');
      final (status, response) = await callJson(
        testServer.handler,
        'POST',
        '/stories/generate',
        headers: authHeaders(token),
        body: jsonEncode(missingHeroName),
      );
      expect(status, 400);
      expect(errorCode(response), ApiErrorCode.invalidField);

      expect(client.requests, isEmpty);
      testServer.expectEmptyLibrary();
    },
  );
}
