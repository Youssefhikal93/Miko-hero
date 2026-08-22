import 'package:miko_hero/core/ai_connection/bridge_client.dart';

/// Which generator the app uses for the parent's next story request.
enum StoryGeneratorMode {
  /// The clearly labelled offline sample generator that needs no PC.
  demo,

  /// The local AI running on the paired family PC.
  localAi,
}

/// Parent-chosen generator mode and PC bridge address, persisted per device.
///
/// Deliberately holds no secret: the pairing token lives in its own stored
/// record so a value shown on screen can never carry it by accident.
class AiConnectionSettings {
  /// Creates a validated connection selection.
  const AiConnectionSettings({required this.mode, required this.baseUrl});

  /// Generator the story creation flow will call.
  final StoryGeneratorMode mode;

  /// Origin of the PC bridge on the home network.
  final Uri baseUrl;

  /// Whether story requests are sent to the paired PC instead of the sample.
  bool get usesLocalAi => mode == StoryGeneratorMode.localAi;

  /// Converts the selection into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{'mode': mode.name, 'baseUrl': baseUrl.toString()};
  }

  /// Validates and restores the selection from local storage.
  factory AiConnectionSettings.fromJson(Map<String, Object?> json) {
    final mode = json['mode'];
    final baseUrl = json['baseUrl'];
    if (mode is! String || baseUrl is! String) {
      throw const FormatException('Malformed AI connection settings.');
    }
    final address = parseBridgeBaseUrl(baseUrl);
    if (address == null) {
      throw const FormatException('Malformed bridge address.');
    }
    try {
      return AiConnectionSettings(
        mode: StoryGeneratorMode.values.byName(mode),
        baseUrl: address,
      );
    } on ArgumentError {
      throw const FormatException('Unsupported story generator mode.');
    }
  }

  /// Returns the same settings after the parent switches generator.
  AiConnectionSettings withMode(StoryGeneratorMode savedMode) {
    return AiConnectionSettings(mode: savedMode, baseUrl: baseUrl);
  }

  /// Returns the same settings pointing at another validated bridge address.
  AiConnectionSettings withBaseUrl(Uri savedBaseUrl) {
    return AiConnectionSettings(mode: mode, baseUrl: savedBaseUrl);
  }
}

/// Settings a device starts with: the offline demo and the loopback bridge.
AiConnectionSettings defaultAiConnectionSettings() {
  return AiConnectionSettings(
    mode: StoryGeneratorMode.demo,
    baseUrl: Uri.parse(defaultBridgeBaseUrl),
  );
}
