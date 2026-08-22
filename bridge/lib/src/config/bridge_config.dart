import 'dart:io';

/// Immutable runtime configuration of the bridge service.
///
/// All machine-specific values (paths, addresses, ports) live exclusively in
/// the JSON configuration file; nothing is hardcoded in source code.
class BridgeConfig {
  /// Creates a configuration from validated values.
  const BridgeConfig({
    required this.bindAddress,
    required this.port,
    required this.libraryPath,
    required this.ollamaBaseUrl,
    required this.comfyUiBaseUrl,
    required this.ollamaModel,
    required this.generationTimeoutSeconds,
    required this.maxGenerationAttempts,
    this.allowedWebOrigins = const <String>[],
  });

  /// Default loopback bind address: the bridge is private unless explicitly
  /// reconfigured to listen on a LAN address.
  static const String defaultBindAddress = '127.0.0.1';

  /// Default TCP port for the HTTP server.
  static const int defaultPort = 8765;

  /// Default base URL of the local Ollama service.
  static const String defaultOllamaBaseUrl = 'http://127.0.0.1:11434';

  /// Default base URL of the local ComfyUI service.
  static const String defaultComfyUiBaseUrl = 'http://127.0.0.1:8188';

  /// Default Ollama model used for story generation.
  static const String defaultOllamaModel = 'gemma3:4b';

  /// Default wall-clock budget for one story generation call: 10 minutes.
  ///
  /// A small local GPU needs minutes for a ten-page story, so this is
  /// generous on purpose — but always bounded.
  static const int defaultGenerationTimeoutSeconds = 600;

  /// Default number of generation attempts per job (one try plus two
  /// retries) before the job fails.
  static const int defaultMaxGenerationAttempts = 3;

  /// Smallest accepted generation timeout, in seconds.
  static const int minimumGenerationTimeoutSeconds = 30;

  /// Largest accepted generation timeout, in seconds (one hour).
  static const int maximumGenerationTimeoutSeconds = 3600;

  /// Largest accepted number of attempts per generation job.
  static const int maximumGenerationAttempts = 5;

  /// Network interface address the HTTP server binds to, e.g. `127.0.0.1`
  /// or a LAN address such as `192.168.1.20`.
  final String bindAddress;

  /// TCP port the HTTP server listens on.
  final int port;

  /// Absolute or working-directory-relative path of the master library root
  /// folder which holds `db/`, `photos/`, `illustrations/` and `exports/`.
  final String libraryPath;

  /// Base URL of the local Ollama API, e.g. `http://127.0.0.1:11434`.
  final String ollamaBaseUrl;

  /// Base URL of the local ComfyUI API, e.g. `http://127.0.0.1:8188`.
  final String comfyUiBaseUrl;

  /// Ollama model tag used for story generation, e.g. `gemma3:4b`.
  final String ollamaModel;

  /// Wall-clock budget for one story generation call, in seconds.
  final int generationTimeoutSeconds;

  /// Attempts allowed per generation job before it fails.
  ///
  /// Counts the first try, so the default of 3 means one try plus two
  /// retries. Only invalid model output is retried.
  final int maxGenerationAttempts;

  /// Additional web origins (scheme + host + optional port, no path) whose
  /// browser pages may call the bridge, e.g. `http://192.168.1.20:8765`.
  ///
  /// Loopback origins (`localhost`, `127.0.0.1`, `[::1]` on any port) are
  /// always allowed so a web app opened on the PC itself just works; every
  /// other origin must be listed here explicitly. Never list a public
  /// internet origin — the bridge is for the private home network only.
  final List<String> allowedWebOrigins;

  /// [generationTimeoutSeconds] as a [Duration].
  Duration get generationTimeout => Duration(seconds: generationTimeoutSeconds);

  /// Serializes the configuration into the JSON map persisted on disk.
  Map<String, Object> toJson() {
    return <String, Object>{
      'bindAddress': bindAddress,
      'port': port,
      'libraryPath': libraryPath,
      'ollamaBaseUrl': ollamaBaseUrl,
      'comfyUiBaseUrl': comfyUiBaseUrl,
      'ollamaModel': ollamaModel,
      'generationTimeoutSeconds': generationTimeoutSeconds,
      'maxGenerationAttempts': maxGenerationAttempts,
      'allowedWebOrigins': allowedWebOrigins,
    };
  }

  /// Validates and parses a configuration from a decoded JSON map.
  ///
  /// Missing fields fall back to their documented defaults so partially
  /// filled files keep working; present-but-invalid values throw a
  /// [FormatException] with a precise message.
  factory BridgeConfig.fromJson(Map<String, Object?> json) {
    return BridgeConfig(
      bindAddress:
          _readNonEmptyString(json, 'bindAddress') ?? defaultBindAddress,
      port: _readPort(json),
      libraryPath:
          _readNonEmptyString(json, 'libraryPath') ?? defaultLibraryPath(),
      ollamaBaseUrl:
          _readHttpUrl(json, 'ollamaBaseUrl') ?? defaultOllamaBaseUrl,
      comfyUiBaseUrl:
          _readHttpUrl(json, 'comfyUiBaseUrl') ?? defaultComfyUiBaseUrl,
      ollamaModel:
          _readNonEmptyString(json, 'ollamaModel') ?? defaultOllamaModel,
      generationTimeoutSeconds: _readBoundedInt(
        json,
        'generationTimeoutSeconds',
        minimum: minimumGenerationTimeoutSeconds,
        maximum: maximumGenerationTimeoutSeconds,
        fallback: defaultGenerationTimeoutSeconds,
      ),
      maxGenerationAttempts: _readBoundedInt(
        json,
        'maxGenerationAttempts',
        minimum: 1,
        maximum: maximumGenerationAttempts,
        fallback: defaultMaxGenerationAttempts,
      ),
      allowedWebOrigins: _readOriginList(json, 'allowedWebOrigins'),
    );
  }

  /// Reads and validates the optional list of extra allowed web origins.
  static List<String> _readOriginList(Map<String, Object?> json, String key) {
    final Object? value = json[key];
    if (value == null) {
      return const <String>[];
    }
    if (value is! List<Object?>) {
      throw FormatException('Field "$key" must be a list of origin strings.');
    }
    final origins = <String>[];
    for (final entry in value) {
      if (entry is! String || entry.trim().isEmpty) {
        throw FormatException('Field "$key" must contain only origin strings.');
      }
      final origin = entry.trim();
      final uri = Uri.tryParse(origin);
      if (uri == null ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty ||
          uri.path.isNotEmpty && uri.path != '/' ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw FormatException(
          'Field "$key" entry "$origin" must be a bare origin such as '
          '"http://192.168.1.20:8765" with no path.',
        );
      }
      origins.add(
        origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin,
      );
    }
    return List<String>.unmodifiable(origins);
  }

  /// Builds a fully-default configuration rooted at [workingDirectory].
  factory BridgeConfig.defaults({required String workingDirectory}) {
    return BridgeConfig(
      bindAddress: defaultBindAddress,
      port: defaultPort,
      libraryPath: defaultLibraryPath(workingDirectory),
      ollamaBaseUrl: defaultOllamaBaseUrl,
      comfyUiBaseUrl: defaultComfyUiBaseUrl,
      ollamaModel: defaultOllamaModel,
      generationTimeoutSeconds: defaultGenerationTimeoutSeconds,
      maxGenerationAttempts: defaultMaxGenerationAttempts,
    );
  }

  /// Default master library location: `iam_hero_library` under
  /// [workingDirectory] (or the current directory when omitted).
  static String defaultLibraryPath([String? workingDirectory]) {
    final Directory base = workingDirectory == null
        ? Directory.current
        : Directory(workingDirectory);
    final separator = Platform.pathSeparator;
    var path = base.path;
    if (!path.endsWith(separator)) {
      path = '$path$separator';
    }
    return '${path}iam_hero_library';
  }

  static String? _readNonEmptyString(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is! String || value.trim().isEmpty) {
      throw FormatException(
        'Bridge config field "$key" must be a non-empty string.',
      );
    }
    return value.trim();
  }

  static int _readPort(Map<String, Object?> json) {
    final value = json['port'];
    if (value == null) {
      return defaultPort;
    }
    if (value is! int || value < 1 || value > 65535) {
      throw FormatException(
        'Bridge config field "port" must be an integer between 1 and 65535.',
      );
    }
    return value;
  }

  static int _readBoundedInt(
    Map<String, Object?> json,
    String key, {
    required int minimum,
    required int maximum,
    required int fallback,
  }) {
    final value = json[key];
    if (value == null) {
      return fallback;
    }
    if (value is! int || value < minimum || value > maximum) {
      throw FormatException(
        'Bridge config field "$key" must be an integer between $minimum '
        'and $maximum.',
      );
    }
    return value;
  }

  static String? _readHttpUrl(Map<String, Object?> json, String key) {
    final value = _readNonEmptyString(json, key);
    if (value == null) {
      return null;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !value.contains('://')) {
      throw FormatException(
        'Bridge config field "$key" must be an http(s) URL.',
      );
    }
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}

/// Outcome of loading one bridge configuration file.
class BridgeConfigLoadResult {
  /// Creates a load result.
  const BridgeConfigLoadResult({
    required this.config,
    required this.configFile,
    required this.createdDefaults,
  });

  /// Parsed and validated configuration.
  final BridgeConfig config;

  /// Absolute path of the JSON file backing [config].
  final File configFile;

  /// Whether the file did not exist and was created with defaults.
  final bool createdDefaults;
}
