import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/illustrations/illustration_service.dart';
import 'package:miko_hero/l10n/app_localizations_en.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';

/// Verifies the sentence a parent reads once a picture run has ended.
///
/// The tricky case is a story whose pages were all drawn earlier: the PC then
/// reports a completed job of zero pages, which must read as "already done"
/// and never as a failure.
void main() {
  final text = AppLocalizationsEn();

  IllustrationOutcome outcome({
    required BridgeIllustrationJobStatus status,
    required int pageCount,
    required int completedPageCount,
    int failedPageCount = 0,
  }) {
    return IllustrationOutcome(
      status: status,
      pageCount: pageCount,
      completedPageCount: completedPageCount,
      failedPageCount: failedPageCount,
      savedIllustrationIds: const <String>[],
      fetchFailureCount: 0,
      photoSkipped: false,
    );
  }

  test('a job with nothing left to draw reads as already done', () {
    final alreadyDone = outcome(
      status: BridgeIllustrationJobStatus.completed,
      pageCount: 0,
      completedPageCount: 0,
    );
    expect(alreadyDone.wasAlreadyDone, isTrue);
    expect(
      illustrationOutcomeMessage(text, alreadyDone),
      text.illustrationsAlreadyDone,
    );
  });

  test('a job that tried pages and drew none reads as a failure', () {
    final noneDrawn = outcome(
      status: BridgeIllustrationJobStatus.failed,
      pageCount: 6,
      completedPageCount: 0,
      failedPageCount: 6,
    );
    expect(noneDrawn.wasAlreadyDone, isFalse);
    expect(
      illustrationOutcomeMessage(text, noneDrawn),
      text.illustrationsNoneDrawn,
    );
  });

  test('a fully drawn run still reads as ready', () {
    final ready = outcome(
      status: BridgeIllustrationJobStatus.completed,
      pageCount: 6,
      completedPageCount: 6,
    );
    expect(ready.wasAlreadyDone, isFalse);
    expect(illustrationOutcomeMessage(text, ready), text.illustrationsReady(6));
  });
}
