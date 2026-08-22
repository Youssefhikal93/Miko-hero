import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/pairing/pairing_service.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:shelf/shelf.dart';

/// Serves the unauthenticated pairing endpoints.
///
/// `POST /pair/request` issues a 6-digit code which is printed on the PC
/// console (the single deliberate logging exception) and returns only the
/// `pairingId`. `POST /pair/confirm` exchanges `{pairingId, code,
/// deviceName}` for a one-time 256-bit bearer token; only its SHA-256 hash
/// is persisted.
class PairingHandlers {
  /// Creates handlers wired to [service] and [deviceStore]. [notifyCode]
  /// receives the console line containing the pairing code; defaults to no
  /// output (tests), the entry point wires it to `print`.
  PairingHandlers({
    required this._service,
    required this._deviceStore,
    void Function(String message)? notifyCode,
  }) : _notifyCode =
           notifyCode ??
           ((String _) {
             /* tests stay silent by default */
           });

  final PairingService _service;
  final DeviceStore _deviceStore;
  final void Function(String message) _notifyCode;

  /// Handles `POST /pair/request`.
  Future<Response> requestPairing(Request request) async {
    final PairingRequest pairing;
    try {
      pairing = _service.issueRequest();
    } on RateLimitExceededException catch (error) {
      throw ApiError(
        429,
        ApiErrorCode.rateLimited,
        'Too many pairing requests. Retry in '
        '${error.retryAfterSeconds} seconds.',
      );
    }
    final remainingSeconds = pairing.expiresAtUtc
        .difference(DateTime.now().toUtc())
        .inSeconds;
    final minutes = ((remainingSeconds + 59) ~/ 60).clamp(1, 60);
    _notifyCode(
      'Pairing code: ${pairing.code} — expires in '
      '$minutes minute${minutes == 1 ? '' : 's'}',
    );
    return jsonResponse(201, <String, Object?>{'pairingId': pairing.pairingId});
  }

  /// Handles `POST /pair/confirm`.
  Future<Response> confirmPairing(Request request) async {
    final body = await parseJsonObjectBody(request);
    final pairingId = requiredStringField(body, 'pairingId', maxLength: 64);
    final code = requiredStringField(body, 'code', maxLength: 6);
    final deviceName = requiredStringField(body, 'deviceName', maxLength: 100);

    final PairingConfirmOutcome outcome = _service.confirm(
      pairingId: pairingId,
      code: code,
    );
    switch (outcome) {
      case final PairingDenied denial:
        throw _denialError(denial.reason);
      case PairingApproved():
        break;
    }

    final deviceToken = generateDeviceToken();
    _deviceStore.registerDevice(
      name: deviceName,
      tokenHash: sha256Hex(deviceToken),
    );
    return jsonResponse(200, <String, Object?>{'deviceToken': deviceToken});
  }

  ApiError _denialError(PairingDenialReason reason) {
    return switch (reason) {
      PairingDenialReason.unknownPairingId => ApiError(
        404,
        ApiErrorCode.pairingNotFound,
        'No pending pairing exists under this id.',
      ),
      PairingDenialReason.expired => ApiError(
        410,
        ApiErrorCode.pairingExpired,
        'This pairing code has expired. Request a new one.',
      ),
      PairingDenialReason.wrongCode => ApiError(
        403,
        ApiErrorCode.invalidPairingCode,
        'The submitted pairing code is wrong.',
      ),
    };
  }
}
