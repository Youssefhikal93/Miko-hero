import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies that commands aimed at deleted content stay recoverable.
///
/// Every failure must be an `Exception`, because the generation center and the
/// library catch `on Exception` to show a snackbar; an `Error` would instead
/// crash the screen the parent is standing in front of.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('retrying a request that no longer exists is recoverable', () async {
    final container = await _familyContainer();
    final controller = container.read(storyControllerProvider);

    await expectLater(
      controller.retryGeneration('generation-missing'),
      throwsA(isA<UnknownEntityException>()),
    );
    await expectLater(
      controller.retryGeneration('generation-missing'),
      throwsA(isA<Exception>()),
    );
  });

  test('cancelling a request that no longer exists is recoverable', () async {
    final container = await _familyContainer();
    final controller = container.read(storyControllerProvider);

    await expectLater(
      controller.cancelGeneration('generation-missing'),
      throwsA(isA<UnknownEntityException>()),
    );
    await expectLater(
      controller.cancelGeneration('generation-missing'),
      throwsA(isA<Exception>()),
    );
  });

  test('favouriting a deleted story is recoverable', () async {
    final container = await _familyContainer(stories: <StoryBook>[_story()]);
    final controller = container.read(storyControllerProvider);
    await controller.deleteStory('story-moon');

    await expectLater(
      controller.toggleFavorite('story-moon'),
      throwsA(isA<UnknownEntityException>()),
    );
    await expectLater(
      controller.setCollections('story-moon', <String>['Bedtime']),
      throwsA(isA<Exception>()),
    );
  });

  test('creating a story for a deleted child is recoverable', () async {
    final container = await _familyContainer();
    final controller = container.read(storyControllerProvider);

    await expectLater(
      controller.createStory(_request(profileId: 'deleted-child')),
      throwsA(isA<UnknownEntityException>()),
    );
  });
}

/// Opens a container over real persisted state with one saved child profile.
Future<ProviderContainer> _familyContainer({
  List<StoryBook> stories = const <StoryBook>[],
}) async {
  final repository = await LocalRepository.open();
  await repository.saveProfiles(const <ChildProfile>[
    ChildProfile(
      id: 'miko',
      name: 'Miko',
      legacyAge: 8,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
    ),
  ]);
  await repository.saveStories(stories);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  return container;
}

/// Builds one saved book belonging to the container's only child.
StoryBook _story() {
  return StoryBook(
    id: 'story-moon',
    createdAt: DateTime.utc(2026, 8, 18),
    content: StoryContent(
      title: 'Moon Garden',
      request: _request(profileId: 'miko'),
      pages: const <StoryPage>[
        StoryPage(
          number: 1,
          text: 'A kind beginning.',
          sceneDescription: 'A moonlit garden.',
        ),
      ],
    ),
    reviewStatus: StoryReviewStatus.approved,
  );
}

/// Builds a complete request for one child identity.
StoryRequest _request({required String profileId}) {
  return StoryRequest(
    hero: StoryHero(
      profileId: profileId,
      name: 'Miko',
      gender: ChildGender.girl,
    ),
    prompt: const StoryPrompt(
      theme: 'moon garden',
      moral: 'kindness',
      preferences: ChildStoryPreferences(),
    ),
    presentation: const StoryPresentation(
      language: AppLanguage.english,
      length: StoryLength.short,
      style: IllustrationStyle.watercolor,
    ),
  );
}
