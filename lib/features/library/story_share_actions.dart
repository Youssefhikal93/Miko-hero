import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/shared_story.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/library/story_share_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/encrypted_file_messages.dart';
import 'package:miko_hero/shared/encryption_password_dialog.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

/// Saves one story as an encrypted single-story file, behind the parent gate.
///
/// The file carries the story and the hero's display name only; the child's
/// reference photo and every other profile detail stay on this device.
Future<void> exportStoryFile(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) async {
  if (!await requestParentAccess(context, ref) || !context.mounted) return;
  final text = AppLocalizations.of(context);
  final password = await showEncryptionPasswordDialog(
    context,
    copy: _storyPasswordCopy(
      text,
      title: text.createStoryPasswordTitle,
      requirements:
          '${text.backupPasswordRequirements} ${text.storyFileNotice}',
    ),
    confirmPassword: true,
  );
  if (password == null || !context.mounted) return;
  try {
    final saved = await ref
        .read(storyShareControllerProvider)
        .exportStory(
          story.id,
          password,
          dialogTitle: text.saveStoryFileDialogTitle,
        );
    if (!context.mounted) return;
    _showMessage(
      context,
      saved ? text.storyFileSaved : text.storyFileSaveCancelled,
    );
  } on Exception catch (error) {
    if (context.mounted) _showMessage(context, storyFileMessage(text, error));
  }
}

/// Imports one encrypted story file into a profile the parent chooses.
///
/// Runs pick file, password, preview, and profile choice as separate confirmed
/// steps; dismissing any of them imports nothing.
Future<void> importStoryFile(
  BuildContext context,
  WidgetRef ref, {
  required AppState state,
}) async {
  final text = AppLocalizations.of(context);
  if (state.profiles.isEmpty) {
    _showMessage(context, text.importStoryNeedsProfile);
    return;
  }
  if (!await requestParentAccess(context, ref) || !context.mounted) return;
  final controller = ref.read(storyShareControllerProvider);
  try {
    final shared = await controller.openStoryFile(
      askPassword: (fileName) async {
        if (!context.mounted) return null;
        return showEncryptionPasswordDialog(
          context,
          copy: _storyPasswordCopy(
            text,
            title: text.enterStoryPasswordTitle,
            requirements: text.backupPasswordRequirements,
          ),
          confirmPassword: false,
          fileContext: text.restoreFileName(fileName),
        );
      },
    );
    if (shared == null || !context.mounted) return;
    final profileId = await showDialog<String>(
      context: context,
      builder: (context) => _ImportStoryDialog(
        shared: shared,
        profiles: state.profiles,
        initialProfileId: state.activeProfileId ?? state.profiles.first.id,
      ),
    );
    if (profileId == null || !context.mounted) return;
    await controller.importStory(shared, profileId);
    if (!context.mounted) return;
    _showMessage(context, text.storyImported(shared.story.content.title));
  } on Exception catch (error) {
    if (context.mounted) _showMessage(context, storyFileMessage(text, error));
  }
}

/// Preview of a decoded story plus the profile that will receive it.
class _ImportStoryDialog extends StatefulWidget {
  /// Creates the confirmation step for one already decrypted story file.
  const _ImportStoryDialog({
    required this.shared,
    required this.profiles,
    required this.initialProfileId,
  });

  final SharedStory shared;
  final List<ChildProfile> profiles;
  final String initialProfileId;

  @override
  /// Creates the destination choice discarded when the dialog is dismissed.
  State<_ImportStoryDialog> createState() => _ImportStoryDialogState();
}

/// Holds the chosen destination profile until the parent confirms the import.
class _ImportStoryDialogState extends State<_ImportStoryDialog> {
  late String _profileId;

  @override
  /// Starts from the active hero so the common case is a single tap.
  void initState() {
    super.initState();
    _profileId = widget.initialProfileId;
  }

  @override
  /// Shows the story title, page count, and hero before anything is stored.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final shared = widget.shared;
    return AlertDialog(
      title: Text(text.importStoryTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              shared.story.content.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(text.importStoryPages(shared.pageCount)),
            Text(text.importStoryHero(shared.heroName)),
            const SizedBox(height: 18),
            Text(text.importStoryChooseProfile),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.profiles
                  .map((profile) {
                    return ChoiceChip(
                      key: ValueKey<String>('import-profile-${profile.id}'),
                      selected: profile.id == _profileId,
                      onSelected: (_) =>
                          setState(() => _profileId = profile.id),
                      label: Text(profile.heroName),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(), child: Text(text.cancel)),
        FilledButton(
          onPressed: () => context.pop(_profileId),
          child: Text(text.importStoryAction),
        ),
      ],
    );
  }
}

/// Builds the story-file wording for the shared encryption password prompt.
EncryptionPasswordCopy _storyPasswordCopy(
  AppLocalizations text, {
  required String title,
  required String requirements,
}) {
  return EncryptionPasswordCopy(
    title: title,
    passwordLabel: text.storyFilePassword,
    confirmLabel: text.confirmStoryFilePassword,
    requirements: requirements,
    mismatch: text.storyFilePasswordMismatch,
    cancel: text.cancel,
    confirmAction: text.continueAction,
  );
}

/// Replaces any earlier notice with the latest story-file outcome.
void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
