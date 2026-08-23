import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_job.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_workflow.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// A fake Ollama call that blocks until released, so a story job can be held
/// "running" while the test inspects what the illustration queue is doing.
class _GatedOllamaCall {
  _GatedOllamaCall(this.payload);

  final String payload;
  final Completer<void> started = Completer<void>();
  final Completer<void> release = Completer<void>();

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

/// Starts one illustration job over HTTP and returns the response body.
Future<Map<String, Object?>> startIllustrationJob(
  TestServer testServer,
  String token,
  String storyId, {
  Map<String, Object?>? body,
  int expectedStatus = 202,
}) async {
  final (status, response) = await callJson(
    testServer.handler,
    'POST',
    '/stories/$storyId/illustrate',
    headers: authHeaders(token),
    body: body == null ? null : jsonEncode(body),
  );
  expect(status, expectedStatus, reason: 'body was $response');
  return response;
}

/// Absolute path of one library-relative file.
String _libraryPath(TestServer testServer, String relativePath) {
  return joinPath(
    testServer.library.rootPath,
    toPlatformRelativePath(relativePath),
  );
}

/// Inputs of one node of a submitted workflow.
Map<String, Object?> _inputs(Map<String, Object?> workflow, String nodeId) {
  final node = workflow[nodeId]! as Map<String, Object?>;
  return node['inputs']! as Map<String, Object?>;
}

/// A schema-valid two-page model answer, for the serialization test.
String _storyPayload() {
  return jsonEncode(<String, Object?>{
    'title': 'Nour and the Sea Lanterns',
    'pages': List<Object?>.generate(
      6,
      (index) => <String, Object?>{
        'pageNumber': index + 1,
        'text': 'Page ${index + 1} of quiet prose.',
        'illustrationScene': 'A moonlit beach, page ${index + 1}.',
      },
    ),
  });
}

void main() {
  test('every pending page is rendered, stored and marked completed', () async {
    final printedCodes = <String>[];
    final comfy = FakeComfyUiClient();
    final testServer = await createTestServer(
      comfyUiClient: comfy,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(
      testServer.library,
      pageCount: 3,
      writtenAtUtc: DateTime.utc(2026, 1, 1),
    );
    final before = storyUpdatedAt(testServer.library, story.id);

    final queued = await startIllustrationJob(testServer, token, story.id);
    expect(queued['pageCount'], 3);
    expect(queued['queuePosition'], 1);
    final jobId = queued['jobId']! as String;

    final settled = await testServer.server.illustrationQueue.whenSettled(
      jobId,
    );
    expect(settled.status, IllustrationJobStatus.completed);
    expect(settled.completedPageCount, 3);
    expect(settled.failedPageCount, 0);

    for (var index = 0; index < 3; index++) {
      final path = 'illustrations/${story.id}/$index.png';
      final file = File(_libraryPath(testServer, path));
      expect(file.existsSync(), isTrue, reason: '$path must exist');
      expect(file.readAsBytesSync(), onePixelPngBytes());
    }
    expect(illustrationStatuses(testServer.library, story.id), <String>[
      'completed',
      'completed',
      'completed',
    ]);
    expect(
      storyUpdatedAt(testServer.library, story.id).isAfter(before),
      isTrue,
      reason: 'sync must see the story as changed',
    );

    final (status, body) = await callJson(
      testServer.handler,
      'GET',
      '/illustrations/jobs/$jobId',
      headers: authHeaders(token),
    );
    expect(status, 200, reason: 'body was $body');
    expect(body['status'], 'completed');
    expect(body['storyId'], story.id);
    expect(body['completedPageCount'], 3);
    expect(body.containsKey('queuePosition'), isFalse);
    expect(
      jsonEncode(body),
      isNot(contains('moonlit')),
      reason: 'a job status never carries scene text',
    );
    expect(comfy.workflows, hasLength(3));
    expect(
      comfy.uploadedFileNames,
      isEmpty,
      reason: 'no photo means nothing is uploaded and nothing is stylized',
    );
    for (final workflow in comfy.workflows) {
      expect(workflow.containsKey(referenceSaveImageNodeId), isFalse);
      expect(workflow.containsKey(ipAdapterApplyNodeId), isFalse);
    }
  });

  test('a photo is stylized once and every page uses that portrait', () async {
    final printedCodes = <String>[];
    final comfy = FakeComfyUiClient();
    final testServer = await createTestServer(
      comfyUiClient: comfy,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library, pageCount: 2);
    await callRaw(
      testServer.handler,
      'PUT',
      '/profiles/profile-1/photo',
      headers: <String, String>{
        ...authHeaders(token),
        HttpHeaders.contentTypeHeader: 'image/jpeg',
      },
      body: minimalJpegBytes(),
    );

    final queued = await startIllustrationJob(
      testServer,
      token,
      story.id,
      body: <String, Object?>{
        'illustrationStyle': 'watercolor',
        'genderContext': 'boy',
      },
    );
    final settled = await testServer.server.illustrationQueue.whenSettled(
      queued['jobId']! as String,
    );
    expect(settled.status, IllustrationJobStatus.completed);
    expect(settled.completedPageCount, 2);

    final portraitName = referencePortraitFileName(story.id);
    expect(
      comfy.uploadedFileNames,
      <String>['profile-1.jpg', portraitName],
      reason: 'the photo goes up once, the portrait comes back up once',
    );
    expect(
      comfy.workflows,
      hasLength(3),
      reason: 'one stylization pass in front of the two pages',
    );

    final stylize = comfy.workflows.first;
    expect(
      _inputs(stylize, referenceSamplerNodeId)['denoise'],
      illustrationReferenceDenoise,
    );
    expect(
      _inputs(stylize, referencePhotoNodeId)['image'],
      'profile-1.jpg',
      reason: 'stage one is the only pass that ever sees the raw photo',
    );
    final portraitPrompt =
        _inputs(stylize, referencePositivePromptNodeId)['text']! as String;
    expect(portraitPrompt, contains('watercolor'));
    expect(portraitPrompt, contains('a young boy'));

    for (final workflow in comfy.workflows.skip(1)) {
      expect(workflow.containsKey(ipAdapterApplyNodeId), isTrue);
      expect(
        _inputs(workflow, referenceImageNodeId)['image'],
        portraitName,
        reason: 'pages reference the drawn portrait, never the photograph',
      );
      final text = _inputs(workflow, positivePromptNodeId)['text']! as String;
      expect(text, contains('watercolor'));
      expect(text, contains('a young boy'));
    }
  });

  test(
    'a failed stylization drops the reference instead of the photo',
    () async {
      final printedCodes = <String>[];
      // Submission zero is the stylization pass, and it is the one that fails.
      final comfy = FakeComfyUiClient(failingSubmissions: const <int>{0});
      final testServer = await createTestServer(
        comfyUiClient: comfy,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final story = seedStory(testServer.library, pageCount: 2);
      await callRaw(
        testServer.handler,
        'PUT',
        '/profiles/profile-1/photo',
        headers: <String, String>{
          ...authHeaders(token),
          HttpHeaders.contentTypeHeader: 'image/jpeg',
        },
        body: minimalJpegBytes(),
      );

      final queued = await startIllustrationJob(testServer, token, story.id);
      final settled = await testServer.server.illustrationQueue.whenSettled(
        queued['jobId']! as String,
      );

      expect(
        settled.status,
        IllustrationJobStatus.completed,
        reason: 'a lost portrait costs likeness, not the book',
      );
      expect(settled.completedPageCount, 2);
      expect(settled.failedPageCount, 0);
      expect(illustrationStatuses(testServer.library, story.id), <String>[
        'completed',
        'completed',
      ]);
      expect(
        comfy.uploadedFileNames,
        <String>['profile-1.jpg'],
        reason: 'nothing was stylized, so nothing was uploaded back',
      );
      for (final workflow in comfy.workflows.skip(1)) {
        for (final nodeId in <String>[
          referenceImageNodeId,
          ipAdapterModelNodeId,
          clipVisionNodeId,
          ipAdapterApplyNodeId,
        ]) {
          expect(
            workflow.containsKey(nodeId),
            isFalse,
            reason: 'the raw photo must never become the page reference',
          );
        }
      }
    },
  );

  test('one failing page fails its row and the others still land', () async {
    final printedCodes = <String>[];
    // The second submission is the one ComfyUI reports as an error.
    final comfy = FakeComfyUiClient(failingSubmissions: const <int>{1});
    final testServer = await createTestServer(
      comfyUiClient: comfy,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library, pageCount: 3);

    final queued = await startIllustrationJob(testServer, token, story.id);
    final settled = await testServer.server.illustrationQueue.whenSettled(
      queued['jobId']! as String,
    );

    expect(settled.status, IllustrationJobStatus.completed);
    expect(settled.completedPageCount, 2);
    expect(settled.failedPageCount, 1);
    expect(illustrationStatuses(testServer.library, story.id), <String>[
      'completed',
      'failed',
      'completed',
    ]);
    expect(
      File(
        _libraryPath(testServer, 'illustrations/${story.id}/1.png'),
      ).existsSync(),
      isFalse,
      reason: 'a failed page leaves no half-written file',
    );
    expect(
      File(
        _libraryPath(testServer, 'illustrations/${story.id}/2.png'),
      ).existsSync(),
      isTrue,
      reason: 'a failed page must not stop the pages after it',
    );
  });

  test('re-running renders only the pages that are not done', () async {
    final printedCodes = <String>[];
    final comfy = FakeComfyUiClient(failingSubmissions: const <int>{0});
    final testServer = await createTestServer(
      comfyUiClient: comfy,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library, pageCount: 3);

    final first = await startIllustrationJob(testServer, token, story.id);
    await testServer.server.illustrationQueue.whenSettled(
      first['jobId']! as String,
    );
    expect(illustrationStatuses(testServer.library, story.id), <String>[
      'failed',
      'completed',
      'completed',
    ]);
    expect(comfy.workflows, hasLength(3));

    final second = await startIllustrationJob(testServer, token, story.id);
    expect(
      second['pageCount'],
      1,
      reason: 'only the failed page is still outstanding',
    );
    final settled = await testServer.server.illustrationQueue.whenSettled(
      second['jobId']! as String,
    );

    expect(settled.completedPageCount, 1);
    expect(
      comfy.workflows,
      hasLength(4),
      reason: 'completed pages must not be rendered again',
    );
    expect(illustrationStatuses(testServer.library, story.id), <String>[
      'completed',
      'completed',
      'completed',
    ]);

    // A third run has nothing left to do and finishes without a render.
    final third = await startIllustrationJob(testServer, token, story.id);
    expect(third['pageCount'], 0);
    final done = await testServer.server.illustrationQueue.whenSettled(
      third['jobId']! as String,
    );
    expect(done.status, IllustrationJobStatus.completed);
    expect(comfy.workflows, hasLength(4));
  });

  test('a story job and an illustration job never overlap', () async {
    final printedCodes = <String>[];
    final storyGate = _GatedOllamaCall(_storyPayload());
    final renderOrder = <String>[];
    final comfy = FakeComfyUiClient(
      onSubmit: (index) async => renderOrder.add('render-$index'),
    );
    final testServer = await createTestServer(
      ollamaClient: FakeOllamaStoryClient(storyGate.call),
      comfyUiClient: comfy,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library, pageCount: 2);

    // Hold the GPU with a story job that is mid-generation.
    final (generateStatus, generateBody) = await callJson(
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
    expect(generateStatus, 202, reason: 'body was $generateBody');
    final storyJobId = generateBody['jobId']! as String;
    await storyGate.started.future;

    final queued = await startIllustrationJob(testServer, token, story.id);
    final illustrationJobId = queued['jobId']! as String;

    // Give the illustration worker every chance to jump the queue.
    for (var tick = 0; tick < 10; tick++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      comfy.workflows,
      isEmpty,
      reason: 'no render may start while the model holds the GPU',
    );
    final waiting = await callJson(
      testServer.handler,
      'GET',
      '/illustrations/jobs/$illustrationJobId',
      headers: authHeaders(token),
    );
    expect(waiting.$2['status'], anyOf('queued', 'rendering'));

    storyGate.release.complete();
    final storyJob = await testServer.server.generationQueue.whenSettled(
      storyJobId,
    );
    expect(storyJob.status, GenerationJobStatus.completed);
    renderOrder.add('story-done');

    final illustrationJob = await testServer.server.illustrationQueue
        .whenSettled(illustrationJobId);
    expect(illustrationJob.status, IllustrationJobStatus.completed);
    expect(
      renderOrder.first,
      'story-done',
      reason: 'the story finished before the first page was submitted',
    );
    expect(comfy.workflows, hasLength(2));
  });

  test('cancelling stops after the page in flight', () async {
    final printedCodes = <String>[];
    final firstPage = Completer<void>();
    final release = Completer<void>();
    final comfy = FakeComfyUiClient(
      onSubmit: (index) async {
        if (index == 0) {
          if (!firstPage.isCompleted) {
            firstPage.complete();
          }
          await release.future;
        }
      },
    );
    final testServer = await createTestServer(
      comfyUiClient: comfy,
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library, pageCount: 4);

    final queued = await startIllustrationJob(testServer, token, story.id);
    final jobId = queued['jobId']! as String;
    await firstPage.future;

    final (cancelStatus, cancelBody) = await callJson(
      testServer.handler,
      'POST',
      '/illustrations/jobs/$jobId/cancel',
      headers: authHeaders(token),
    );
    expect(cancelStatus, 200, reason: 'body was $cancelBody');
    expect(cancelBody['status'], 'cancelled');

    release.complete();
    final settled = await testServer.server.illustrationQueue.whenSettled(
      jobId,
    );

    expect(settled.status, IllustrationJobStatus.cancelled);
    expect(
      comfy.workflows,
      hasLength(1),
      reason: 'no page after the in-flight one is started',
    );
    expect(
      settled.completedPageCount,
      1,
      reason: 'the page already rendering is finished, not thrown away',
    );
    expect(illustrationStatuses(testServer.library, story.id), <String>[
      'completed',
      'pending',
      'pending',
      'pending',
    ]);

    // Cancelling again is a no-op that reports the same terminal status.
    final (repeatStatus, repeatBody) = await callJson(
      testServer.handler,
      'POST',
      '/illustrations/jobs/$jobId/cancel',
      headers: authHeaders(token),
    );
    expect(repeatStatus, 200);
    expect(repeatBody['status'], 'cancelled');
  });

  test('an unreachable ComfyUI fails the job without failing rows', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(
      comfyUiClient: FakeComfyUiClient(reachable: false),
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final token = await pairDevice(testServer, printedCodes);
    final story = seedStory(testServer.library, pageCount: 2);

    final queued = await startIllustrationJob(testServer, token, story.id);
    final settled = await testServer.server.illustrationQueue.whenSettled(
      queued['jobId']! as String,
    );

    expect(settled.status, IllustrationJobStatus.failed);
    expect(settled.failure?.code.wireCode, 'comfyui_unavailable');
    expect(
      illustrationStatuses(testServer.library, story.id),
      <String>['pending', 'pending'],
      reason: 'a stopped renderer is not the pages\' fault',
    );
  });

  test('unknown stories, foreign jobs and bad options are refused', () async {
    final printedCodes = <String>[];
    final testServer = await createTestServer(
      comfyUiClient: FakeComfyUiClient(),
      notifyCode: printedCodes.add,
    );
    addTearDown(testServer.close);
    final ownerToken = await pairDevice(testServer, printedCodes);
    final otherToken = await pairDevice(
      testServer,
      printedCodes,
      deviceName: 'Second phone',
    );
    final story = seedStory(testServer.library, pageCount: 1);

    final (missingStatus, missingBody) = await callJson(
      testServer.handler,
      'POST',
      '/stories/does-not-exist/illustrate',
      headers: authHeaders(ownerToken),
    );
    expect(missingStatus, 404);
    expect(errorCode(missingBody), ApiErrorCode.storyNotFound);

    for (final invalid in <Map<String, Object?>>[
      <String, Object?>{'illustrationStyle': 'photoreal'},
      <String, Object?>{'genderContext': 'unspecified'},
    ]) {
      final (status, body) = await callJson(
        testServer.handler,
        'POST',
        '/stories/${story.id}/illustrate',
        headers: authHeaders(ownerToken),
        body: jsonEncode(invalid),
      );
      expect(status, 400, reason: 'body was $body');
      expect(errorCode(body), ApiErrorCode.invalidField);
    }

    final queued = await startIllustrationJob(testServer, ownerToken, story.id);
    final jobId = queued['jobId']! as String;
    await testServer.server.illustrationQueue.whenSettled(jobId);

    final (readStatus, readBody) = await callJson(
      testServer.handler,
      'GET',
      '/illustrations/jobs/$jobId',
      headers: authHeaders(otherToken),
    );
    expect(readStatus, 404);
    expect(errorCode(readBody), ApiErrorCode.jobNotFound);

    final (cancelStatus, cancelBody) = await callJson(
      testServer.handler,
      'POST',
      '/illustrations/jobs/$jobId/cancel',
      headers: authHeaders(otherToken),
    );
    expect(cancelStatus, 404);
    expect(errorCode(cancelBody), ApiErrorCode.jobNotFound);

    final (unknownStatus, unknownBody) = await callJson(
      testServer.handler,
      'GET',
      '/illustrations/jobs/nope',
      headers: authHeaders(ownerToken),
    );
    expect(unknownStatus, 404);
    expect(errorCode(unknownBody), ApiErrorCode.jobNotFound);
  });

  test('every illustration endpoint requires a device token', () async {
    final testServer = await createTestServer();
    addTearDown(testServer.close);

    final calls = <(String, String)>[
      ('POST', '/stories/any-story/illustrate'),
      ('GET', '/illustrations/jobs/any-job'),
      ('POST', '/illustrations/jobs/any-job/cancel'),
      ('GET', '/sync/illustrations/any-illustration'),
    ];
    for (final (method, path) in calls) {
      final (status, body) = await callJson(testServer.handler, method, path);
      expect(status, 401, reason: '$method $path must require auth');
      expect(errorCode(body), ApiErrorCode.unauthorized);

      final (badStatus, badBody) = await callJson(
        testServer.handler,
        method,
        path,
        headers: authHeaders('not-a-real-token'),
      );
      expect(badStatus, 401, reason: '$method $path rejects bad tokens');
      expect(errorCode(badBody), ApiErrorCode.unauthorized);
    }
  });

  group('illustration download', () {
    test('a completed page round-trips with a content ETag', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(
        comfyUiClient: FakeComfyUiClient(),
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final story = seedStory(testServer.library, pageCount: 1);
      final queued = await startIllustrationJob(testServer, token, story.id);
      await testServer.server.illustrationQueue.whenSettled(
        queued['jobId']! as String,
      );

      expect(
        IllustrationRepository(
          library: testServer.library,
        ).readTargets(story.id)!.pending,
        isEmpty,
        reason: 'the page must be completed before it can be downloaded',
      );
      final illustrationId =
          testServer.library.database
                  .select('SELECT id FROM illustrations')
                  .single['id']!
              as String;

      final response = await callRaw(
        testServer.handler,
        'GET',
        '/sync/illustrations/$illustrationId',
        headers: authHeaders(token),
      );
      expect(response.statusCode, 200);
      expect(response.headers['content-type'], 'image/png');
      final eTag = response.headers['etag'];
      expect(eTag, isNotNull);
      expect(
        await response.read().expand((c) => c).toList(),
        onePixelPngBytes(),
      );

      final repeated = await callRaw(
        testServer.handler,
        'GET',
        '/sync/illustrations/$illustrationId',
        headers: <String, String>{
          ...authHeaders(token),
          'if-none-match': eTag!,
        },
      );
      expect(
        repeated.statusCode,
        304,
        reason: 'the ETag exists so a device can skip a re-download',
      );
    });

    test('a not-yet-rendered page answers 409 and an unknown id 404', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(notifyCode: printedCodes.add);
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final story = seedStory(testServer.library, pageCount: 1);
      expect(illustrationStatuses(testServer.library, story.id), <String>[
        pendingIllustrationStatus,
      ]);
      final illustrationId =
          testServer.library.database
                  .select('SELECT id FROM illustrations')
                  .single['id']!
              as String;

      final (notReadyStatus, notReadyBody) = await callJson(
        testServer.handler,
        'GET',
        '/sync/illustrations/$illustrationId',
        headers: authHeaders(token),
      );
      expect(notReadyStatus, 409);
      expect(errorCode(notReadyBody), ApiErrorCode.illustrationNotReady);

      final (unknownStatus, unknownBody) = await callJson(
        testServer.handler,
        'GET',
        '/sync/illustrations/does-not-exist',
        headers: authHeaders(token),
      );
      expect(unknownStatus, 404);
      expect(errorCode(unknownBody), ApiErrorCode.illustrationNotFound);
    });

    test('a completed row whose file is gone reads as not ready', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(
        comfyUiClient: FakeComfyUiClient(),
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final story = seedStory(testServer.library, pageCount: 1);
      final queued = await startIllustrationJob(testServer, token, story.id);
      await testServer.server.illustrationQueue.whenSettled(
        queued['jobId']! as String,
      );
      final illustrationId =
          testServer.library.database
                  .select('SELECT id FROM illustrations')
                  .single['id']!
              as String;
      File(
        _libraryPath(testServer, 'illustrations/${story.id}/0.png'),
      ).deleteSync();

      final (status, body) = await callJson(
        testServer.handler,
        'GET',
        '/sync/illustrations/$illustrationId',
        headers: authHeaders(token),
      );
      expect(status, 409);
      expect(errorCode(body), ApiErrorCode.illustrationNotReady);
    });
  });
}
