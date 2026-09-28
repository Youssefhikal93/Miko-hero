import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the device list and device removal for authenticated devices.
///
/// Responses contain device names, moments, and which row belongs to the
/// caller — never tokens or token hashes.
class DevicesHandler {
  /// Creates the handler over [deviceStore].
  const DevicesHandler({required this._deviceStore});

  final DeviceStore _deviceStore;

  /// Handles `GET /devices`.
  ///
  /// Marks the caller's own row with `isCaller`, so the app can show "this
  /// device" and hide its own remove control without the phone having to
  /// store its device id.
  Future<Response> listDevices(Request request) async {
    final caller = requireAuthenticatedDevice(request);
    final devices = _deviceStore
        .listDevices()
        .where((device) => device.isActive)
        .map(
          (device) => <String, Object?>{
            'id': device.id,
            'name': device.name,
            'createdAtUtc': device.createdAtUtc.toIso8601String(),
            'lastSeenAtUtc': device.lastSeenAtUtc?.toIso8601String(),
            'isCaller': device.id == caller.id,
          },
        )
        .toList(growable: false);
    return jsonResponse(200, <String, Object?>{'devices': devices});
  }

  /// Handles `DELETE /devices/<deviceId>`.
  ///
  /// The removed device's very next call fails authentication, which is the
  /// point: a phone that left the family stops reaching the PC without anyone
  /// having to touch it. A device may not remove itself — unpairing this
  /// device is a local decision made on the device, and a self-removal would
  /// leave the parent looking at a list they can no longer refresh.
  Future<Response> removeDevice(Request request, String deviceId) async {
    final caller = requireAuthenticatedDevice(request);
    if (deviceId == caller.id) {
      throw ApiError(
        409,
        ApiErrorCode.cannotRemoveSelf,
        'A device cannot remove its own pairing from the PC.',
      );
    }
    if (!_deviceStore.revokeById(deviceId)) {
      throw ApiError(
        404,
        ApiErrorCode.deviceNotFound,
        'No paired device exists under this id.',
      );
    }
    return jsonResponse(200, <String, Object?>{
      'id': deviceId,
      'removed': true,
    });
  }
}
