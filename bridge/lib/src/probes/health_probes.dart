import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/probes/probe_client.dart';

/// Maximum time a single probe may take before reporting unavailable.
const Duration probeTimeout = Duration(seconds: 3);

/// Result of one service probe.
class ProbeStatus {
  /// Creates a probe status.
  const ProbeStatus({required this.available, required this.detail});

  /// Whether the probed capability is usable right now.
  final bool available;

  /// Human-readable explanation; never contains user content or secrets.
  final String detail;

  /// JSON shape used by the health endpoint.
  Map<String, Object> toJson() {
    return <String, Object>{'available': available, 'detail': detail};
  }
}

/// Contract for one health probe.
abstract class HealthProbe {
  /// Stable key of this probe inside the health report.
  String get key;

  /// Runs the probe, returning its status. Implementations must catch all
  /// failures and convert them into an unavailable [ProbeStatus]; a probe
  /// must never throw into the HTTP layer.
  Future<ProbeStatus> check();
}

/// Probes the configured Ollama instance: version endpoint reachable and
/// the configured model present in `/api/tags`.
class OllamaProbe implements HealthProbe {
  /// Creates a probe against [baseUrl] requiring [model].
  OllamaProbe({
    required this._client,
    required String baseUrl,
    required this.model,
    this.timeout = probeTimeout,
  }) : _baseUrl = _normalize(baseUrl);

  final ProbeHttpClient _client;
  final Uri _baseUrl;

  /// Model tag that must be available locally (e.g. `gemma3:4b`).
  final String model;

  /// Per-request timeout.
  final Duration timeout;

  @override
  String get key => 'ollama';

  @override
  Future<ProbeStatus> check() async {
    try {
      await _client.get(
        _baseUrl.replace(path: '${_baseUrl.path}/api/version'),
        timeout: timeout,
      );
      final tagsResponse = await _client.get(
        _baseUrl.replace(path: '${_baseUrl.path}/api/tags'),
        timeout: timeout,
      );
      if (tagsResponse.statusCode != HttpStatus.ok) {
        return ProbeStatus(
          available: false,
          detail: 'Ollama /api/tags answered HTTP ${tagsResponse.statusCode}.',
        );
      }
      if (_modelIsPresent(tagsResponse.bodyText)) {
        return ProbeStatus(
          available: true,
          detail: 'Ollama ready with $model.',
        );
      }
      return ProbeStatus(
        available: false,
        detail: 'Ollama reachable but model "$model" is not pulled.',
      );
    } on Exception catch (_) {
      return ProbeStatus(available: false, detail: 'Ollama unreachable.');
    }
  }

  bool _modelIsPresent(String bodyText) {
    final Object? decoded;
    try {
      decoded = jsonDecode(bodyText);
    } on FormatException {
      return false;
    }
    if (decoded is! Map<String, Object?>) {
      return false;
    }
    final models = decoded['models'];
    if (models is! List) {
      return false;
    }
    for (final entry in models) {
      if (entry is! Map<String, Object?>) {
        continue;
      }
      final name = entry['name'];
      if (name is! String) {
        continue;
      }
      if (name == model || name.startsWith('$model:')) {
        return true;
      }
    }
    return false;
  }
}

/// Probes the configured ComfyUI instance via `/system_stats`.
///
/// It is expected and fine for this to stay unavailable until ComfyUI is
/// installed; the bridge keeps working without it.
class ComfyUiProbe implements HealthProbe {
  /// Creates a probe against [baseUrl].
  ComfyUiProbe({
    required this._client,
    required String baseUrl,
    this.timeout = probeTimeout,
  }) : _baseUrl = _normalize(baseUrl);

  final ProbeHttpClient _client;
  final Uri _baseUrl;

  /// Per-request timeout.
  final Duration timeout;

  @override
  String get key => 'comfyui';

  @override
  Future<ProbeStatus> check() async {
    try {
      final response = await _client.get(
        _baseUrl.replace(path: '${_baseUrl.path}/system_stats'),
        timeout: timeout,
      );
      if (response.statusCode == HttpStatus.ok) {
        return const ProbeStatus(available: true, detail: 'ComfyUI reachable.');
      }
      return ProbeStatus(
        available: false,
        detail: 'ComfyUI /system_stats answered HTTP ${response.statusCode}.',
      );
    } on Exception catch (_) {
      return ProbeStatus(available: false, detail: 'ComfyUI unreachable.');
    }
  }
}

/// Verifies the master library: database openable and folders writable.
class LibraryProbe implements HealthProbe {
  /// Creates a library probe.
  LibraryProbe({required this._library});
  final MasterLibrary _library;

  @override
  String get key => 'library';

  @override
  Future<ProbeStatus> check() async {
    if (!_library.isInitialized) {
      return const ProbeStatus(
        available: false,
        detail: 'Library not initialized.',
      );
    }
    try {
      final db = _library.database;
      final rows = db.select('SELECT 1');
      if (rows.isEmpty) {
        return const ProbeStatus(
          available: false,
          detail: 'Library database did not answer.',
        );
      }
      final unwritable = <String>[];
      for (final folder in LibraryFolder.values) {
        if (!await _canWrite(folder)) {
          unwritable.add(folder.folderName);
        }
      }
      if (unwritable.isNotEmpty) {
        return ProbeStatus(
          available: false,
          detail: 'Folders not writable: ${unwritable.join(', ')}.',
        );
      }
      return const ProbeStatus(
        available: true,
        detail: 'Database open and folders writable.',
      );
    } on Exception catch (_) {
      return const ProbeStatus(
        available: false,
        detail: 'Library database error.',
      );
    }
  }

  Future<bool> _canWrite(LibraryFolder folder) async {
    File? probeFile;
    try {
      final directory = Directory(_library.folderPath(folder));
      final unique =
          'probe-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}.tmp';
      probeFile = File('${directory.path}${Platform.pathSeparator}$unique');
      final sink = probeFile.openWrite();
      await sink.close();
      await probeFile.delete();
      return true;
    } on FileSystemException {
      return false;
    } finally {
      try {
        if (probeFile != null && await probeFile.exists()) {
          await probeFile.delete();
        }
      } on FileSystemException {
        // Nothing more we can do; the write result above already decided.
      }
    }
  }
}

Uri _normalize(String baseUrl) {
  final parsed = Uri.tryParse(baseUrl);
  if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
    throw FormatException('Invalid base URL for probe: $baseUrl');
  }
  var path = parsed.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return parsed.replace(path: path);
}
