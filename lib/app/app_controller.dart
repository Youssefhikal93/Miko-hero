import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/generation/local_ai_story_generator.dart';
import 'package:miko_hero/core/generation/story_generator.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/narration/device_narration_service.dart';
import 'package:miko_hero/core/narration/narration_service.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/generation_progress_controller.dart';

/// Supplies protected storage for the bridge's bearer credential.
///
/// Phones and desktops get the platform's protected store; the web build keeps
/// the value in preferences, because a browser has nothing more protected to
/// offer and the web plugin failed silently in release builds.
final bridgeCredentialStorageProvider = Provider<BridgeCredentialStorage>((
  ref,
) {
  if (kIsWeb) return const PreferencesBridgeCredentialStorage();
  return const SecureBridgeCredentialStorage();
});

/// Opens the platform stores once per provider container.
final localRepositoryProvider = FutureProvider<LocalRepository>((ref) {
  return LocalRepository.open(
    bridgeCredentialStorage: ref.watch(bridgeCredentialStorageProvider),
  );
});

/// Supplies how often a job running on the PC is polled.
///
/// Injectable so a test can drive the complete polling flow without waiting
/// out the real interval.
final localAiPollIntervalProvider = Provider<Duration>((ref) {
  return defaultLocalAiPollInterval;
});

/// Supplies the generator the parent selected in the AI connection settings.
///
/// The offline demo stays a deliberate, manually selected choice: it is used
/// while the settings are still loading and whenever Demo is the saved mode,
/// never as a silent fallback for a local AI call that failed.
final storyGeneratorProvider = Provider<StoryGenerator>((ref) {
  final connection = ref.watch(aiConnectionControllerProvider).value;
  if (connection == null || !connection.usesLocalAi) {
    return DemoStoryGenerator(
      latency: const Duration(milliseconds: 650),
      currentTime: DateTime.now,
    );
  }
  return LocalAiStoryGenerator(
    client: BridgeClient(
      httpClient: ref.watch(bridgeHttpClientProvider),
      baseUrl: connection.settings.baseUrl,
      deviceToken: connection.credential?.deviceToken,
    ),
    resolveAgeYears: (request) => _heroAgeYears(ref, request),
    currentTime: DateTime.now,
    pollInterval: ref.watch(localAiPollIntervalProvider),
    onProgress: (progress) {
      ref.read(generationProgressProvider.notifier).report(progress);
    },
  );
});

/// Resolves the hero's age today, which the bridge requires with each request.
///
/// A request whose profile was deleted between queueing and generation keeps
/// the default reading age; the story controller refuses it moments later.
int _heroAgeYears(Ref ref, StoryRequest request) {
  final profile = ref
      .read(appControllerProvider)
      .value
      ?.profileById(request.profileId);
  return profile?.age ?? defaultChildProfileAgeYears;
}

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
