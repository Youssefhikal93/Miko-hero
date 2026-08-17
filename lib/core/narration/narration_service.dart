import 'package:miko_hero/core/models/app_language.dart';

/// Device speech boundary used by the reader without depending on a TTS plugin.
abstract interface class NarrationService {
  /// Reports whether the current device exposes a voice for the language.
  Future<bool> supports(AppLanguage language);

  /// Speaks one page and completes after the platform finishes playback.
  Future<void> speak(String text, AppLanguage language);

  /// Stops active speech immediately when the reader changes state.
  Future<void> stop();
}
