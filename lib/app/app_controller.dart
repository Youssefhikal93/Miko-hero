import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_state.dart';
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

/// Exposes the single persisted snapshot observed by all feature controllers.
final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

/// Loads application state and commits snapshots already persisted by features.
class AppController extends AsyncNotifier<AppState> {
  @override
  /// Loads local state before any feature screen is rendered.
  Future<AppState> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    return repository.readState();
  }

  /// Publishes a snapshot only after its feature controller completes storage.
  void commit(AppState persistedState) {
    state = AsyncData(persistedState);
  }
}
