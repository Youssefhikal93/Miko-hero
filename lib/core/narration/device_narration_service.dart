import 'package:flutter_tts/flutter_tts.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/narration/narration_options.dart';
import 'package:miko_hero/core/narration/narration_service.dart';

/// Uses the free speech engine already installed on the current device.
class DeviceNarrationService implements NarrationService {
  /// Creates a service around the platform plugin used by the application.
  DeviceNarrationService(this._speechEngine);

  final FlutterTts _speechEngine;

  @override
  /// Converts the plugin's platform response into a strict boolean contract.
  Future<bool> supports(AppLanguage language) async {
    final availability = await _speechEngine.isLanguageAvailable(
      language.speechLocale,
    );
    return availability == true || availability == 1;
  }

  @override
  /// Configures the locale before speaking so pages never use a stale voice.
  Future<void> speak(NarrationRequest request) async {
    await _speechEngine.stop();
    await _speechEngine.setLanguage(request.language.speechLocale);
    await _speechEngine.setSpeechRate(request.speed.platformRate);
    await _speechEngine.awaitSpeakCompletion(true);
    await _speechEngine.speak(request.text);
  }

  @override
  /// Delegates cancellation to the active platform speech engine.
  Future<void> stop() async {
    await _speechEngine.stop();
  }
}
