import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';

/// Verifies what a device ends up holding after talking to the PC library.
///
/// The whole app path runs for real — the typed client, the sync service, the
/// controllers, and preference storage — with only the PC's HTTP boundary
/// replaced, so every assertion is about persisted family content.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('a first sync downloads every story onto the right shelf', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
        bridgeManifestProfile(id: 'abbas', displayName: 'Abbas'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
        bridgeManifestStory(
          id: 'story-b',
          profileId: 'abbas',
          title: 'The Brave Kite',
          pageCount: 8,
        ),
      ],
    );
    final container = await _pairedContainer(bridge);

    final result = await container
        .read(librarySyncControllerProvider.notifier)
        .syncNow();

    expect(result.addedCount, 2);
    expect(result.updatedCount, 0);
    expect(result.removedCount, 0);
    final state = container.read(appControllerProvider).requireValue;
    expect(state.storiesForProfile('miko').single.id, 'story-a');
    final kite = state.storiesForProfile('abbas').single;
    expect(kite.id, 'story-b');
    expect(kite.content.title, 'The Brave Kite');
    expect(kite.content.pages, hasLength(8));
    expect(kite.reviewStatus, StoryReviewStatus.approved);
    expect(
      kite.content.request.presentation.length.pageCount,
      kite.content.pages.length,
    );
    final provenance = BridgeStoryProvenance.fromSceneDescription(
      kite.content.pages.first.sceneDescription,
    );
    expect(provenance?.storyId, 'story-b');
    expect(provenance?.illustrationId, 'illustration-1');
    expect(provenance?.scene, 'A lantern scene 1.');
    // The whole library, stories included, is what local storage already
    // persists, so what a second launch reads is what stays readable offline.
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.stories, hasLength(2));
  });

  test('a second sync downloads nothing and changes nothing', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);

    await controller.syncNow();
    final firstPass = container.read(appControllerProvider).requireValue;
    final second = await controller.syncNow();

    expect(second.changedNothing, isTrue);
    expect(bridge.httpClient.callsTo('/sync/stories/story-a'), 1);
    expect(bridge.httpClient.callsTo('/sync/complete'), 2);
    final stories = container.read(appControllerProvider).requireValue.stories;
    expect(stories, hasLength(1));
    expect(stories.single.id, firstPass.stories.single.id);
    expect(
      stories.single.content.title,
      firstPass.stories.single.content.title,
    );
  });

  test('a story whose PC copy changed is downloaded again', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    await container.read(storyControllerProvider).toggleFavorite('story-a');

    bridge.stories = <Map<String, Object>>[
      bridgeManifestStory(
        id: 'story-a',
        profileId: 'miko',
        title: 'The Lantern Path, retold',
        updatedAtUtc: '2026-08-22T12:00:00.000Z',
      ),
    ];

    final result = await controller.syncNow();

    expect(result.addedCount, 0);
    expect(result.updatedCount, 1);
    final story = container
        .read(appControllerProvider)
        .requireValue
        .stories
        .single;
    expect(story.content.title, 'The Lantern Path, retold');
    expect(story.isFavorite, isTrue, reason: 'local metadata survives');
    expect(bridge.httpClient.callsTo('/sync/stories/story-a'), 2);
  });

  test('a deletion record removes the local copy and its badge', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    await container
        .read(profileControllerProvider)
        .recordFinishedStory('miko', 'story-a');

    bridge
      ..stories = const <Map<String, Object>>[]
      ..deletions = <Map<String, Object>>[
        bridgeManifestDeletion(entityId: 'story-a'),
      ];
    final result = await controller.syncNow();

    expect(result.removedCount, 1);
    final state = container.read(appControllerProvider).requireValue;
    expect(state.stories, isEmpty);
    expect(state.profileById('miko')!.finishedStoryIds, isEmpty);
  });

  test('a deletion record also cleans a story kept off this device', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    await controller.removeFromThisDevice('story-a');
    expect(
      container
          .read(librarySyncControllerProvider)
          .requireValue
          .hasDeclinedStories,
      isTrue,
    );

    bridge
      ..stories = const <Map<String, Object>>[]
      ..deletions = <Map<String, Object>>[
        bridgeManifestDeletion(entityId: 'story-a'),
      ];
    await controller.syncNow();

    final snapshot = container.read(librarySyncControllerProvider).requireValue;
    expect(snapshot.hasDeclinedStories, isFalse);
    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
  });

  test('a story removed from this device is not downloaded again', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();

    await controller.removeFromThisDevice('story-a');

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    expect(bridge.httpClient.callsTo('/stories/story-a/delete'), 0);
    final result = await controller.syncNow();
    expect(result.addedCount, 0);
    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    expect(bridge.httpClient.callsTo('/sync/stories/story-a'), 1);
  });

  test('the re-download control brings a removed story back', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    await controller.removeFromThisDevice('story-a');

    await controller.allowRemovedStoriesAgain();
    final result = await controller.syncNow();

    expect(result.addedCount, 1);
    expect(
      container.read(appControllerProvider).requireValue.stories.single.id,
      'story-a',
    );
    expect(
      container
          .read(librarySyncControllerProvider)
          .requireValue
          .hasDeclinedStories,
      isFalse,
    );
  });

  test('deleting everywhere asks the PC first and then removes it', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();

    final deletion = await controller.deleteEverywhere('story-a');

    expect(deletion.alreadyDeleted, isFalse);
    expect(bridge.httpClient.callsTo('/stories/story-a/delete'), 1);
    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    final snapshot = container.read(librarySyncControllerProvider).requireValue;
    expect(snapshot.hasDeclinedStories, isFalse);
  });

  test('deleting everywhere without the PC changes nothing here', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    );
    final container = await _pairedContainer(bridge);
    final controller = container.read(librarySyncControllerProvider.notifier);
    await controller.syncNow();
    bridge.isOffline = true;

    await expectLater(
      controller.deleteEverywhere('story-a'),
      throwsA(_failure(BridgeFailure.unreachable)),
    );

    expect(
      container.read(appControllerProvider).requireValue.stories.single.id,
      'story-a',
    );
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.stories, hasLength(1));
  });

  test('stories for an unknown child are reported, never invented', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
        bridgeManifestProfile(id: 'nour', displayName: 'Nour'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
        bridgeManifestStory(id: 'story-c', profileId: 'nour'),
        bridgeManifestStory(id: 'story-d', profileId: 'nour'),
      ],
    );
    final container = await _pairedContainer(bridge);

    final result = await container
        .read(librarySyncControllerProvider.notifier)
        .syncNow();

    expect(result.addedCount, 1);
    final pending = result.pendingProfiles.single;
    expect(pending.profileId, 'nour');
    expect(pending.displayName, 'Nour');
    expect(pending.storyCount, 2);
    final state = container.read(appControllerProvider).requireValue;
    expect(state.profileById('nour'), isNull, reason: 'no profile is invented');
    expect(state.profiles, hasLength(2));
    expect(state.stories.single.id, 'story-a');
    expect(bridge.httpClient.callsTo('/sync/stories/story-c'), 0);
    expect(bridge.httpClient.callsTo('/sync/stories/story-d'), 0);
  });

  test('a failure part way through the downloads changes nothing', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
        bridgeManifestStory(id: 'story-b', profileId: 'miko'),
      ],
    )..unreachableStoryId = 'story-b';
    final container = await _pairedContainer(bridge);

    await expectLater(
      container.read(librarySyncControllerProvider.notifier).syncNow(),
      throwsA(_failure(BridgeFailure.unreachable)),
    );

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
    expect(bridge.httpClient.callsTo('/sync/complete'), 0);
    final snapshot = container.read(librarySyncControllerProvider).requireValue;
    expect(snapshot.lastSyncedAtUtc, isNull);
    expect(snapshot.lastResult, isNull);
    expect(snapshot.lastFailure, isA<BridgeException>());
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.stories, isEmpty);
  });

  test('a failed report back to the PC changes nothing either', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
      stories: <Map<String, Object>>[
        bridgeManifestStory(id: 'story-a', profileId: 'miko'),
      ],
    )..refuseCompletion = true;
    final container = await _pairedContainer(bridge);

    await expectLater(
      container.read(librarySyncControllerProvider.notifier).syncNow(),
      throwsA(_failure(BridgeFailure.unauthorized)),
    );

    expect(container.read(appControllerProvider).requireValue.stories, isEmpty);
  });

  test(
    'Arabic prose survives the manifest, the download, and storage',
    () async {
      const arabicTitle = 'مصباح نور';
      const arabicPage = 'صفحة عربية';
      final bridge = _FakeBridge(
        profiles: <Map<String, Object>>[
          bridgeManifestProfile(id: 'miko', displayName: 'ميكو'),
        ],
        stories: <Map<String, Object>>[
          bridgeManifestStory(
            id: 'story-ar',
            profileId: 'miko',
            title: arabicTitle,
            languageCode: 'ar',
          ),
        ],
      )..pageTextPrefix = arabicPage;
      final container = await _pairedContainer(bridge);

      await container.read(librarySyncControllerProvider.notifier).syncNow();

      final reopened = await (await LocalRepository.open()).readState();
      final story = reopened.stories.single;
      expect(story.content.title, arabicTitle);
      expect(story.content.pages.first.text, '$arabicPage 1.');
      expect(story.content.request.presentation.language, AppLanguage.arabic);
    },
  );

  test('an unpaired device is told to pair instead of syncing', () async {
    final bridge = _FakeBridge(
      profiles: <Map<String, Object>>[
        bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
      ],
    );
    final container = await _pairedContainer(bridge, isPaired: false);

    await expectLater(
      container.read(librarySyncControllerProvider.notifier).syncNow(),
      throwsA(_failure(BridgeFailure.notPaired)),
    );
    expect(bridge.httpClient.requests, isEmpty);
  });

  test(
    'the automatic start-up sync runs once, and only for local AI',
    () async {
      final bridge = _FakeBridge(
        profiles: <Map<String, Object>>[
          bridgeManifestProfile(id: 'miko', displayName: 'Miko'),
        ],
        stories: <Map<String, Object>>[
          bridgeManifestStory(id: 'story-a', profileId: 'miko'),
        ],
      );
      final demoContainer = await _pairedContainer(bridge, usesLocalAi: false);

      await demoContainer
          .read(librarySyncControllerProvider.notifier)
          .syncAfterAppStart();
      expect(bridge.httpClient.requests, isEmpty);

      final container = await _pairedContainer(bridge);
      final controller = container.read(librarySyncControllerProvider.notifier);
      await controller.syncAfterAppStart();
      await controller.syncAfterAppStart();

      expect(bridge.httpClient.callsTo('/sync/manifest'), 1);
      expect(
        container.read(appControllerProvider).requireValue.stories.single.id,
        'story-a',
      );
    },
  );
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
  _FakeBridge bridge, {
  bool isPaired = true,
  bool usesLocalAi = true,
}) async {
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
    ChildProfile(
      id: 'abbas',
      name: 'Abbas',
      legacyAge: 5,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.boy,
      themeColorValue: cyanProfileThemeColorValue,
      hasCustomThemeColor: false,
    ),
  ]);
  await repository.saveAiConnectionSettings(
    AiConnectionSettings(
      mode: usesLocalAi ? StoryGeneratorMode.localAi : StoryGeneratorMode.demo,
      baseUrl: Uri.parse(defaultBridgeBaseUrl),
    ),
  );
  if (isPaired) {
    await repository.saveBridgeCredential(
      BridgeCredential(
        deviceToken: 'device-token',
        deviceName: 'Family tablet',
        pairedAtUtc: DateTime.utc(2026, 8, 22),
      ),
    );
  }
  final container = ProviderContainer(
    overrides: [bridgeHttpClientProvider.overrideWithValue(bridge.httpClient)],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  await container.read(aiConnectionControllerProvider.future);
  await container.read(librarySyncControllerProvider.future);
  return container;
}

/// One scripted PC library that answers the four synchronization endpoints.
class _FakeBridge {
  /// Creates a bridge whose manifest the test can change between syncs.
  _FakeBridge({
    this.profiles = const <Map<String, Object>>[],
    this.stories = const <Map<String, Object>>[],
  }) {
    httpClient = FakeBridgeHttpClient(_answer);
  }

  /// The HTTP boundary handed to the app.
  late final FakeBridgeHttpClient httpClient;

  /// Profiles the manifest advertises.
  List<Map<String, Object>> profiles;

  /// Stories the manifest advertises.
  List<Map<String, Object>> stories;

  /// Deletion records the manifest advertises.
  List<Map<String, Object>> deletions = const <Map<String, Object>>[];

  /// Page-text prefix every downloaded story carries.
  String? pageTextPrefix;

  /// Story identity whose download fails as an unreachable PC.
  String? unreachableStoryId;

  /// Whether every call fails as an unreachable PC.
  bool isOffline = false;

  /// Whether the report back to the PC is refused.
  bool refuseCompletion = false;

  /// Answers one bridge call from the current scripted library.
  Future<http.Response> _answer(http.Request request) async {
    final path = request.url.path;
    if (isOffline) {
      throw http.ClientException('Connection refused.', request.url);
    }
    if (path == '/sync/manifest') {
      return bridgeJsonResponse(
        bridgeManifestPayload(
          profiles: profiles,
          stories: stories,
          deletions: deletions,
        ),
      );
    }
    if (path.startsWith('/sync/stories/')) {
      final storyId = path.substring('/sync/stories/'.length);
      if (storyId == unreachableStoryId) {
        throw http.ClientException('Connection refused.', request.url);
      }
      final entry = stories.firstWhere(
        (story) => story['id'] == storyId,
        orElse: () => <String, Object>{},
      );
      if (entry.isEmpty) {
        return bridgeErrorResponse('story_not_found', 404);
      }
      return bridgeJsonResponse(<String, Object>{
        'story': bridgeStoryPayload(
          storyId: storyId,
          languageCode: entry['languageCode']! as String,
          pageCount: entry['pageCount']! as int,
          title: entry['title']! as String,
          profileId: entry['profileId']! as String,
          createdAtUtc: entry['createdAtUtc']! as String,
          updatedAtUtc: entry['updatedAtUtc']! as String,
          pageTextPrefix: pageTextPrefix,
        ),
      });
    }
    if (path == '/sync/complete') {
      if (refuseCompletion) return bridgeErrorResponse('unauthorized', 401);
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
        'removedFileCount': 0,
      });
    }
    return bridgeErrorResponse('invalid_request', 400);
  }
}
