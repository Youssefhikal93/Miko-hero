import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:miko_hero/core/ai_connection/library_sync.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';

/// Parent-only synchronization controls inside the AI connection card.
///
/// Everything about synchronization lives here, behind the same parent gate as
/// the rest of the card: no child-facing screen mentions syncing, a manifest,
/// or the PC at all.
class LibrarySyncSection extends ConsumerWidget {
  /// Creates the synchronization block of the AI connection card.
  const LibrarySyncSection({super.key});

  @override
  /// Renders the stored synchronization record once it is readable.
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(librarySyncControllerProvider);
    return sync.when(
      data: (snapshot) => _LoadedLibrarySyncSection(snapshot: snapshot),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.error),
        title: Text(AppLocalizations.of(context).somethingWentWrong),
        trailing: TextButton(
          onPressed: () => ref.invalidate(librarySyncControllerProvider),
          child: Text(AppLocalizations.of(context).retry),
        ),
      ),
    );
  }
}

/// Loaded synchronization state, its last report, and its two commands.
class _LoadedLibrarySyncSection extends ConsumerWidget {
  /// Creates the section from one immutable synchronization snapshot.
  const _LoadedLibrarySyncSection({required this.snapshot});

  final LibrarySyncSnapshot snapshot;

  @override
  /// Groups the sync action, the last result, and the re-download control.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final result = snapshot.lastResult;
    final failure = snapshot.lastFailure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          text.librarySyncTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(text.librarySyncBody),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          key: const ValueKey<String>('sync-library-now'),
          onPressed: snapshot.isSyncing
              ? null
              : () => unawaited(_syncNow(context, ref)),
          icon: snapshot.isSyncing
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.sync),
          label: Text(
            snapshot.isSyncing ? text.librarySyncRunning : text.syncNow,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _lastSyncLabel(context, text),
          key: const ValueKey<String>('library-sync-last-run'),
        ),
        if (result != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            result.changedNothing
                ? text.librarySyncUpToDate
                : text.librarySyncResult(
                    result.addedCount,
                    result.updatedCount,
                    result.removedCount,
                  ),
            key: const ValueKey<String>('library-sync-result'),
          ),
        ],
        if (result != null && result.savedPictureCount > 0) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            text.librarySyncPictures(result.savedPictureCount),
            key: const ValueKey<String>('library-sync-pictures'),
          ),
        ],
        if (result != null && result.failedPictureCount > 0) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            text.illustrationsNotFetched(result.failedPictureCount),
            key: const ValueKey<String>('library-sync-pictures-failed'),
          ),
        ],
        if (failure != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            localAiFailureMessage(text, failure),
            key: const ValueKey<String>('library-sync-failure'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (result != null && result.pendingProfiles.isNotEmpty)
          _pendingProfiles(context, text, result.pendingProfiles),
        if (snapshot.hasDeclinedStories) _removedStories(context, ref, text),
      ],
    );
  }

  /// Names the children whose stories cannot be placed on this device yet.
  Widget _pendingProfiles(
    BuildContext context,
    AppLocalizations text,
    List<LibrarySyncPendingProfile> pendingProfiles,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text.librarySyncPendingProfilesTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          ...pendingProfiles.map(
            (pending) => Text(
              text.librarySyncPendingProfile(
                pending.storyCount,
                pending.displayName,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text.librarySyncPendingProfilesBody,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  /// Offers the stories this device removed on purpose back again.
  Widget _removedStories(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations text,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text.removedStoriesTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(text.removedStoriesBody(snapshot.declinedStoryCount)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey<String>('redownload-removed-stories'),
            onPressed: () => unawaited(_allowRemovedStoriesAgain(context, ref)),
            icon: const Icon(AppIcons.redownload),
            label: Text(text.redownloadRemovedStories),
          ),
        ],
      ),
    );
  }

  /// States when this device last agreed with the PC, in the local time zone.
  String _lastSyncLabel(BuildContext context, AppLocalizations text) {
    final lastSyncedAtUtc = snapshot.lastSyncedAtUtc;
    if (lastSyncedAtUtc == null) return text.librarySyncNever;
    final moment = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(lastSyncedAtUtc.toLocal());
    return text.librarySyncLastRun(moment);
  }

  /// Runs one synchronization and reports a typed failure in this language.
  Future<void> _syncNow(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(librarySyncControllerProvider.notifier).syncNow();
    } on Exception {
      // The failure is held in the snapshot and rendered by this section.
    }
  }

  /// Clears the not-wanted-offline list so the next sync downloads them again.
  Future<void> _allowRemovedStoriesAgain(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final text = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(librarySyncControllerProvider.notifier)
          .allowRemovedStoriesAgain();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(text.redownloadRemovedStoriesDone)),
        );
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }
}
