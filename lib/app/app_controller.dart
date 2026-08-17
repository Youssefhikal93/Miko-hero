import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/daughter_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/device_narration_service.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/core/storage/local_repository.dart';

/// Opens the platform preference store once per provider container.
final localRepositoryProvider = FutureProvider<LocalRepository>((ref) {
  return LocalRepository.open();
});

/// Supplies the explicitly labelled local demo generator until AI is connected.
final storyGeneratorProvider = Provider<StoryGenerator>((ref) {
  return DemoStoryGenerator(
    latency: const Duration(milliseconds: 650),
    currentTime: DateTime.now,
  );
});

/// Supplies free narration through the current device's installed voices.
final narrationServiceProvider = Provider<NarrationService>((ref) {
  return DeviceNarrationService(FlutterTts());
});

/// Exposes the persisted application state and all user-triggered commands.
final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

/// Coordinates persistence and generation without embedding logic in widgets.
class AppController extends AsyncNotifier<AppState> {
  @override
  /// Loads local state before any feature screen is rendered.
  Future<AppState> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    return repository.readState();
  }

  /// Persists a validated profile before exposing it to feature screens.
  Future<void> saveProfile(DaughterProfile profile) async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveProfile(profile);
    final current = state.requireValue;
    state = AsyncData(
      AppState(
        locale: current.locale,
        profile: profile,
        stories: current.stories,
      ),
    );
  }

  /// Generates, persists, and returns a new book for immediate navigation.
  Future<StoryBook> createStory(StoryRequest request) async {
    final generator = ref.read(storyGeneratorProvider);
    final story = await generator.generate(request);
    final current = state.requireValue;
    final stories = List<StoryBook>.unmodifiable(<StoryBook>[
      story,
      ...current.stories,
    ]);
    await _saveStories(stories);
    return story;
  }

  /// Permanently removes the selected story while preserving all other state.
  Future<void> deleteStory(String storyId) async {
    final current = state.requireValue;
    final stories = current.stories
        .where((story) => story.id != storyId)
        .toList(growable: false);
    await _saveStories(stories);
  }

  /// Persists an interface locale and immediately rebuilds localized widgets.
  Future<void> setLocale(Locale locale) async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveLocale(locale);
    final current = state.requireValue;
    state = AsyncData(
      AppState(
        locale: locale,
        profile: current.profile,
        stories: current.stories,
      ),
    );
  }

  /// Deletes the profile, photo, and stories while keeping language preference.
  Future<void> clearAll() async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.clearAll();
    final current = state.requireValue;
    state = AsyncData(
      AppState(
        locale: current.locale,
        profile: null,
        stories: const <StoryBook>[],
      ),
    );
  }

  /// Saves one library snapshot and updates state only after persistence succeeds.
  Future<void> _saveStories(List<StoryBook> stories) async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveStories(stories);
    final current = state.requireValue;
    state = AsyncData(
      AppState(
        locale: current.locale,
        profile: current.profile,
        stories: stories,
      ),
    );
  }
}
