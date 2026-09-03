import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/reading_badge.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';

import '../../support/seeded_device.dart';

/// Verifies the local reading rewards a child earns by finishing stories.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('badges are earned at one, five, ten, and twenty-five stories', () {
    expect(ReadingBadge.earnedWith(0), isEmpty);
    expect(ReadingBadge.earnedWith(1), <ReadingBadge>[ReadingBadge.firstStory]);
    expect(ReadingBadge.earnedWith(4), <ReadingBadge>[ReadingBadge.firstStory]);
    expect(ReadingBadge.earnedWith(5), <ReadingBadge>[
      ReadingBadge.firstStory,
      ReadingBadge.fiveStories,
    ]);
    expect(ReadingBadge.earnedWith(25), ReadingBadge.values);
    expect(ReadingBadge.reachedAt(1), ReadingBadge.firstStory);
    expect(ReadingBadge.reachedAt(10), ReadingBadge.tenStories);
    expect(ReadingBadge.reachedAt(11), isNull);
    expect(ReadingBadge.nextAfter(1), ReadingBadge.fiveStories);
    expect(ReadingBadge.nextAfter(25), isNull);
  });

  test('finishing a story counts it once and reports the new badge', () async {
    final container = await _familyContainer();
    final controller = container.read(profileControllerProvider);

    final firstBadge = await controller.recordFinishedStory(
      'miko',
      'story-moon',
    );
    final repeatBadge = await controller.recordFinishedStory(
      'miko',
      'story-moon',
    );

    expect(firstBadge, ReadingBadge.firstStory);
    expect(repeatBadge, isNull);
    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.profileById('miko')!.finishedStoryIds, <String>[
      'story-moon',
    ]);
    expect(reopened.profileById('miko')!.finishedStoryCount, 1);
  });

  test('a second finished story reports no badge before five', () async {
    final container = await _familyContainer();
    final controller = container.read(profileControllerProvider);
    await controller.recordFinishedStory('miko', 'story-moon');

    final badge = await controller.recordFinishedStory('miko', 'story-sun');

    expect(badge, isNull);
    expect(
      container
          .read(appControllerProvider)
          .requireValue
          .profileById('miko')!
          .finishedStoryCount,
      2,
    );
  });

  test('deleting a story removes it from the reward history', () async {
    final container = await _familyContainer(
      stories: <StoryBook>[_story('story-moon'), _story('story-sun')],
    );
    await container
        .read(profileControllerProvider)
        .recordFinishedStory('miko', 'story-moon');
    await container
        .read(profileControllerProvider)
        .recordFinishedStory('miko', 'story-sun');

    await container.read(storyControllerProvider).deleteStory('story-moon');

    final reopened = await (await LocalRepository.open()).readState();
    expect(reopened.profileById('miko')!.finishedStoryIds, <String>[
      'story-sun',
    ]);
    expect(reopened.stories.single.id, 'story-sun');
  });

  testWidgets('reaching the last page celebrates the first badge once', (
    tester,
  ) async {
    await seedDevice(
      profiles: <ChildProfile>[child()],
      // Two pages, so one page turn is enough to finish the book.
      stories: <StoryBook>[book(profileId: 'miko', id: 'story-moon')],
      activeProfileId: 'miko',
    );

    await pumpApp(tester, route: '/story/story-moon');

    expect(find.text('New badge earned: First story'), findsNothing);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('New badge earned: First story'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    appRouter.go('/kingdom');
    await tester.pumpAndSettle();

    expect(find.text('Stories finished: 1'), findsOneWidget);
    expect(find.text('4 more to go until Five stories.'), findsOneWidget);

    appRouter.go('/story/story-moon');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('New badge earned: First story'), findsNothing);

    appRouter.go('/kingdom');
    await tester.pumpAndSettle();

    expect(find.text('Stories finished: 1'), findsOneWidget);
  });
}

/// Opens a container over real persisted state with one saved child profile.
Future<ProviderContainer> _familyContainer({
  List<StoryBook> stories = const <StoryBook>[],
}) async {
  await seedDevice(
    profiles: <ChildProfile>[child()],
    stories: stories,
    activeProfileId: 'miko',
  );
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  return container;
}

/// Builds one approved book belonging to the container's only child.
StoryBook _story(String storyId) {
  return book(
    id: storyId,
    profileId: 'miko',
    title: 'Moon Garden',
    theme: 'moon garden',
    createdAt: DateTime.utc(2026, 8, 18),
    style: IllustrationStyle.watercolor,
    pages: <StoryPage>[
      storyPage(1, 'A kind beginning.', scene: 'A moonlit garden.'),
    ],
  );
}
