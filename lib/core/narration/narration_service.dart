import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/narration/narration_options.dart';

/// Device speech boundary used by the reader without depending on a TTS plugin.
abstract interface class NarrationService {
  /// Reports whether the current device exposes a voice for the language.
  Future<bool> supports(AppLanguage language);

  /// Speaks the requested local prose and completes after platform playback.
  Future<void> speak(NarrationRequest request);

  /// Stops active speech immediately when the reader changes state.
  Future<void> stop();
}
