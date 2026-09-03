import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/library/illustrate_story_controller.dart';
import 'package:miko_hero/features/library/story_illustrate_actions.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/in_memory_illustration_store.dart';

/// A one-pixel PNG, so a decoded photo really carries the PNG magic bytes.
const _pngPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Verifies what a family actually ends up with after asking for pictures.
///
/// The whole app path runs for real — the typed client, the picture service,
/// the controller, and preference storage — with only the PC's HTTP boundary
/// and the platform image cache replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a finished run uploads the photo once and caches every page', () async {
    final bridge = _FakePictureBridge();
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);

    await _illustrate(container);

    final run = container.read(illustrateStoryControllerProvider)!;
    expect(run.isRunning, isFalse);
    final outcome = run.outcome!;
    expect(outcome.status, BridgeIllustrationJobStatus.completed);
    expect(outcome.completedPageCount, 3);
    expect(outcome.failedPageCount, 0);
    expect(outcome.drewEveryPage, isTrue);
    expect(outcome.photoSkipped, isFalse);
    expect(outcome.savedIllustrationIds, <String>[
      'illustration-1',
      'illustration-2',
      'illustration-3',
    ]);
    expect(bridge.httpClient.callsTo('/profiles/miko/photo'), 1);
    expect(bridge.photoContentType, 'image/png');
    final cached = await store.read('illustration-2');
    expect(cached!.eTag, 'etag-illustration-2');
    expect(cached.bytes, isNotEmpty);
  });

  test('the request carries the story style and the hero gender', () async {
    final bridge = _FakePictureBridge();
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
    );

    await _illustrate(container);

    final body = bridge.httpClient
        .jsonBodiesFor('/stories/story-a/illustrate')
        .single;
    expect(body['illustrationStyle'], 'watercolor');
    expect(body['genderContext'], 'girl');
  });

  test('a cached page with a matching ETag is not downloaded again', () async {
    final bridge = _FakePictureBridge();
    final store = InMemoryIllustrationStore();
    await store.write(
      'illustration-1',
      Uint8List.fromList(<int>[1, 2, 3]),
      eTag: 'etag-illustration-1',
    );
    final container = await _pairedContainer(bridge, store);

    await _illustrate(container);

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(outcome.savedIllustrationIds, <String>[
      'illustration-2',
      'illustration-3',
    ]);
    expect((await store.read('illustration-1'))!.bytes, <int>[1, 2, 3]);
    expect(bridge.unchangedIds, <String>['illustration-1']);
  });

  test('the reader of a newly drawn page is told to repaint', () async {
    final bridge = _FakePictureBridge();
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
    );
    // An open reader is holding this page, so only an explicit invalidation
    // can make it look at the cache again.
    container.listen(
      illustrationBytesProvider('illustration-1'),
      (previous, next) {},
      fireImmediately: true,
    );
    expect(
      await container.read(illustrationBytesProvider('illustration-1').future),
      isNull,
    );

    await _illustrate(container);

    expect(
      await container.read(illustrationBytesProvider('illustration-1').future),
      isNotEmpty,
    );
  });

  test('a partly drawn book reports the pages the PC failed on', () async {
    final bridge = _FakePictureBridge()
      ..completedPageCount = 2
      ..failedPageCount = 1
      ..notReadyIds = const <String>['illustration-3'];
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);

    await _illustrate(container);

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(outcome.status, BridgeIllustrationJobStatus.completed);
    expect(outcome.drewEveryPage, isFalse);
    expect(outcome.completedPageCount, 2);
    expect(outcome.failedPageCount, 1);
    expect(outcome.fetchFailureCount, 0, reason: 'not drawn is not a failure');
    expect(outcome.savedIllustrationIds, hasLength(2));
    expect(store.holds('illustration-3'), isFalse);
  });

  test('one broken picture never costs the other pictures', () async {
    final bridge = _FakePictureBridge()
      ..unreachableIds = const <String>['illustration-2'];
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
    );

    await _illustrate(container);

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(outcome.fetchFailureCount, 1);
    expect(outcome.savedIllustrationIds, <String>[
      'illustration-1',
      'illustration-3',
    ]);
  });

  test('stopping keeps the pictures the PC already finished', () async {
    final bridge = _FakePictureBridge()
      ..completedPageCount = 1
      ..notReadyIds = const <String>['illustration-2', 'illustration-3']
      ..pollsBeforeTerminal = 4;
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(
      illustrateStoryControllerProvider.notifier,
    );
    // Stopping has to happen while the PC is genuinely mid-job, so the request
    // is made from the first poll rather than after a guessed-at delay.
    bridge.onJobPoll = () => unawaited(controller.cancel());

    await controller.illustrate(_storedStory(container));

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(bridge.httpClient.callsTo(_cancelPath), 1);
    expect(outcome.status, BridgeIllustrationJobStatus.cancelled);
    expect(outcome.completedPageCount, 1);
    expect(store.holds('illustration-1'), isTrue);
    expect(store.holds('illustration-2'), isFalse);
  });

  test('a hero this device no longer has means no photo is sent', () async {
    final bridge = _FakePictureBridge();
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
    );
    final story = _storedStory(container);
    // The parent deleted the child between opening the shelf and asking for
    // pictures: there is no photo to send, which is not something to report.
    final state = container.read(appControllerProvider).requireValue;
    container
        .read(appControllerProvider.notifier)
        .commit(
          state.withProfiles(
            const <ChildProfile>[],
            savedActiveProfileId: null,
          ),
        );

    await container
        .read(illustrateStoryControllerProvider.notifier)
        .illustrate(story);

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(outcome.photoSkipped, isFalse);
    expect(outcome.drewEveryPage, isTrue);
    expect(bridge.httpClient.callsTo('/profiles/miko/photo'), 0);
  });

  test('a photo that is not a JPEG or PNG is skipped, not fatal', () async {
    final bridge = _FakePictureBridge();
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
      photoBase64: base64Encode(utf8.encode('RIFF....WEBP not a JPEG')),
    );

    await _illustrate(container);

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(outcome.photoSkipped, isTrue);
    expect(outcome.drewEveryPage, isTrue, reason: 'the book still got drawn');
    expect(bridge.httpClient.callsTo('/profiles/miko/photo'), 0);
  });

  test('a photo the PC refuses is skipped and the book still drawn', () async {
    final bridge = _FakePictureBridge()..refusePhoto = true;
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
    );

    await _illustrate(container);

    final outcome = container.read(illustrateStoryControllerProvider)!.outcome!;
    expect(outcome.photoSkipped, isTrue);
    expect(outcome.drewEveryPage, isTrue);
    expect(bridge.httpClient.callsTo('/profiles/miko/photo'), 1);
  });

  test('an unreachable PC fails the run and caches nothing', () async {
    final bridge = _FakePictureBridge()..isOffline = true;
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);

    await _illustrate(container);

    final run = container.read(illustrateStoryControllerProvider)!;
    expect(run.outcome, isNull);
    expect(run.failure, isA<BridgeException>());
    expect(
      (run.failure! as BridgeException).failure,
      BridgeFailure.unreachable,
    );
    expect(store.illustrationIds, isEmpty);
  });

  test('a second request while one is open is ignored', () async {
    final bridge = _FakePictureBridge()..pollsBeforeTerminal = 3;
    final container = await _pairedContainer(
      bridge,
      InMemoryIllustrationStore(),
    );
    final controller = container.read(
      illustrateStoryControllerProvider.notifier,
    );
    final story = _storedStory(container);
    bridge.onJobPoll = () => unawaited(controller.illustrate(story));

    await controller.illustrate(story);

    expect(bridge.httpClient.callsTo('/stories/story-a/illustrate'), 1);
  });

  test('the action is offered only for a paired PC story', () async {
    final container = await _pairedContainer(
      _FakePictureBridge(),
      InMemoryIllustrationStore(),
    );
    final connection = container.read(aiConnectionControllerProvider).value;
    final story = _storedStory(container);
    final demoStory = StoryBook(
      id: 'story-demo',
      createdAt: story.createdAt,
      content: StoryContent(
        title: story.content.title,
        request: story.content.request,
        pages: const <StoryPage>[
          StoryPage(number: 1, text: 'Demo page.', sceneDescription: 'a scene'),
        ],
      ),
    );

    expect(canIllustrateStory(story, connection), isTrue);
    expect(canIllustrateStory(demoStory, connection), isFalse);
    expect(canIllustrateStory(story, null), isFalse);
  });
}

/// Cancel endpoint of the one job every test in this file queues.
const _cancelPath = '/illustrations/jobs/illustration-job-1/cancel';

/// Number of pages the one stored story has, and the PC draws.
const _pageCount = 3;

/// Runs one whole picture flow for the story this device holds.
Future<void> _illustrate(ProviderContainer container) {
  return container
      .read(illustrateStoryControllerProvider.notifier)
      .illustrate(_storedStory(container));
}

/// Reads the stored bridge story back out of the loaded library.
StoryBook _storedStory(ProviderContainer container) {
  return container.read(appControllerProvider).requireValue.stories.single;
}

/// Opens a container for a paired Local AI family holding one bridge story.
Future<ProviderContainer> _pairedContainer(
  _FakePictureBridge bridge,
  InMemoryIllustrationStore store, {
  String photoBase64 = _pngPixel,
}) async {
  final credentialStorage = InMemoryBridgeCredentialStorage();
  final repository = await LocalRepository.open(
    bridgeCredentialStorage: credentialStorage,
  );
  await repository.saveProfiles(<ChildProfile>[
    ChildProfile(
      id: 'miko',
      name: 'Miko',
      legacyAge: 7,
      photoBase64: photoBase64,
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
    ),
  ]);
  await repository.saveStories(<StoryBook>[_bridgeStory()]);
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
      bridgeHttpClientProvider.overrideWithValue(bridge.httpClient),
      bridgeCredentialStorageProvider.overrideWithValue(credentialStorage),
      illustrationStoreProvider.overrideWithValue(store),
      illustrationPollIntervalProvider.overrideWithValue(Duration.zero),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  await container.read(aiConnectionControllerProvider.future);
  // In the app the waiting dialog watches the run for its whole duration; a
  // test holds it open the same way instead of relying on a bare read.
  container.listen(
    illustrateStoryControllerProvider,
    (previous, next) {},
    fireImmediately: true,
  );
  return container;
}

/// One stored PC-library story whose pages carry their bridge identities.
StoryBook _bridgeStory() {
  return StoryBook(
    id: 'story-a',
    createdAt: DateTime.utc(2026, 8, 20, 10),
    content: StoryContent(
      title: 'The Lantern Path',
      request: const StoryRequest(
        hero: StoryHero(
          profileId: 'miko',
          name: 'Miko',
          gender: ChildGender.girl,
        ),
        prompt: StoryPrompt(
          theme: 'a lantern festival',
          moral: 'sharing',
          preferences: ChildStoryPreferences(),
        ),
        presentation: StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.watercolor,
        ),
      ),
      pages: <StoryPage>[
        for (var number = 1; number <= _pageCount; number++)
          StoryPage(
            number: number,
            text: 'Page $number prose.',
            sceneDescription: BridgeStoryProvenance(
              scene: 'A lantern scene $number.',
              storyId: 'story-a',
              illustrationId: 'illustration-$number',
            ).toSceneDescription(),
          ),
      ],
    ),
  );
}

/// One scripted PC that answers the photo, job, and page-image endpoints.
class _FakePictureBridge {
  /// Creates a PC that draws every page of the one stored story.
  _FakePictureBridge() {
    httpClient = FakeBridgeHttpClient(_answer);
  }

  /// The HTTP boundary handed to the app.
  late final FakeBridgeHttpClient httpClient;

  /// Pages the job reports as drawn once it ends.
  int completedPageCount = _pageCount;

  /// Pages the job reports as attempted and failed.
  int failedPageCount = 0;

  /// Polls answered as still rendering before the job reaches its end state.
  int pollsBeforeTerminal = 1;

  /// Images the PC answers `409 illustration_not_ready` for.
  List<String> notReadyIds = const <String>[];

  /// Images whose download fails as an unreachable PC.
  List<String> unreachableIds = const <String>[];

  /// Whether every call fails as an unreachable PC.
  bool isOffline = false;

  /// Whether the photo upload is refused as too large.
  bool refusePhoto = false;

  /// Runs on the first job poll, so a test can act while the PC is working.
  void Function()? onJobPoll;

  /// Content type the app sent the photo with, absent until it does.
  String? photoContentType;

  /// Identities the PC answered `304 Not Modified` for.
  final List<String> unchangedIds = <String>[];

  int _polls = 0;
  bool _cancelled = false;

  /// Answers one bridge call from the current scripted state.
  Future<http.Response> _answer(http.Request request) async {
    final path = request.url.path;
    if (isOffline) {
      throw http.ClientException('Connection refused.', request.url);
    }
    if (path == '/profiles/miko/photo') {
      if (refusePhoto) return bridgeErrorResponse('photo_too_large', 413);
      photoContentType = request.headers['content-type'];
      return bridgeJsonResponse(<String, Object>{
        'profileId': 'miko',
        'relativePath': 'profiles/miko/photo.png',
        'contentType': request.headers['content-type']!,
        'sizeBytes': request.bodyBytes.length,
      });
    }
    if (path == '/stories/story-a/illustrate') {
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'illustration-job-1',
        'pageCount': _pageCount,
        'queuePosition': 1,
      }, statusCode: 202);
    }
    if (path == _cancelPath) {
      _cancelled = true;
      return bridgeJsonResponse(<String, Object>{
        'jobId': 'illustration-job-1',
        'status': 'cancelled',
      });
    }
    if (path == '/illustrations/jobs/illustration-job-1') {
      return bridgeJsonResponse(_jobPayload());
    }
    if (path.startsWith('/sync/illustrations/')) {
      return _imageAnswer(request, path);
    }
    return bridgeErrorResponse('invalid_request', 400);
  }

  /// Reports the job as rendering until it reaches its scripted end state.
  Map<String, Object> _jobPayload() {
    _polls++;
    if (_polls == 1) onJobPoll?.call();
    final isTerminal = _cancelled || _polls >= pollsBeforeTerminal;
    return <String, Object>{
      'jobId': 'illustration-job-1',
      'storyId': 'story-a',
      'status': isTerminal
          ? (_cancelled ? 'cancelled' : 'completed')
          : 'rendering',
      'progress': 'Drawing.',
      'pageCount': _pageCount,
      'completedPageCount': isTerminal ? completedPageCount : 0,
      'failedPageCount': isTerminal ? failedPageCount : 0,
    };
  }

  /// Serves one page image, its 304, or the reason it is not available.
  http.Response _imageAnswer(http.Request request, String path) {
    final illustrationId = path.substring('/sync/illustrations/'.length);
    if (unreachableIds.contains(illustrationId)) {
      throw http.ClientException('Connection refused.', request.url);
    }
    if (notReadyIds.contains(illustrationId)) {
      return bridgeErrorResponse('illustration_not_ready', 409);
    }
    final eTag = 'etag-$illustrationId';
    if (request.headers['if-none-match'] == eTag) {
      unchangedIds.add(illustrationId);
      return http.Response.bytes(Uint8List(0), 304);
    }
    return http.Response.bytes(
      Uint8List.fromList(<int>[0x89, 0x50, 0x4E, 0x47, illustrationId.length]),
      200,
      headers: <String, String>{'content-type': 'image/png', 'etag': eTag},
    );
  }
}
