/// Reason one call to the local PC bridge could not be completed.
///
/// The bridge answers failures as `{"error": {"code", "message"}}`, but its
/// message is English technical text. Only the typed reason crosses this
/// boundary so every parent-facing sentence is localized inside the app.
enum BridgeFailure {
  /// The configured address did not answer at all.
  unreachable,

  /// The bridge accepted the connection but did not answer in time.
  timedOut,

  /// This device has no stored pairing token yet.
  notPaired,

  /// The stored token was refused, so the PC forgot this device.
  unauthorized,

  /// Too many pairing requests arrived within one minute.
  rateLimited,

  /// The pending pairing was never created or has already been consumed.
  pairingNotFound,

  /// The 6-digit code shown on the PC is older than two minutes.
  pairingExpired,

  /// The typed code did not match; five wrong codes cancel the pairing.
  invalidPairingCode,

  /// The bridge rejected a field of the story request before queueing it.
  invalidRequest,

  /// The bridge no longer knows the polled job.
  jobNotFound,

  /// The master library holds no story under the identity this device sent.
  storyNotFound,

  /// The master library holds no profile under the identity this device sent.
  profileNotFound,

  /// The chosen reference photo is larger than the bridge accepts.
  photoTooLarge,

  /// The chosen reference photo is not a JPEG or a PNG the bridge can read.
  unsupportedImage,

  /// The master library holds no illustration under the requested identity.
  illustrationNotFound,

  /// The illustration exists but the PC has not drawn its image yet.
  ///
  /// Not a fault: it is the normal answer for a page whose picture is still
  /// queued, still rendering, or was never rendered successfully, so surfaces
  /// say "not made yet" instead of showing a failure.
  illustrationNotReady,

  /// Generation ran and failed on the PC; no story exists there.
  generationFailed,

  /// Generation stopped because this device asked the bridge to cancel it.
  cancelled,

  /// The answer was not the JSON shape this client understands.
  invalidResponse,

  /// The bridge reported a typed failure this build does not know.
  bridgeError,
}

/// Typed local-bridge failure carrying no bridge-authored text.
class BridgeException implements Exception {
  /// Creates a failure from its typed reason and optional bridge error code.
  const BridgeException(this.failure, {this.code});

  /// Reason the call failed, used to pick one localized parent-facing message.
  final BridgeFailure failure;

  /// Machine-readable code reported by the bridge, absent for local failures.
  ///
  /// Diagnostic only: it is never shown to a parent and never contains story
  /// text, a child name, or a token.
  final String? code;

  /// Keeps diagnostics free of bridge-authored prose and of any secret.
  @override
  String toString() {
    final reportedCode = code;
    return reportedCode == null
        ? 'BridgeException(${failure.name})'
        : 'BridgeException(${failure.name}, $reportedCode)';
  }
}
