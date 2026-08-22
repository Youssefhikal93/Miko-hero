import 'package:iam_hero_bridge/src/probes/health_probes.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/version.dart';
import 'package:shelf/shelf.dart';

/// Serves `GET /health` with version, uptime, and dependency statuses.
///
/// Probe failures never crash the server: every probe converts its own
/// failures into an unavailable status, and this handler additionally
/// guards against unexpected probe exceptions.
class HealthHandler {
  /// Creates the handler over [probes] (`ollama`, `comfyui`, `library`).
  HealthHandler({required List<HealthProbe> probes})
    : _probes = List.of(probes);

  final List<HealthProbe> _probes;
  final DateTime _startedAt = DateTime.now().toUtc();

  /// Runs all probes in parallel and serializes the health report.
  Future<Response> call(Request request) async {
    return jsonResponse(200, await gatherStatuses());
  }

  /// Runs every probe and builds the health report body.
  ///
  /// Public so tests can inspect the exact shape without HTTP.
  Future<Map<String, Object?>> gatherStatuses() async {
    final statuses = <String, Object?>{};
    await Future.wait(
      _probes.map((probe) async {
        ProbeStatus status;
        try {
          status = await probe.check();
        } on Exception catch (_) {
          status = const ProbeStatus(
            available: false,
            detail: 'Probe failed unexpectedly.',
          );
        } on Error catch (_) {
          status = const ProbeStatus(
            available: false,
            detail: 'Probe failed unexpectedly.',
          );
        }
        statuses[probe.key] = status.toJson();
      }),
    );
    return <String, Object?>{
      'version': bridgeVersion,
      'uptimeSeconds': uptimeSeconds,
      'statuses': statuses,
    };
  }

  /// Seconds since the bridge process started serving.
  double get uptimeSeconds =>
      DateTime.now().toUtc().difference(_startedAt).inMilliseconds /
      Duration.millisecondsPerSecond;
}
