/// Longest device name this app sends to the bridge at pairing time.
const maximumPairedDeviceNameLength = 60;

/// Number of digits in the pairing code the PC prints on its own console.
const bridgePairingCodeLength = 6;

/// The bearer token this device received when the parent paired it.
///
/// Stored in platform-protected storage, written only by the repository, never
/// logged, and never rendered. The [toString] override keeps the token out of
/// diagnostics even by accident.
class BridgeCredential {
  /// Creates a stored pairing record after a successful confirmation.
  const BridgeCredential({
    required this.deviceToken,
    required this.deviceName,
    required this.pairedAtUtc,
  });

  /// Bearer token the bridge issued once and cannot show again.
  final String deviceToken;

  /// Name this device is listed under on the PC.
  final String deviceName;

  /// UTC moment the pairing was confirmed, shown as paired-state detail.
  final DateTime pairedAtUtc;

  /// Converts the record into a JSON-compatible local storage object.
  Map<String, Object> toJson() {
    return <String, Object>{
      'deviceToken': deviceToken,
      'deviceName': deviceName,
      'pairedAtUtc': pairedAtUtc.toIso8601String(),
    };
  }

  /// Validates and restores the stored pairing record.
  factory BridgeCredential.fromJson(Map<String, Object?> json) {
    final deviceToken = json['deviceToken'];
    final deviceName = json['deviceName'];
    final pairedAtUtc = json['pairedAtUtc'];
    if (deviceToken is! String ||
        deviceToken.isEmpty ||
        deviceName is! String ||
        deviceName.trim().isEmpty ||
        pairedAtUtc is! String) {
      throw const FormatException('Malformed paired device record.');
    }
    return BridgeCredential(
      deviceToken: deviceToken,
      deviceName: deviceName.trim(),
      pairedAtUtc: DateTime.parse(pairedAtUtc).toUtc(),
    );
  }

  /// Reports the paired device without ever revealing its token.
  @override
  String toString() => 'BridgeCredential($deviceName)';
}

/// Whether a parent-entered device name can be sent to the bridge as is.
bool isValidPairedDeviceName(String deviceName) {
  final trimmed = deviceName.trim();
  return trimmed.isNotEmpty && trimmed.length <= maximumPairedDeviceNameLength;
}

/// Whether a typed pairing code has the exact shape the PC console printed.
bool isValidBridgePairingCode(String code) {
  return RegExp('^\\d{$bridgePairingCodeLength}\$').hasMatch(code.trim());
}
