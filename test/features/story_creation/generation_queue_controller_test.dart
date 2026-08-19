import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/story_creation/generation_queue_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies restart recovery through real preference-backed queue providers.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('interrupted running request reopens as a durable queued job', () async {
    final repository = await LocalRepository.open();
    const profile = ChildProfile(
      id: 'miko',
      name: 'Miko',
      legacyAge: 7,
      photoBase64: 'cGhvdG8=',
      gender: ChildGender.girl,
      themeColorValue: roseProfileThemeColorValue,
      hasCustomThemeColor: false,
    );
    await repository.saveProfiles(const <ChildProfile>[profile]);
    await repository.saveGenerationJobs(<GenerationJob>[
      GenerationJob(
        id: 'generation-1',
        createdAt: DateTime.utc(2026, 8, 18),
        request: _request(profile),
        status: GenerationJobStatus.running,
      ),
    ]);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final jobs = await container.read(generationQueueControllerProvider.future);
    final persistedRepository = await container.read(
      localRepositoryProvider.future,
    );
    final persistedJobs = await persistedRepository.readGenerationJobs();

    expect(jobs.single.status, GenerationJobStatus.queued);
    expect(persistedJobs.single.status, GenerationJobStatus.queued);
    expect(persistedJobs.single.request.profileId, profile.id);
  });
}

/// Builds a complete real request for the persisted queue boundary.
StoryRequest _request(ChildProfile profile) {
  return StoryRequest(
    hero: StoryHero(
      profileId: profile.id,
      name: profile.name,
      gender: profile.gender,
    ),
    prompt: const StoryPrompt(
      theme: 'moon garden',
      moral: 'kindness',
      preferences: ChildStoryPreferences(),
    ),
    presentation: const StoryPresentation(
      language: AppLanguage.english,
      length: StoryLength.short,
      style: IllustrationStyle.pictureBook,
    ),
  );
}
