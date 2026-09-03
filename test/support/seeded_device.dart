/// One seeded device, shaped in one place.
///
/// Every value is written through the real models and the real repository, so
/// a seed that no build could ever have produced fails at [seedDevice] instead
/// of quietly decoding into something the app never stores. That also keeps
/// the preference key names out of the test suite entirely: only
/// `LocalRepository` knows them, which is what `docs/CODEBASE.md` claims.
///
/// Suites whose subject *is* the stored wire format — `local_repository_test`
/// and the schema-migration cases — still write their own JSON on purpose.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` is the type of a `ProviderScope` entry, but only this library of
// the package exports the name itself.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'in_memory_illustration_store.dart';

/// A one-pixel PNG: the smallest reference photo a profile can really carry.
///
/// Real PNG bytes, so a surface that decodes the photo gets a valid image.
const transparentPixelPhoto =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Moment every seeded book is created at unless a test needs its own order.
final DateTime seededStoryCreatedAt = DateTime.utc(2026, 8, 17, 12);

/// Builds one valid child profile with the defaults most suites want.
///
/// [themeColorValue] and [hasCustomThemeColor] follow the storage boundary's
/// own rule: a profile that names no color takes the palette its gender starts
/// with and counts as untouched, and one that names a color counts as a
/// parent's deliberate choice unless the test says otherwise.
ChildProfile child({
  String id = 'miko',
  String name = 'Miko',
  ChildGender gender = ChildGender.girl,
  int legacyAge = 7,
  DateTime? birthDate,
  String photoBase64 = transparentPixelPhoto,
  int? themeColorValue,
  bool? hasCustomThemeColor,
  ChildStoryPreferences storyPreferences = const ChildStoryPreferences(),
  KingdomTheme kingdomTheme = const KingdomTheme(),
  ChildReadingSettings readingSettings = const ChildReadingSettings(),
  List<String> finishedStoryIds = const <String>[],
}) {
  return ChildProfile(
    id: id,
    name: name,
    legacyAge: legacyAge,
    birthDate: birthDate,
    photoBase64: photoBase64,
    gender: gender,
    themeColorValue: themeColorValue ?? defaultProfileThemeColorValue(gender),
    hasCustomThemeColor: hasCustomThemeColor ?? (themeColorValue != null),
    storyPreferences: storyPreferences,
    kingdomTheme: kingdomTheme,
    readingSettings: readingSettings,
    finishedStoryIds: finishedStoryIds,
  );
}

/// Builds one numbered reader page, for a book whose prose a test asserts on.
StoryPage storyPage(
  int number,
  String text, {
  String scene = 'a glowing garden',
}) {
  return StoryPage(number: number, text: text, sceneDescription: scene);
}

/// Builds one stored book owned by [profileId].
///
/// Pass [pages] when the exact prose or scene of a page is the subject of the
/// test; otherwise [pageCount] generic pages are written, which is enough for
/// a page counter, a cover, or a shelf card.
StoryBook book({
  required String profileId,
  String id = 'story-1',
  String title = 'The moon garden',
  String heroName = 'Miko',
  ChildGender gender = ChildGender.girl,
  DateTime? createdAt,
  List<StoryPage> pages = const <StoryPage>[],
  int pageCount = 2,
  String sceneDescription = 'a glowing garden',
  String theme = 'a moon garden',
  String moral = 'kindness',
  ChildStoryPreferences preferences = const ChildStoryPreferences(),
  AppLanguage language = AppLanguage.english,
  StoryLength length = StoryLength.short,
  IllustrationStyle style = IllustrationStyle.pictureBook,
  StoryReviewStatus reviewStatus = StoryReviewStatus.approved,
  bool isFavorite = false,
  List<String> collections = const <String>[],
}) {
  return StoryBook(
    id: id,
    createdAt: createdAt ?? seededStoryCreatedAt,
    reviewStatus: reviewStatus,
    isFavorite: isFavorite,
    collections: collections,
    content: StoryContent(
      title: title,
      request: StoryRequest(
        hero: StoryHero(profileId: profileId, name: heroName, gender: gender),
        prompt: StoryPrompt(
          theme: theme,
          moral: moral,
          preferences: preferences,
        ),
        presentation: StoryPresentation(
          language: language,
          length: length,
          style: style,
        ),
      ),
      pages: pages.isNotEmpty
          ? pages
          : <StoryPage>[
              for (var number = 1; number <= pageCount; number++)
                storyPage(
                  number,
                  'Page $number prose.',
                  scene: sceneDescription,
                ),
            ],
    ),
  );
}

/// The Local AI selection a paired family keeps on this device.
AiConnectionSettings localAiConnection({String? baseUrl}) {
  return AiConnectionSettings(
    mode: StoryGeneratorMode.localAi,
    baseUrl: Uri.parse(baseUrl ?? defaultBridgeBaseUrl),
  );
}

/// The pairing record a device holds once the parent has paired it with a PC.
BridgeCredential pairedDevice({
  String deviceToken = 'device-token',
  String deviceName = 'Family tablet',
  DateTime? pairedAtUtc,
}) {
  return BridgeCredential(
    deviceToken: deviceToken,
    deviceName: deviceName,
    pairedAtUtc: pairedAtUtc ?? DateTime.utc(2026, 8, 22, 9),
  );
}

/// Pairing store the most recent [seedDevice] wrote into.
///
/// [pumpApp] hands the application this same instance, so a seeded pairing is
/// the one the app reads back. A protected platform store is never touched.
BridgeCredentialStorage get seededBridgeCredentialStorage {
  return _credentialStorage ??= InMemoryBridgeCredentialStorage();
}

InMemoryBridgeCredentialStorage? _credentialStorage;

/// Replaces this device's stored state with exactly what is passed here.
///
/// Writes go through a real [LocalRepository] over an empty preference store,
/// so the values the app reads back are the values the app itself would have
/// written, down to the schema version stamp.
Future<void> seedDevice({
  List<ChildProfile> profiles = const <ChildProfile>[],
  List<StoryBook> stories = const <StoryBook>[],
  String? activeProfileId,
  Locale? locale,
  AiConnectionSettings? aiConnection,
  BridgeCredential? bridgeCredential,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final credentialStorage = InMemoryBridgeCredentialStorage();
  _credentialStorage = credentialStorage;
  final repository = await LocalRepository.open(
    bridgeCredentialStorage: credentialStorage,
  );
  if (locale != null) await repository.saveLocale(locale);
  if (profiles.isNotEmpty) await repository.saveProfiles(profiles);
  if (stories.isNotEmpty) await repository.saveStories(stories);
  if (activeProfileId != null) {
    await repository.saveActiveProfileId(activeProfileId);
  }
  if (aiConnection != null) {
    await repository.saveAiConnectionSettings(aiConnection);
  }
  if (bridgeCredential != null) {
    await repository.saveBridgeCredential(bridgeCredential);
  }
}

/// Builds the real application over test-safe device boundaries and settles it.
///
/// The pairing store and the page-image cache are always replaced: the real
/// ones reach for platform-protected storage and for this machine's
/// application folder, which a widget test must never touch. Everything else
/// — the router, the controllers, and preference storage — runs for real.
Future<void> pumpApp(
  WidgetTester tester, {
  String? route,
  List<Override> overrides = const <Override>[],
  InMemoryIllustrationStore? illustrationStore,
}) async {
  if (route != null) appRouter.go(route);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        bridgeCredentialStorageProvider.overrideWithValue(
          seededBridgeCredentialStorage,
        ),
        illustrationStoreProvider.overrideWithValue(
          illustrationStore ?? InMemoryIllustrationStore(),
        ),
        ...overrides,
      ],
      child: const IamHeroApp(),
    ),
  );
  await tester.pumpAndSettle();
}
