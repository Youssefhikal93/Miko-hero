import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/ai_connection/local_ai_progress.dart';
import 'package:miko_hero/core/generation/local_ai_story_generator.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies the observable contract of the local AI adapter.
///
/// Only the PC process boundary is replaced. The tests assert what a family
/// can see — the saved book, the typed failure, the reported stage — and never
/// prompt wording, model prose, or internal call counts.
void main() {
  final fixedTime = DateTime.utc(2026, 8, 22, 10);

  test('a completed job becomes one complete book', () async {
    final httpClient = _bridge(
      story: bridgeStoryPayload(
        storyId: 'story-9',
        languageCode: 'sv',
        pageCount: 8,
        title: 'Lyktstigen',
      ),
    );
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    final book = await generator.generate(
      _request(language: AppLanguage.swedish, length: StoryLength.medium),
    );

    expect(book.content.title, 'Lyktstigen');
    expect(book.content.request.presentation.language, AppLanguage.swedish);
    expect(book.content.pages, hasLength(8));
    expect(
      book.content.pages.map((page) => page.number),
      orderedEquals(List<int>.generate(8, (index) => index + 1)),
    );
    expect(book.content.pages[3].text, 'Page 4 prose.');
    expect(book.createdAt, fixedTime);
  });

  test('every page keeps its scene text and its bridge identities', () async {
    final httpClient = _bridge(
      story: bridgeStoryPayload(
        storyId: 'story-9',
        languageCode: 'en',
        pageCount: 6,
      ),
    );
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    final book = await generator.generate(_request());

    for (final (index, page) in book.content.pages.indexed) {
      final provenance = BridgeStoryProvenance.fromSceneDescription(
        page.sceneDescription,
      );
      expect(provenance, isNotNull);
      expect(provenance!.scene, 'A lantern scene ${index + 1}.');
      expect(provenance.storyId, 'story-9');
      expect(provenance.illustrationId, 'illustration-${index + 1}');
    }
  });

  test('gender context and every page count reach the request', () async {
    for (final gender in <ChildGender>[ChildGender.girl, ChildGender.boy]) {
      for (final length in StoryLength.values) {
        final httpClient = _bridge(
          story: bridgeStoryPayload(
            storyId: 'story-9',
            languageCode: 'en',
            pageCount: length.pageCount,
          ),
        );
        final generator = _generator(httpClient, currentTime: () => fixedTime);

        await generator.generate(_request(gender: gender, length: length));

        final body = httpClient.jsonBodiesFor('/stories/generate').single;
        expect(body['genderContext'], gender.name);
        expect(body['pageCount'], length.pageCount);
        expect(body['ageYears'], 7);
        expect(body['illustrationStyle'], 'pictureBook');
        expect(body['profileId'], 'miko');
      }
    }
  });

  test('the confirmed spelling travels beside the entered name', () async {
    final httpClient = _bridge(
      story: bridgeStoryPayload(
        storyId: 'story-9',
        languageCode: 'ar',
        pageCount: 6,
      ),
    );
    final generator = _generator(
      httpClient,
      currentTime: () => fixedTime,
      nameSpelling: 'مليكة',
    );

    await generator.generate(_request(language: AppLanguage.arabic));

    final body = httpClient.jsonBodiesFor('/stories/generate').single;
    expect(body['heroName'], 'Miko');
    expect(body['heroNameSpelling'], 'مليكة');
  });

  test(
    'a child with no spelling for this language sends no field at all',
    () async {
      final httpClient = _bridge(
        story: bridgeStoryPayload(
          storyId: 'story-9',
          languageCode: 'en',
          pageCount: 6,
        ),
      );
      final generator = _generator(httpClient, currentTime: () => fixedTime);

      await generator.generate(_request());

      final body = httpClient.jsonBodiesFor('/stories/generate').single;
      expect(
        body.containsKey('heroNameSpelling'),
        isFalse,
        reason: 'an older bridge must see the body it has always seen',
      );
    },
  );

  test('a request without a parent gender choice never reaches the PC', () {
    final httpClient = _bridge(
      story: bridgeStoryPayload(
        storyId: 'story-9',
        languageCode: 'en',
        pageCount: 6,
      ),
    );
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    expect(
      generator.generate(_request(gender: ChildGender.unspecified)),
      throwsArgumentError,
    );
    expect(httpClient.requests, isEmpty);
  });

  test('waiting, writing, and checking are reported as they happen', () async {
    final statuses = <Map<String, Object>>[
      <String, Object>{'status': 'queued', 'queuePosition': 2},
      <String, Object>{'status': 'generating'},
      <String, Object>{'status': 'validating'},
    ];
    var poll = 0;
    final httpClient = FakeBridgeHttpClient((request) async {
      if (request.url.path == '/stories/generate') {
        return bridgeJsonResponse(<String, Object>{
          'jobId': 'job-1',
          'queuePosition': 2,
        }, statusCode: 202);
      }
      if (poll < statuses.length) {
        final status = statuses[poll++];
        return bridgeJsonResponse(<String, Object>{
          'jobId': 'job-1',
          ...status,
        });
      }
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'job-1',
        'status': 'completed',
        'story': bridgeStoryPayload(
          storyId: 'story-9',
          languageCode: 'en',
          pageCount: 6,
        ),
      });
    });
    final reported = <LocalAiProgress>[];
    final generator = _generator(
      httpClient,
      currentTime: () => fixedTime,
      onProgress: reported.add,
    );

    await generator.generate(_request());

    expect(
      reported.map((progress) => progress.stage),
      containsAllInOrder(<LocalAiStage>[
        LocalAiStage.submitting,
        LocalAiStage.queued,
        LocalAiStage.writing,
        LocalAiStage.checking,
      ]),
    );
    expect(
      reported
          .lastWhere((progress) => progress.stage == LocalAiStage.queued)
          .queuePosition,
      2,
    );
  });

  test('a failed job is reported as a typed failure', () async {
    final httpClient = _bridge(
      job: <String, Object>{
        'jobId': 'job-1',
        'status': 'failed',
        'error': <String, Object>{
          'code': 'ollama_unavailable',
          'message': 'Ollama is unreachable.',
        },
      },
    );
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    await expectLater(
      generator.generate(_request()),
      throwsA(_failure(BridgeFailure.generationFailed)),
    );
  });

  test('an unreachable bridge is reported as a typed failure', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      throw http.ClientException('Connection refused.', request.url);
    });
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    await expectLater(
      generator.generate(_request()),
      throwsA(_failure(BridgeFailure.unreachable)),
    );
  });

  test('a refused device token is reported as a typed failure', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeErrorResponse('unauthorized', 401);
    });
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    await expectLater(
      generator.generate(_request()),
      throwsA(_failure(BridgeFailure.unauthorized)),
    );
  });

  test('a bridge that stops answering in time is reported', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      throw TimeoutException('Too slow.');
    });
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    await expectLater(
      generator.generate(_request()),
      throwsA(_failure(BridgeFailure.timedOut)),
    );
  });

  test('a job that never finishes gives up inside its bound', () async {
    final httpClient = _bridge(
      job: <String, Object>{'jobId': 'job-1', 'status': 'generating'},
    );
    var clock = fixedTime;
    final generator = _generator(
      httpClient,
      currentTime: () {
        clock = clock.add(const Duration(minutes: 20));
        return clock;
      },
    );

    await expectLater(
      generator.generate(_request()),
      throwsA(_failure(BridgeFailure.timedOut)),
    );
  });

  test('cancelling stops the PC and reports cancellation', () async {
    late LocalAiStoryGenerator generator;
    var isCancelled = false;
    var polls = 0;
    final httpClient = FakeBridgeHttpClient((request) async {
      if (request.url.path == '/stories/generate') {
        return bridgeJsonResponse(<String, Object>{
          'jobId': 'job-1',
          'queuePosition': 1,
        }, statusCode: 202);
      }
      if (request.url.path.endsWith('/cancel')) {
        isCancelled = true;
        return bridgeJsonResponse(<String, Object>{
          'jobId': 'job-1',
          'status': 'cancelled',
        });
      }
      polls++;
      if (polls == 1) await generator.cancelActiveGeneration();
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'job-1',
        'status': isCancelled ? 'cancelled' : 'generating',
      });
    });
    generator = _generator(httpClient, currentTime: () => fixedTime);

    await expectLater(
      generator.generate(_request()),
      throwsA(_failure(BridgeFailure.cancelled)),
    );
    expect(httpClient.callsTo('/stories/jobs/job-1/cancel'), 1);
  });

  test('cancelling with nothing running never calls the PC', () async {
    final httpClient = FakeBridgeHttpClient((request) async {
      return bridgeJsonResponse(<String, Object>{});
    });
    final generator = _generator(httpClient, currentTime: () => fixedTime);

    await generator.cancelActiveGeneration();

    expect(httpClient.requests, isEmpty);
  });

  test('a payload that lost pages or changed language is refused', () async {
    final wrongPageCount = _generator(
      _bridge(
        story: bridgeStoryPayload(
          storyId: 'story-9',
          languageCode: 'en',
          pageCount: 5,
        ),
      ),
      currentTime: () => fixedTime,
    );
    final wrongLanguage = _generator(
      _bridge(
        story: bridgeStoryPayload(
          storyId: 'story-9',
          languageCode: 'sv',
          pageCount: 6,
        ),
      ),
      currentTime: () => fixedTime,
    );

    await expectLater(
      wrongPageCount.generate(_request()),
      throwsA(_failure(BridgeFailure.invalidResponse)),
    );
    await expectLater(
      wrongLanguage.generate(_request()),
      throwsA(_failure(BridgeFailure.invalidResponse)),
    );
  });
}

/// Matches one typed bridge failure regardless of its diagnostic code.
Matcher _failure(BridgeFailure failure) {
  return isA<BridgeException>().having(
    (error) => error.failure,
    'failure',
    failure,
  );
}

/// Builds a generator over one fake PC boundary with no polling delay.
LocalAiStoryGenerator _generator(
  FakeBridgeHttpClient httpClient, {
  required DateTime Function() currentTime,
  void Function(LocalAiProgress progress)? onProgress,
  String nameSpelling = '',
}) {
  return LocalAiStoryGenerator(
    client: BridgeClient(
      httpClient: httpClient,
      baseUrl: Uri.parse(defaultBridgeBaseUrl),
      deviceToken: 'device-token',
    ),
    resolveAgeYears: (request) => 7,
    resolveNameSpelling: (request) => nameSpelling,
    currentTime: currentTime,
    onProgress: onProgress,
    pollInterval: Duration.zero,
  );
}

/// Answers the submit call, then repeats one job answer on every poll.
FakeBridgeHttpClient _bridge({
  Map<String, Object>? story,
  Map<String, Object>? job,
}) {
  return FakeBridgeHttpClient((request) async {
    if (request.url.path == '/stories/generate') {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'job-1',
        'queuePosition': 1,
      }, statusCode: 202);
    }
    return bridgeJsonResponse(
      job ??
          <String, Object>{
            'jobId': 'job-1',
            'status': 'completed',
            'story': story!,
          },
    );
  });
}

/// Creates a valid request while letting one contract vary per test.
StoryRequest _request({
  AppLanguage language = AppLanguage.english,
  StoryLength length = StoryLength.short,
  ChildGender gender = ChildGender.girl,
}) {
  return StoryRequest(
    hero: StoryHero(profileId: 'miko', name: 'Miko', gender: gender),
    prompt: const StoryPrompt(
      theme: 'a lantern festival',
      moral: 'sharing',
      preferences: ChildStoryPreferences(),
    ),
    presentation: StoryPresentation(
      language: language,
      length: length,
      style: IllustrationStyle.pictureBook,
    ),
  );
}
