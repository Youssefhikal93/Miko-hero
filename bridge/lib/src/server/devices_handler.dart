import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:shelf/shelf.dart';

/// Serves `GET /devices` for authenticated devices.
///
/// Responses contain device names and created dates only — never tokens or
/// token hashes.
class DevicesHandler {
  /// Creates the handler over [deviceStore].
  const DevicesHandler({required this._deviceStore});

  final DeviceStore _deviceStore;

  /// Handles `GET /devices`.
  Future<Response> listDevices(Request request) async {
    final devices = _deviceStore
        .listDevices()
        .where((device) => device.isActive)
        .map(
          (device) => <String, Object?>{
            'id': device.id,
            'name': device.name,
            'createdAtUtc': device.createdAtUtc.toIso8601String(),
          },
        )
        .toList(growable: false);
    return jsonResponse(200, <String, Object?>{'devices': devices});
  }
}
