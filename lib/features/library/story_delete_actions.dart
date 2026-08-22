import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

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
) async {
  final hasAccess = await requestParentAccess(context, ref);
  if (!hasAccess || !context.mounted) return;
  if (BridgeStoryProvenance.storyIdOf(story) == null) {
    await _deleteLocalStory(context, ref, story);
    return;
  }
  final choice = await showDialog<BridgeStoryDeleteChoice>(
    context: context,
    builder: (context) => const _BridgeStoryDeleteDialog(),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case BridgeStoryDeleteChoice.removeFromDevice:
      await _removeFromThisDevice(context, ref, story);
    case BridgeStoryDeleteChoice.deleteEverywhere:
      await _deleteEverywhere(context, ref, story);
  }
}

/// Confirms and performs the single local deletion a demo story allows.
Future<void> _deleteLocalStory(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) async {
  final text = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
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
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(storyControllerProvider).deleteStory(story.id);
  } on Exception {
    _report(messenger, text.somethingWentWrong);
  }
}

/// Deletes only this device's copy and keeps sync from bringing it back.
Future<void> _removeFromThisDevice(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) async {
  final text = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(librarySyncControllerProvider.notifier)
        .removeFromThisDevice(story.id);
    _report(messenger, text.storyRemovedFromDevice);
  } on Exception {
    _report(messenger, text.somethingWentWrong);
  }
}

/// Deletes the story on the PC first and only then on this device.
///
/// Offline this fails with the typed bridge message and changes nothing here:
/// a local-only delete would quietly do something else than what the parent
/// asked for, and every other device would keep its copy.
Future<void> _deleteEverywhere(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) async {
  final text = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    final deletion = await ref
        .read(librarySyncControllerProvider.notifier)
        .deleteEverywhere(story.id);
    _report(
      messenger,
      deletion.alreadyDeleted
          ? text.storyAlreadyDeletedEverywhere
          : text.storyDeletedEverywhere,
    );
  } on Exception catch (error) {
    _report(messenger, localAiFailureMessage(text, error));
  }
}

/// Shows one short outcome without leaving the shelf the parent is on.
void _report(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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
