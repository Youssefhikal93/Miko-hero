import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

/// Asks the parent for whatever one action needs before it may run.
///
/// Returning null cancels the action: a dismissed dialog, a refused
/// confirmation and a closed password prompt all mean the same thing here, and
/// nothing after this step runs.
typedef ParentGatedConfirm<T extends Object> =
    Future<T?> Function(BuildContext context);

/// Performs one confirmed action and returns whatever its report needs.
///
/// The context is passed because some actions keep the parent in a dialog while
/// they run; it is mounted at the moment this step is called.
typedef ParentGatedRun<T extends Object, R> =
    Future<R> Function(BuildContext context, T confirmation);

/// The one sentence an outcome leaves behind, or null for a silent action.
typedef ParentGatedReport<R> =
    String? Function(AppLocalizations text, R outcome);

/// The one sentence a failed action leaves behind.
typedef ParentGatedFailureReport =
    String Function(AppLocalizations text, Object failure);

/// Runs one parent-only action as gate, confirmation, action, then outcome.
///
/// Deleting a story, making its pictures, writing a story file, reading one
/// back, changing its collections and saving a PDF are all the same sequence
/// with different steps in it, so the sequence lives here once: the PIN gate
/// first, the parent's decision second, the action itself third, and one
/// sentence about how it went last.
///
/// Every "is this context still mounted" question is answered here too. The
/// messenger is taken before the action starts, so an action that empties the
/// shelf it was started from still says what it did — the screen underneath may
/// legitimately be gone by then, but the family is still owed the answer.
Future<void> runParentGatedAction<T extends Object, R>(
  BuildContext context,
  WidgetRef ref, {
  required ParentGatedConfirm<T> confirm,
  required ParentGatedRun<T, R> run,
  required ParentGatedReport<R> report,
  ParentGatedFailureReport onFailure = recoverableActionFailure,
}) async {
  final text = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (!await requestParentAccess(context, ref) || !context.mounted) return;
  try {
    final confirmation = await confirm(context);
    if (confirmation == null || !context.mounted) return;
    final outcome = await run(context, confirmation);
    reportActionOutcome(messenger, report(text, outcome));
  } on Exception catch (failure) {
    reportActionOutcome(messenger, onFailure(text, failure));
  }
}

/// Builds a confirmation step from a dialog that answers yes or no.
///
/// Refusing and dismissing are the same answer, so both cancel the action
/// rather than letting `false` travel on as a decision.
ParentGatedConfirm<bool> confirmedByDialog(WidgetBuilder builder) {
  return (context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: builder,
    );
    return confirmed == true ? true : null;
  };
}

/// The sentence an action that simply could not finish leaves behind.
///
/// The default for anything whose failures say nothing a parent could act on;
/// flows with typed reasons pass their own localizer instead.
String recoverableActionFailure(AppLocalizations text, Object failure) {
  return text.somethingWentWrong;
}

/// Shows one outcome message, replacing whatever notice is on screen.
///
/// One visible message at a time is the whole point: these arrive after a
/// parent's deliberate action, so the latest answer is the one that matters and
/// a queue of stale notices would bury it. A null message says nothing at all,
/// which is how a silent action reports.
void reportActionOutcome(ScaffoldMessengerState messenger, String? message) {
  if (message == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
