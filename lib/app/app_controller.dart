import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
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

  /// Adds a new child or replaces an existing profile after form validation.
  Future<void> saveProfile({
    required String? profileId,
    required String name,
    required int age,
    required String photoBase64,
  }) async {
    final current = state.requireValue;
    final profile = ChildProfile(
      id: profileId ?? _newProfileId(current.profiles),
      name: name,
      age: age,
      photoBase64: photoBase64,
    );
    final profiles = _upsertProfile(current.profiles, profile);
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveProfiles(profiles);
    state = AsyncData(
      AppState(
        locale: current.locale,
        profiles: profiles,
        stories: current.stories,
      ),
    );
  }

  /// Generates, persists, and returns a new book for immediate navigation.
  Future<StoryBook> createStory(StoryRequest request) async {
    final current = state.requireValue;
    if (current.profileById(request.profileId) == null) {
      throw StateError('Cannot create a story for an unknown child profile.');
    }
    final generator = ref.read(storyGeneratorProvider);
    final story = await generator.generate(request);
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
        profiles: current.profiles,
        stories: current.stories,
      ),
    );
  }

  /// Deletes all profiles, photos, and stories while keeping language preference.
  Future<void> clearAll() async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.clearAll();
    final current = state.requireValue;
    state = AsyncData(
      AppState(
        locale: current.locale,
        profiles: const <ChildProfile>[],
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
        profiles: current.profiles,
        stories: stories,
      ),
    );
  }

  /// Replaces a matching identity or appends a newly created profile.
  List<ChildProfile> _upsertProfile(
    List<ChildProfile> profiles,
    ChildProfile savedProfile,
  ) {
    final updatedProfiles = profiles
        .map(
          (profile) => profile.id == savedProfile.id ? savedProfile : profile,
        )
        .toList();
    if (!profiles.any((profile) => profile.id == savedProfile.id)) {
      updatedProfiles.add(savedProfile);
    }
    return List<ChildProfile>.unmodifiable(updatedProfiles);
  }

  /// Creates a device-local identity after a deliberate parent save action.
  String _newProfileId(List<ChildProfile> profiles) {
    final timePart = DateTime.now().toUtc().microsecondsSinceEpoch;
    final baseId = 'profile-$timePart';
    var candidateId = baseId;
    var suffix = 1;
    while (profiles.any((profile) => profile.id == candidateId)) {
      candidateId = '$baseId-${suffix++}';
    }
    return candidateId;
  }
}
