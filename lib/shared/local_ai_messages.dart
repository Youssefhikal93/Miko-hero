import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/ai_connection/local_ai_progress.dart';
import 'package:miko_hero/core/illustrations/illustration_service.dart';
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
    BridgeFailure.blockedByBrowser => text.bridgeBlockedByBrowser,
    BridgeFailure.timedOut => text.bridgeTimedOut,
    BridgeFailure.notPaired => text.bridgeNotPaired,
    BridgeFailure.unauthorized => text.bridgeUnauthorized,
    BridgeFailure.rateLimited => text.bridgeRateLimited,
    BridgeFailure.pairingNotFound => text.bridgePairingNotFound,
    BridgeFailure.pairingExpired => text.bridgePairingExpired,
    BridgeFailure.invalidPairingCode => text.bridgeInvalidPairingCode,
    BridgeFailure.invalidRequest => text.bridgeInvalidRequest,
    BridgeFailure.jobNotFound => text.bridgeJobNotFound,
    BridgeFailure.storyNotFound => text.bridgeStoryNotFound,
    BridgeFailure.profileNotFound => text.bridgeProfileNotFound,
    BridgeFailure.photoTooLarge => text.bridgePhotoTooLarge,
    BridgeFailure.unsupportedImage => text.bridgeUnsupportedImage,
    BridgeFailure.illustrationNotFound => text.bridgeIllustrationNotFound,
    BridgeFailure.illustrationNotReady => text.bridgeIllustrationNotReady,
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

/// Localizes what the paired PC is doing during one picture run.
///
/// The bridge also reports a ready-made English `progress` sentence; this is
/// built from the counts instead, so a waiting parent reads which page is being
/// drawn in their own language.
String illustrationProgressMessage(
  AppLocalizations text,
  IllustrationProgress progress,
) {
  return switch (progress.stage) {
    IllustrationStage.sendingPhoto => text.illustrationsSendingPhoto,
    IllustrationStage.submitting => text.illustrationsSubmitting,
    IllustrationStage.queued => _queuedMessage(text, progress.queuePosition),
    IllustrationStage.drawing => _drawingMessage(text, progress),
    IllustrationStage.downloading => text.illustrationsDownloading,
  };
}

/// Localizes how one finished picture run actually turned out.
///
/// A job reaches `completed` even when the PC failed on some pages, so the
/// counts decide the sentence rather than the status alone.
String illustrationOutcomeMessage(
  AppLocalizations text,
  IllustrationOutcome outcome,
) {
  if (outcome.status == BridgeIllustrationJobStatus.cancelled) {
    return text.illustrationsStopped;
  }
  if (outcome.wasAlreadyDone) return text.illustrationsAlreadyDone;
  if (outcome.drewNothing) return text.illustrationsNoneDrawn;
  if (outcome.drewEveryPage) {
    return text.illustrationsReady(outcome.completedPageCount);
  }
  return text.illustrationsPartlyReady(
    outcome.completedPageCount,
    outcome.pageCount,
  );
}

/// Names the page being drawn, or stays general until the PC has said how many.
String _drawingMessage(AppLocalizations text, IllustrationProgress progress) {
  final total = progress.pageCount;
  if (total <= 0) return text.illustrationsDrawingAny;
  final page = (progress.completedPageCount + 1).clamp(1, total);
  return text.illustrationsDrawing(page, total);
}

/// Names the place in line only when the bridge reported one.
String _queuedMessage(AppLocalizations text, int? queuePosition) {
  if (queuePosition == null) return text.localAiQueued;
  return text.localAiQueuedPosition(queuePosition);
}
