import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies what a family ends up with when the PC generates the story.
///
/// The whole app path runs for real — durable queue, story controller, and
/// preference storage — with only the PC's HTTP boundary replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a completed PC story is saved once as a draft', () async {
    final container = await _pairedContainer(
      _bridge(
        job: <String, Object>{
          'jobId': 'job-1',
          'status': 'completed',
          'story': bridgeStoryPayload(
            storyId: 'story-9',
            languageCode: 'en',
            pageCount: 6,
          ),
        },
      ),
    );

    final story = await container
        .read(storyControllerProvider)
        .createStory(_request());

    expect(story.reviewStatus, StoryReviewStatus.draft);
    expect(story.content.pages, hasLength(6));
    expect(
      container.read(appControllerProvider).requireValue.stories.single.id,
      story.id,
    );
    expect(
      container.read(generationQueueControllerProvider).requireValue,
      isEmpty,
    );
  });

  test('a failed PC job saves nothing and stays retryable', () async {
    final container = await _pairedContainer(
      _bridge(
        job: <String, Object>{
          'jobId': 'job-1',
          'status': 'failed',
          'error': <String, Object>{
            'code': 'invalid_model_output',
            'message': 'The model returned the wrong page count.',
          },
        },
      ),
    );

    await expectLater(
      container.read(storyControllerProvider).createStory(_request()),
      throwsA(_failure(BridgeFailure.generationFailed)),
    );

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    final jobs = container.read(generationQueueControllerProvider).requireValue;
    expect(jobs.single.status, GenerationJobStatus.failed);
  });

  test('an unreachable PC leaves the library untouched', () async {
    final container = await _pairedContainer(
      FakeBridgeHttpClient((request) async {
        throw http.ClientException('Connection refused.', request.url);
      }),
    );

    await expectLater(
      container.read(storyControllerProvider).createStory(_request()),
      throwsA(_failure(BridgeFailure.unreachable)),
    );

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    final repository = await LocalRepository.open();
    expect((await repository.readState()).stories, isEmpty);
  });

  test('a refused device token leaves the library untouched', () async {
    final container = await _pairedContainer(
      FakeBridgeHttpClient((request) async {
        return bridgeErrorResponse('unauthorized', 401);
      }),
    );

    await expectLater(
      container.read(storyControllerProvider).createStory(_request()),
      throwsA(_failure(BridgeFailure.unauthorized)),
    );

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
  });

  test('a PC that stops answering leaves the library untouched', () async {
    final container = await _pairedContainer(
      FakeBridgeHttpClient((request) async {
        throw TimeoutException('Too slow.');
      }),
    );

    await expectLater(
      container.read(storyControllerProvider).createStory(_request()),
      throwsA(_failure(BridgeFailure.timedOut)),
    );

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
  });

  test('cancelling a running request stops the PC too', () async {
    final started = Completer<void>();
    var isCancelled = false;
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
      if (!started.isCompleted) started.complete();
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'job-1',
        'status': isCancelled ? 'cancelled' : 'generating',
      });
    });
    final container = await _pairedContainer(httpClient);
    final controller = container.read(storyControllerProvider);

    final generating = expectLater(
      controller.createStory(_request()),
      throwsA(_failure(BridgeFailure.cancelled)),
    );
    await started.future;
    final job = container
        .read(generationQueueControllerProvider)
        .requireValue
        .single;
    await controller.cancelGeneration(job.id);
    await generating;

    expect(httpClient.callsTo('/stories/jobs/job-1/cancel'), 1);
    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    expect(
      container.read(generationQueueControllerProvider).requireValue,
      isEmpty,
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

/// Opens a container for a family whose device is paired and set to local AI.
Future<ProviderContainer> _pairedContainer(
  FakeBridgeHttpClient httpClient,
) async {
  final repository = await LocalRepository.open();
  await repository.saveProfiles(const <ChildProfile>[
    ChildProfile(
      id: 'miko',
      name: 'Miko',
      legacyAge: 7,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
    ),
  ]);
  await repository.saveAiConnectionSettings(
    AiConnectionSettings(
      mode: StoryGeneratorMode.localAi,
      baseUrl: Uri.parse(defaultBridgeBaseUrl),
    ),
  );
  await repository.saveBridgeCredential(
    BridgeCredential(
      deviceToken: 'device-token',
      deviceName: 'Family tablet',
      pairedAtUtc: DateTime.utc(2026, 8, 22),
    ),
  );
  final container = ProviderContainer(
    overrides: [
      bridgeHttpClientProvider.overrideWithValue(httpClient),
      localAiPollIntervalProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  await container.read(generationQueueControllerProvider.future);
  await container.read(aiConnectionControllerProvider.future);
  return container;
}

/// Answers the submit call, then repeats one job answer on every poll.
FakeBridgeHttpClient _bridge({required Map<String, Object> job}) {
  return FakeBridgeHttpClient((request) async {
    if (request.url.path == '/stories/generate') {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'job-1',
        'queuePosition': 1,
      }, statusCode: 202);
    }
    return bridgeJsonResponse(job);
  });
}

/// Builds the request the creation screen would hand to the controller.
StoryRequest _request() {
  return const StoryRequest(
    hero: StoryHero(profileId: 'miko', name: 'Miko', gender: ChildGender.girl),
    prompt: StoryPrompt(
      theme: 'a lantern festival',
      moral: 'sharing',
      preferences: ChildStoryPreferences(),
    ),
    presentation: StoryPresentation(
      language: AppLanguage.english,
      length: StoryLength.short,
      style: IllustrationStyle.pictureBook,
    ),
  );
}
