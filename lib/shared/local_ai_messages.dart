import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/local_ai_progress.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Localizes one typed bridge failure for a parent-facing surface.
///
/// The bridge's own English message is deliberately never shown: only its
/// typed reason crosses the client boundary, so every sentence a parent reads
/// is written in the interface language. Anything that is not a bridge failure
/// keeps the app's existing recoverable wording.
String localAiFailureMessage(AppLocalizations text, Object error) {
  if (error is! BridgeException) return text.somethingWentWrong;
  return switch (error.failure) {
    BridgeFailure.unreachable => text.bridgeUnreachable,
    BridgeFailure.timedOut => text.bridgeTimedOut,
    BridgeFailure.notPaired => text.bridgeNotPaired,
    BridgeFailure.unauthorized => text.bridgeUnauthorized,
    BridgeFailure.rateLimited => text.bridgeRateLimited,
    BridgeFailure.pairingNotFound => text.bridgePairingNotFound,
    BridgeFailure.pairingExpired => text.bridgePairingExpired,
    BridgeFailure.invalidPairingCode => text.bridgeInvalidPairingCode,
    BridgeFailure.invalidRequest => text.bridgeInvalidRequest,
    BridgeFailure.jobNotFound => text.bridgeJobNotFound,
    BridgeFailure.generationFailed => text.bridgeGenerationFailed,
    BridgeFailure.cancelled => text.bridgeGenerationCancelled,
    BridgeFailure.invalidResponse => text.bridgeInvalidResponse,
    BridgeFailure.bridgeError => text.bridgeProblem,
  };
}

/// Localizes what the paired PC is doing right now.
///
/// The bridge reports its own English `progress` sentence; this replaces it so
/// a waiting parent reads the stage in their own language.
String localAiProgressMessage(AppLocalizations text, LocalAiProgress progress) {
  return switch (progress.stage) {
    LocalAiStage.submitting => text.localAiSubmitting,
    LocalAiStage.queued => _queuedMessage(text, progress.queuePosition),
    LocalAiStage.writing => text.localAiWriting,
    LocalAiStage.checking => text.localAiChecking,
  };
}

/// Names the place in line only when the bridge reported one.
String _queuedMessage(AppLocalizations text, int? queuePosition) {
  if (queuePosition == null) return text.localAiQueued;
  return text.localAiQueuedPosition(queuePosition);
}
