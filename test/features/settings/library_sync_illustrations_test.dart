import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';
import '../../support/in_memory_illustration_store.dart';

/// Verifies which page pictures a sync brings onto this device, and which not.
///
/// The whole app path runs for real — the typed client, the sync service, the
/// controller, and preference storage — with only the PC's HTTP boundary and the
/// platform image cache replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a sync brings the finished pictures of its stories along', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);

    final result = await container
        .read(librarySyncControllerProvider.notifier)
        .syncNow();

    expect(result.addedCount, 1);
    expect(result.savedPictureCount, 6);
    expect(result.failedPictureCount, 0);
    expect(store.holds('story-a-picture-1'), isTrue);
    expect(store.holds('story-a-picture-2'), isTrue);
    final cached = await store.read('story-a-picture-1');
    expect(cached!.eTag, 'etag-story-a-picture-1');
  });

  test('a page the PC has not drawn yet is never asked for', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'pending'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);

    final result = await container
        .read(librarySyncControllerProvider.notifier)
        .syncNow();

    expect(result.addedCount, 1);
    expect(result.savedPictureCount, 0);
    expect(
      bridge.httpClient.callsTo('/sync/illustrations/story-a-picture-1'),
      0,
    );
    expect(store.illustrationIds, isEmpty);
  });

  test('a second sync re-checks the pictures without refetching them', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();

    final second = await controller.syncNow();

    expect(second.changedNothing, isTrue, reason: 'the shelf did not change');
    expect(second.savedPictureCount, 0);
    expect(second.failedPictureCount, 0);
    expect(bridge.unchangedIds, <String>[
      for (var number = 1; number <= 6; number++) 'story-a-picture-$number',
    ]);
    // The story itself is never transferred twice; only the cheap 304s repeat.
    expect(bridge.httpClient.callsTo('/sync/stories/story-a'), 1);
  });

  test('a picture that changed on the PC replaces the cached one', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    bridge.eTagSuffix = '-redrawn';

    final second = await controller.syncNow();

    expect(second.savedPictureCount, 6);
    final cached = await store.read('story-a-picture-1');
    expect(cached!.eTag, 'etag-story-a-picture-1-redrawn');
  });

  test('one refused picture never fails the whole sync', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    )..unreachableIds = const <String>['story-a-picture-2'];
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);

    final result = await container
        .read(librarySyncControllerProvider.notifier)
        .syncNow();

    expect(result.addedCount, 1, reason: 'the story still arrived');
    expect(result.savedPictureCount, 5);
    expect(result.failedPictureCount, 1);
    expect(store.holds('story-a-picture-1'), isTrue);
    expect(store.holds('story-a-picture-2'), isFalse);
    final stories = container.read(appControllerProvider).requireValue.stories;
    expect(stories.single.id, 'story-a');
  });

  test('a cache that refuses one write never fails the sync', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore()
      ..unwritableIllustrationId = 'story-a-picture-1';
    final container = await _pairedContainer(bridge, store);

    final result = await container
        .read(librarySyncControllerProvider.notifier)
        .syncNow();

    expect(result.addedCount, 1);
    expect(result.savedPictureCount, 5);
    expect(result.failedPictureCount, 1);
    expect(store.holds('story-a-picture-2'), isTrue);
  });

  test('a story kept off this device gets no pictures either', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
        _story(id: 'story-b', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    await controller.removeFromThisDevice('story-b');

    final result = await controller.syncNow();

    expect(result.addedCount, 0);
    expect(store.holds('story-a-picture-1'), isTrue);
    expect(store.holds('story-b-picture-1'), isFalse);
    expect(bridge.callsFor('story-b-picture-1'), 1, reason: 'only the first');
  });

  test('removing a story from this device clears its pictures', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    expect(store.illustrationIds, hasLength(6));
    // An open reader is holding the first page, so it has to be told that the
    // picture behind it is gone rather than keep showing a stale one.
    container.listen(
      illustrationBytesProvider('story-a-picture-1'),
      (previous, next) {},
      fireImmediately: true,
    );
    expect(
      await container.read(
        illustrationBytesProvider('story-a-picture-1').future,
      ),
      isNotEmpty,
    );

    await controller.removeFromThisDevice('story-a');

    expect(store.illustrationIds, isEmpty);
    expect(
      await container.read(
        illustrationBytesProvider('story-a-picture-1').future,
      ),
      isNull,
    );
  });

  test('deleting a story everywhere clears its pictures too', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();

    await controller.deleteEverywhere('story-a');

    expect(bridge.httpClient.callsTo('/stories/story-a/delete'), 1);
    expect(store.illustrationIds, isEmpty);
  });

  test('a deletion the PC recorded clears the cached pictures', () async {
    final bridge = _FakeIllustratedBridge(
      stories: <Map<String, Object>>[
        _story(id: 'story-a', illustrationStatus: 'completed'),
      ],
    );
    final store = InMemoryIllustrationStore();
    final container = await _pairedContainer(bridge, store);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();

    bridge
      ..stories = const <Map<String, Object>>[]
      ..deletions = <Map<String, Object>>[
        bridgeManifestDeletion(entityId: 'story-a'),
      ];
    final result = await controller.syncNow();

    expect(result.removedCount, 1);
    expect(store.illustrationIds, isEmpty);
  });
}

/// Builds one manifest story whose pictures use a story-specific identity.
Map<String, Object> _story({
  required String id,
  required String illustrationStatus,
}) {
  return bridgeManifestStory(
    id: id,
    profileId: 'miko',
    pageCount: 6,
    illustrationStatus: illustrationStatus,
    illustrationIdPrefix: '$id-picture',
  );
}

/// Opens a container for a paired Local AI family with a replaceable cache.
Future<ProviderContainer> _pairedContainer(
  _FakeIllustratedBridge bridge,
  InMemoryIllustrationStore store,
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
      bridgeHttpClientProvider.overrideWithValue(bridge.httpClient),
      illustrationStoreProvider.overrideWithValue(store),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  await container.read(aiConnectionControllerProvider.future);
  await container.read(librarySyncControllerProvider.future);
  return container;
}

/// One scripted PC library that also serves its finished page images.
class _FakeIllustratedBridge {
  /// Creates a bridge whose manifest the test can change between syncs.
  _FakeIllustratedBridge({required this.stories}) {
    httpClient = FakeBridgeHttpClient(_answer);
  }

  /// The HTTP boundary handed to the app.
  late final FakeBridgeHttpClient httpClient;

  /// Stories the manifest advertises.
  List<Map<String, Object>> stories;

  /// Deletion records the manifest advertises.
  List<Map<String, Object>> deletions = const <Map<String, Object>>[];

  /// Suffix added to every served ETag, so a test can redraw the pictures.
  String eTagSuffix = '';

  /// Images whose download fails as an unreachable PC.
  List<String> unreachableIds = const <String>[];

  /// Identities the PC answered `304 Not Modified` for, in order.
  final List<String> unchangedIds = <String>[];

  /// How many times one page image was asked for.
  int callsFor(String illustrationId) {
    return httpClient.callsTo('/sync/illustrations/$illustrationId');
  }

  /// Answers one bridge call from the current scripted library.
  Future<http.Response> _answer(http.Request request) async {
    final path = request.url.path;
    if (path == '/sync/manifest') {
      return bridgeJsonResponse(
        bridgeManifestPayload(
          profiles: <Map<String, Object>>[
            bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
          ],
          stories: stories,
          deletions: deletions,
        ),
      );
    }
    if (path.startsWith('/sync/illustrations/')) {
      return _imageAnswer(request, path);
    }
    if (path.startsWith('/sync/stories/')) {
      return _storyAnswer(path);
    }
    if (path == '/sync/complete') {
      return bridgeJsonResponse(<String, Object>{
        'deviceId': 'device-1',
        'lastSyncedAtUtc': '2026-08-22T11:00:00.000Z',
      });
    }
    if (path.endsWith('/delete')) {
      return bridgeJsonResponse(<String, Object>{
        'storyId': path.split('/')[2],
        'alreadyDeleted': false,
        'deletedAtUtc': '2026-08-22T11:05:00.000Z',
        'removedFileCount': 2,
      });
    }
    return bridgeErrorResponse('invalid_request', 400);
  }

  /// Serves one complete story whose pages carry story-specific picture ids.
  http.Response _storyAnswer(String path) {
    final storyId = path.substring('/sync/stories/'.length);
    final entry = stories.firstWhere(
      (story) => story['id'] == storyId,
      orElse: () => <String, Object>{},
    );
    if (entry.isEmpty) return bridgeErrorResponse('story_not_found', 404);
    return bridgeJsonResponse(<String, Object>{
      'story': bridgeStoryPayload(
        storyId: storyId,
        languageCode: entry['languageCode']! as String,
        pageCount: entry['pageCount']! as int,
        title: entry['title']! as String,
        profileId: entry['profileId']! as String,
        createdAtUtc: entry['createdAtUtc']! as String,
        updatedAtUtc: entry['updatedAtUtc']! as String,
        illustrationIdPrefix: '$storyId-picture',
      ),
    });
  }

  /// Serves one page image, its 304, or the reason it cannot be served.
  http.Response _imageAnswer(http.Request request, String path) {
    final illustrationId = path.substring('/sync/illustrations/'.length);
    if (unreachableIds.contains(illustrationId)) {
      throw http.ClientException('Connection refused.', request.url);
    }
    final eTag = 'etag-$illustrationId$eTagSuffix';
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
