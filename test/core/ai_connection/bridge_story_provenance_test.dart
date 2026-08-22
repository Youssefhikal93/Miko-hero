import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/story_models.dart';

StoryBook _book({required String sceneDescription}) {
  return StoryBook(
    id: 'story-1',
    createdAt: DateTime.utc(2026, 8, 22),
    content: StoryContent(
      title: 'A Story',
      request: const StoryRequest(
        hero: StoryHero(
          profileId: 'child-1',
          name: 'Lina',
          gender: ChildGender.girl,
        ),
        prompt: StoryPrompt(
          theme: 'a garden',
          moral: 'kindness',
          preferences: ChildStoryPreferences(),
        ),
        presentation: StoryPresentation(
          language: AppLanguage.english,
          length: StoryLength.short,
          style: IllustrationStyle.pictureBook,
        ),
      ),
      pages: <StoryPage>[
        StoryPage(
          number: 1,
          text: 'Once upon a time.',
          sceneDescription: sceneDescription,
        ),
      ],
    ),
    reviewStatus: StoryReviewStatus.draft,
  );
}

void main() {
  test('a bridge-generated story is recognized by its first page', () {
    final scene = const BridgeStoryProvenance(
      scene: 'Lina in a sunny garden.',
      storyId: 'master-story-1',
      illustrationId: 'illustration-1',
    ).toSceneDescription();
    expect(
      BridgeStoryProvenance.marksStory(_book(sceneDescription: scene)),
      isTrue,
    );
  });

  test('a demo story carries no bridge provenance', () {
    expect(
      BridgeStoryProvenance.marksStory(
        _book(sceneDescription: 'A moonlit garden — soft watercolor light.'),
      ),
      isFalse,
    );
  });
}
