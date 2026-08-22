import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/common/atomic_files.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';

/// Environment variable that can point at a bridge configuration file.
const String bridgeConfigEnvironmentVariable = 'IAM_HERO_BRIDGE_CONFIG';

/// Default file name of the bridge configuration in the working directory.
const String defaultBridgeConfigFileName = 'bridge_config.json';

/// Loads, validates, and (on first run) creates bridge configuration files.
class BridgeConfigLoader {
  /// Creates the stateless loader.
  const BridgeConfigLoader();

  /// Resolves the configuration file location.
  ///
  /// Resolution order:
  /// 1. `--config <path>` (or `--config=<path>`) from [args],
  /// 2. [bridgeConfigEnvironmentVariable] in [environment],
  /// 3. `bridge_config.json` in [workingDirectory] (the current directory).
  ///
  /// Throws a [FormatException] when `--config` is malformed or given twice.
  File resolvePath({
    List<String> args = const <String>[],
    Map<String, String> environment = const <String, String>{},
    Directory? workingDirectory,
  }) {
    final directory = workingDirectory ?? Directory.current;
    final explicit = _readExplicitArg(args);
    final fromEnvironment = environment[bridgeConfigEnvironmentVariable];
    final chosen = explicit?.trim().isNotEmpty == true
        ? explicit!.trim()
        : (fromEnvironment != null && fromEnvironment.trim().isNotEmpty
              ? fromEnvironment.trim()
              : '${directory.path}${Platform.pathSeparator}$defaultBridgeConfigFileName');
    return File(chosen);
  }

  /// Loads the configuration for this run.
  ///
  /// When no configuration file exists at the resolved location one is
  /// created with documented defaults ([BridgeConfigLoadResult.createdDefaults]
  /// reports this so callers can print the new location). Malformed files
  /// throw a [FormatException]; they are never silently overwritten.
  Future<BridgeConfigLoadResult> load({
    List<String> args = const <String>[],
    Map<String, String> environment = const <String, String>{},
    Directory? workingDirectory,
  }) async {
    final directory = workingDirectory ?? Directory.current;
    final file = resolvePath(
      args: args,
      environment: environment,
      workingDirectory: directory,
    );
    if (await file.exists()) {
      final raw = await file.readAsString();
      final Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } on FormatException {
        throw FormatException(
          'Bridge configuration at "${file.path}" is not valid JSON.',
        );
      }
      if (decoded is! Map<String, Object?>) {
        throw FormatException(
          'Bridge configuration at "${file.path}" must be a JSON object.',
        );
      }
      return BridgeConfigLoadResult(
        config: BridgeConfig.fromJson(decoded),
        configFile: file,
        createdDefaults: false,
      );
    }
    final defaults = BridgeConfig.defaults(workingDirectory: directory.path);
    await writeStringAtomic(file.path, jsonEncode(defaults.toJson()));
    return BridgeConfigLoadResult(
      config: defaults,
      configFile: file,
      createdDefaults: true,
    );
  }

  String? _readExplicitArg(List<String> args) {
    String? value;
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--config') {
        if (value != null) {
          throw const FormatException('--config was provided more than once.');
        }
        if (i + 1 >= args.length) {
          throw const FormatException('--config requires a file path.');
        }
        value = args[i + 1];
      } else if (arg.startsWith('--config=')) {
        if (value != null) {
          throw const FormatException('--config was provided more than once.');
        }
        value = arg.substring('--config='.length);
      }
    }
    return value;
  }
}
