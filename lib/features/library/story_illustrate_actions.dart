import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/library/illustrate_story_controller.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';
import 'package:miko_hero/shared/parent_gated_action.dart';

/// Whether the picture-making action belongs on [story]'s card at all.
///
/// Only a story the PC master library holds can be illustrated, and only while
/// this device is actually paired with that PC. A demo story has no pages on
/// any PC, so offering the action there would promise something impossible.
bool canIllustrateStory(StoryBook story, AiConnectionState? connection) {
  if (connection == null) return false;
  if (!connection.usesLocalAi || !connection.isPaired) return false;
  return BridgeStoryProvenance.marksStory(story);
}

/// Runs the parent-gated picture-making flow for one PC library story.
///
/// Behind the same gate as deleting everywhere: this occupies the family PC for
/// several minutes per page and sends the child's photo there, so it is a
/// parent's decision, taken with the cost spelled out first.
Future<void> illustrateStoryWithParentGate(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) {
  return runParentGatedAction<bool, void>(
    context,
    ref,
    confirm: confirmedByDialog((context) => const _IllustrateStoryDialog()),
    run: (context, _) async {
      unawaited(
        ref.read(illustrateStoryControllerProvider.notifier).illustrate(story),
      );
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const _IllustrationRunDialog(),
      );
      ref.read(illustrateStoryControllerProvider.notifier).dismiss();
    },
    // The run dialog has already said how it went, in more words than a
    // passing notice could hold; repeating it underneath would be noise.
    report: (text, _) => null,
  );
}

/// States what making the pictures costs before any of it starts.
class _IllustrateStoryDialog extends StatelessWidget {
  /// Creates the confirmation shown behind the parent gate.
  const _IllustrateStoryDialog();

  @override
  /// Says how long it takes and that stopping keeps finished pictures.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(text.illustrateStoryTitle),
      content: Text(text.illustrateStoryBody),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(), child: Text(text.cancel)),
        FilledButton(
          key: const ValueKey<String>('start-illustrating'),
          onPressed: () => context.pop(true),
          child: Text(text.startIllustrating),
        ),
      ],
    );
  }
}

/// Live view of the run, with one honest sentence about where it has got to.
///
/// No spinner and no animated bar: the wait is measured in minutes per page, so
/// a sentence naming the page being drawn tells a parent far more than a
/// rotating circle, and it is the same text a screen reader can read out.
class _IllustrationRunDialog extends ConsumerWidget {
  /// Creates the dialog that follows the open picture run.
  const _IllustrationRunDialog();

  @override
  /// Shows the current stage while running and the report once it ends.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final run = ref.watch(illustrateStoryControllerProvider);
    return AlertDialog(
      scrollable: true,
      title: Text(text.illustrateStoryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _status(text, run),
            key: const ValueKey<String>('illustration-run-status'),
          ),
          ..._notices(context, text, run),
        ],
      ),
      actions: <Widget>[
        if (run == null || run.isRunning)
          TextButton(
            key: const ValueKey<String>('stop-illustrating'),
            onPressed: run == null || run.isCancelling
                ? null
                : () => unawaited(
                    ref
                        .read(illustrateStoryControllerProvider.notifier)
                        .cancel(),
                  ),
            child: Text(text.stopIllustrating),
          )
        else
          FilledButton(
            key: const ValueKey<String>('close-illustration-run'),
            onPressed: () => context.pop(),
            child: Text(text.close),
          ),
      ],
    );
  }

  /// One sentence describing the run: its stage, its report, or its failure.
  String _status(AppLocalizations text, IllustrateStoryRun? run) {
    if (run == null) return text.illustrationsSubmitting;
    final failure = run.failure;
    if (failure != null) return localAiFailureMessage(text, failure);
    final outcome = run.outcome;
    if (outcome != null) return illustrationOutcomeMessage(text, outcome);
    final progress = run.progress;
    if (progress == null) return text.illustrationsSubmitting;
    return illustrationProgressMessage(text, progress);
  }

  /// Adds the non-fatal notes a finished run leaves behind, if it left any.
  List<Widget> _notices(
    BuildContext context,
    AppLocalizations text,
    IllustrateStoryRun? run,
  ) {
    final outcome = run?.outcome;
    if (outcome == null) return const <Widget>[];
    final style = Theme.of(context).textTheme.bodySmall;
    return <Widget>[
      if (outcome.photoSkipped) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          text.referencePhotoSkipped,
          key: const ValueKey<String>('illustration-photo-skipped'),
          style: style,
        ),
      ],
      if (outcome.fetchFailureCount > 0) ...<Widget>[
        const SizedBox(height: 10),
        Text(
          text.illustrationsNotFetched(outcome.fetchFailureCount),
          key: const ValueKey<String>('illustration-fetch-failures'),
          style: style,
        ),
      ],
    ];
  }
}
