import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';
import 'package:miko_hero/shared/parent_gated_action.dart';

/// What the parent chose in the two-choice dialog for one bridge story.
enum BridgeStoryDeleteChoice {
  /// Free space here and keep the story in the family's PC library.
  removeFromDevice,

  /// Delete the story on the PC and therefore on every family device.
  deleteEverywhere,
}

/// Runs the parent-gated deletion flow for one story on a library shelf.
///
/// A demo story has exactly one meaning of "delete": the local copy is the
/// only copy. A story that also lives in the PC master library has two, and
/// they are very different, so the parent picks between them in words rather
/// than discovering the difference afterwards.
Future<void> deleteStoryWithParentGate(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) {
  if (BridgeStoryProvenance.storyIdOf(story) == null) {
    return _deleteLocalStory(context, ref, story);
  }
  return _deleteBridgeStory(context, ref, story);
}

/// What became of one story the PC master library also holds.
enum _BridgeStoryDeletion {
  /// Only this device's offline copy is gone; the PC still has the story.
  removedFromDevice,

  /// The PC deleted it, so every family device loses it at the next sync.
  deletedEverywhere,

  /// The PC had already deleted it, so this device only caught up.
  alreadyDeletedEverywhere,
}

/// Confirms and performs the single local deletion a demo story allows.
Future<void> _deleteLocalStory(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) {
  return runParentGatedAction<bool, void>(
    context,
    ref,
    confirm: confirmedByDialog((context) => const _DeleteStoryDialog()),
    run: (context, _) =>
        ref.read(storyControllerProvider).deleteStory(story.id),
    // The book leaving the shelf underneath is the whole answer.
    report: (text, _) => null,
  );
}

/// Asks which of the two deletions the parent means, then performs that one.
///
/// Deleting everywhere asks the PC first and only then drops the local copy:
/// offline it fails with the typed bridge message and changes nothing here,
/// because a local-only delete would quietly do something else than what the
/// parent asked for, and every other device would keep its copy.
Future<void> _deleteBridgeStory(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) {
  return runParentGatedAction<BridgeStoryDeleteChoice, _BridgeStoryDeletion>(
    context,
    ref,
    confirm: (context) => showDialog<BridgeStoryDeleteChoice>(
      context: context,
      builder: (context) => const _BridgeStoryDeleteDialog(),
    ),
    run: (context, choice) async {
      final library = ref.read(librarySyncControllerProvider.notifier);
      switch (choice) {
        case BridgeStoryDeleteChoice.removeFromDevice:
          await library.removeFromThisDevice(story.id);
          return _BridgeStoryDeletion.removedFromDevice;
        case BridgeStoryDeleteChoice.deleteEverywhere:
          final deletion = await library.deleteEverywhere(story.id);
          return deletion.alreadyDeleted
              ? _BridgeStoryDeletion.alreadyDeletedEverywhere
              : _BridgeStoryDeletion.deletedEverywhere;
      }
    },
    report: (text, deletion) => switch (deletion) {
      _BridgeStoryDeletion.removedFromDevice => text.storyRemovedFromDevice,
      _BridgeStoryDeletion.deletedEverywhere => text.storyDeletedEverywhere,
      _BridgeStoryDeletion.alreadyDeletedEverywhere =>
        text.storyAlreadyDeletedEverywhere,
    },
    onFailure: localAiFailureMessage,
  );
}

/// The one meaning "delete" has for a story only this device holds.
class _DeleteStoryDialog extends StatelessWidget {
  /// Creates the confirmation shown behind the parent gate.
  const _DeleteStoryDialog();

  @override
  /// Says that the copy being deleted is the only copy there is.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.deleteStoryTitle),
      content: Text(text.deleteStoryBody),
      actions: <Widget>[
        TextButton(
          onPressed: () => context.pop(false),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: () => context.pop(true),
          child: Text(text.confirmDelete),
        ),
      ],
    );
  }
}

/// The two clearly worded deletion choices for one bridge story.
class _BridgeStoryDeleteDialog extends StatelessWidget {
  /// Creates the choice dialog shown behind the parent gate.
  const _BridgeStoryDeleteDialog();

  @override
  /// Spells out both consequences before either of them can be chosen.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      // Both consequences are spelled out in full, which is more text than a
      // short phone dialog fits: let it scroll rather than clip a warning.
      scrollable: true,
      title: Text(text.deleteBridgeStoryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.deleteBridgeStoryBody),
          const SizedBox(height: 14),
          Text(
            text.removeStoryFromDevice,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(text.removeStoryFromDeviceDetail),
          const SizedBox(height: 14),
          Text(
            text.deleteStoryEverywhere,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(text.deleteStoryEverywhereDetail),
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(), child: Text(text.cancel)),
        FilledButton.tonal(
          key: const ValueKey<String>('remove-story-from-device'),
          onPressed: () =>
              context.pop(BridgeStoryDeleteChoice.removeFromDevice),
          child: Text(text.removeStoryFromDevice),
        ),
        FilledButton(
          key: const ValueKey<String>('delete-story-everywhere'),
          onPressed: () =>
              context.pop(BridgeStoryDeleteChoice.deleteEverywhere),
          child: Text(text.deleteStoryEverywhere),
        ),
      ],
    );
  }
}
