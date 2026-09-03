import 'dart:io';

import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:iam_hero_bridge/src/common/local_network.dart';
import 'package:iam_hero_bridge/src/config/illustration_settings.dart';

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
    required this.illustrationTimeoutSeconds,
    this.allowedWebOrigins = const <String>[],
    this.illustration = IllustrationSettings.defaults,
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

  /// Default wall-clock budget for one story generation call: 15 minutes.
  ///
  /// The budget is per model call, and a job makes two: a small outline call
  /// and the call that writes the pages. Raised from ten minutes when the
  /// two-pass pipeline landed, because the recommended larger models — the
  /// ones that actually write correct Arabic — take noticeably longer per call
  /// on a 4 GB card than the 4B floor model does. Generous on purpose, but
  /// always bounded.
  static const int defaultGenerationTimeoutSeconds = 900;

  /// Default number of generation attempts per job (one try plus two
  /// retries) before the job fails.
  static const int defaultMaxGenerationAttempts = 3;

  /// Smallest accepted generation timeout, in seconds.
  static const int minimumGenerationTimeoutSeconds = 30;

  /// Largest accepted generation timeout, in seconds (one hour).
  static const int maximumGenerationTimeoutSeconds = 3600;

  /// Largest accepted number of attempts per generation job.
  static const int maximumGenerationAttempts = 5;

  /// Default wall-clock budget for rendering one illustration: 5 minutes.
  ///
  /// One 512x512 SD 1.5 image on a 4 GB card is a matter of seconds once the
  /// checkpoint is resident, but the first render of a session also pays for
  /// loading it, so the budget is generous — and always bounded.
  static const int defaultIllustrationTimeoutSeconds = 300;

  /// Smallest accepted illustration timeout, in seconds.
  static const int minimumIllustrationTimeoutSeconds = 60;

  /// Largest accepted illustration timeout, in seconds (30 minutes).
  static const int maximumIllustrationTimeoutSeconds = 1800;

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

  /// Wall-clock budget for rendering one illustration, in seconds.
  ///
  /// Covers the whole ComfyUI round trip for a single page: submitting the
  /// workflow, waiting for the render, and downloading the image.
  final int illustrationTimeoutSeconds;

  /// Additional web origins (scheme + host + optional port, no path) whose
  /// browser pages may call the bridge, e.g. `http://192.168.1.20:8765`.
  ///
  /// Loopback origins (`localhost`, `127.0.0.0/8`, `[::1]` on any port) are
  /// always allowed so a web app opened on the PC itself just works; every
  /// other origin must be listed here explicitly. Public web origins must use
  /// HTTPS so bearer tokens never cross the public internet in plaintext.
  final List<String> allowedWebOrigins;

  /// How illustrations are rendered: checkpoint, size, sampler, LoRA chain,
  /// and the optional upscale and face-detail passes.
  ///
  /// Absent from the file means "exactly what the bridge shipped with", so a
  /// configuration written before this section existed renders the same
  /// pictures it always did.
  final IllustrationSettings illustration;

  /// [generationTimeoutSeconds] as a [Duration].
  Duration get generationTimeout => Duration(seconds: generationTimeoutSeconds);

  /// [illustrationTimeoutSeconds] as a [Duration].
  Duration get illustrationTimeout =>
      Duration(seconds: illustrationTimeoutSeconds);

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
      'illustrationTimeoutSeconds': illustrationTimeoutSeconds,
      'allowedWebOrigins': allowedWebOrigins,
      'illustration': illustration.toJson(),
    };
  }

  /// Every key a configuration file may carry.
  ///
  /// Written down rather than implied, because anything else in the file is
  /// refused: see [BridgeConfig.fromJson].
  static const Set<String> knownKeys = <String>{
    'bindAddress',
    'port',
    'libraryPath',
    'ollamaBaseUrl',
    'comfyUiBaseUrl',
    'ollamaModel',
    'generationTimeoutSeconds',
    'maxGenerationAttempts',
    'illustrationTimeoutSeconds',
    'allowedWebOrigins',
    'illustration',
  };

  /// Validates and parses a configuration from a decoded JSON map.
  ///
  /// Missing fields fall back to their documented defaults so partially
  /// filled files keep working; present-but-invalid values throw a
  /// [FormatException] with a precise message.
  ///
  /// A key that is not in [knownKeys] is refused by name, exactly as the
  /// `illustration` section has always refused one. A misspelled top-level
  /// setting used to be dropped in silence, which meant a parent who typed
  /// `ollamaModle` ran every story on the default model and had nothing to
  /// read that said so.
  factory BridgeConfig.fromJson(Map<String, Object?> json) {
    final reader = JsonReader.root(json, failures: bridgeConfigFailures);
    reader.rejectUnknownKeys(knownKeys);
    return BridgeConfig(
      bindAddress: _readBindAddress(reader) ?? defaultBindAddress,
      port: reader.optionalInt(
        'port',
        minimum: 1,
        maximum: 65535,
        fallback: defaultPort,
      ),
      libraryPath: reader.optionalString('libraryPath') ?? defaultLibraryPath(),
      ollamaBaseUrl:
          reader.optionalBaseUrl('ollamaBaseUrl')?.text ?? defaultOllamaBaseUrl,
      comfyUiBaseUrl:
          reader.optionalBaseUrl('comfyUiBaseUrl')?.text ??
          defaultComfyUiBaseUrl,
      ollamaModel: reader.optionalString('ollamaModel') ?? defaultOllamaModel,
      generationTimeoutSeconds: reader.optionalInt(
        'generationTimeoutSeconds',
        minimum: minimumGenerationTimeoutSeconds,
        maximum: maximumGenerationTimeoutSeconds,
        fallback: defaultGenerationTimeoutSeconds,
      ),
      maxGenerationAttempts: reader.optionalInt(
        'maxGenerationAttempts',
        minimum: 1,
        maximum: maximumGenerationAttempts,
        fallback: defaultMaxGenerationAttempts,
      ),
      illustrationTimeoutSeconds: reader.optionalInt(
        'illustrationTimeoutSeconds',
        minimum: minimumIllustrationTimeoutSeconds,
        maximum: maximumIllustrationTimeoutSeconds,
        fallback: defaultIllustrationTimeoutSeconds,
      ),
      allowedWebOrigins: _readOriginList(reader),
      illustration: _readIllustration(reader),
    );
  }

  /// Reads and validates the optional `illustration` section.
  static IllustrationSettings _readIllustration(JsonReader reader) {
    final section = reader.section(
      illustrationSectionPath,
      expected: 'a JSON object',
    );
    if (section == null) {
      return IllustrationSettings.defaults;
    }
    return IllustrationSettings.fromReader(section);
  }

  /// Reads and validates the optional list of extra allowed web origins.
  static List<String> _readOriginList(JsonReader reader) {
    const key = 'allowedWebOrigins';
    final entries = reader.optionalList(
      key,
      expected: 'a list of origin strings',
    );
    if (entries == null) {
      return const <String>[];
    }
    final origins = <String>[];
    for (final entry in entries) {
      if (entry is! String || entry.isEmpty || entry != entry.trim()) {
        reader.fail(key, 'must contain only exact origin strings.');
      }
      final origin = entry;
      final uri = Uri.tryParse(origin);
      if (uri == null ||
          origin.contains('*') ||
          (uri.scheme != 'http' && uri.scheme != 'https') ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.path.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          !_hasExactOriginAuthority(origin, uri)) {
        reader.fail(
          key,
          'entry "$origin" must be an exact http(s) origin (scheme, host, '
          'and optional port only; no wildcard, path, query, fragment, '
          'credentials, or trailing slash).',
        );
      }
      if (uri.scheme == 'http' && !isPrivateOrLoopbackHost(uri.host)) {
        reader.fail(
          key,
          'entry "$origin" must use https because its host is not loopback '
          'or private/LAN.',
        );
      }
      origins.add(origin);
    }
    return List<String>.unmodifiable(origins);
  }

  static String? _readBindAddress(JsonReader reader) {
    const key = 'bindAddress';
    final value = reader.optionalString(key);
    if (value == null) return null;
    if (!isPrivateOrLoopbackHost(value)) {
      reader.fail(
        key,
        'must be "localhost" or a loopback, private/LAN, link-local, or '
        'Tailscale IP address; wildcard, public, and other hostname '
        'addresses are refused.',
      );
    }
    return value;
  }

  static bool _hasExactOriginAuthority(String origin, Uri uri) {
    final separator = origin.indexOf('://');
    if (separator < 0) return false;
    final authority = origin.substring(separator + 3);
    if (authority.isEmpty || authority.endsWith(':')) return false;
    try {
      final port = uri.hasPort ? uri.port : null;
      return port == null || port >= 1 && port <= 65535;
    } on FormatException {
      return false;
    }
  }

  /// Builds a fully-default configuration rooted at [workingDirectory].
  ///
  /// [illustration] exists so a test can render with a non-default pipeline
  /// without writing a configuration file; every real run parses one.
  factory BridgeConfig.defaults({
    required String workingDirectory,
    IllustrationSettings illustration = IllustrationSettings.defaults,
  }) {
    return BridgeConfig(
      bindAddress: defaultBindAddress,
      port: defaultPort,
      libraryPath: defaultLibraryPath(workingDirectory),
      ollamaBaseUrl: defaultOllamaBaseUrl,
      comfyUiBaseUrl: defaultComfyUiBaseUrl,
      ollamaModel: defaultOllamaModel,
      generationTimeoutSeconds: defaultGenerationTimeoutSeconds,
      maxGenerationAttempts: defaultMaxGenerationAttempts,
      illustrationTimeoutSeconds: defaultIllustrationTimeoutSeconds,
      illustration: illustration,
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
