import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/features/settings/backup_settings_card.dart';
import 'package:miko_hero/features/settings/settings_controller.dart';
import 'package:miko_hero/features/settings/settings_group_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';

/// Backups, what this device keeps, and the one command that erases it all.
class DataSettingsPage extends ConsumerWidget {
  /// Creates the routed Your data group.
  const DataSettingsPage({super.key});

  @override
  /// Keeps the irreversible command at the bottom, apart from everything else.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    return SettingsGroupPage(
      title: text.settingsDataTitle,
      subtitle: text.settingsDataBody,
      children: <Widget>[
        const BackupSettingsCard(),
        const SizedBox(height: 16),
        _PrivacyCard(text: text),
        SettingsDangerAction(
          key: const ValueKey<String>('settings-delete-everything'),
          label: text.deleteAllData,
          icon: AppIcons.deleteEverything,
          note: text.deleteAllBody,
          onPressed: () => _confirmDeleteAll(context, ref),
        ),
      ],
    );
  }

  /// Requires confirmation before deleting every profile, photo, and story.
  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref) async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.deleteAllTitle),
        content: Text(text.deleteAllBody),
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
    await ref.read(settingsControllerProvider).clearFamilyData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.allDataDeleted)));
  }
}

/// States the actual local storage behavior instead of making broad claims.
class _PrivacyCard extends StatelessWidget {
  /// Creates the privacy note in the already-resolved interface language.
  const _PrivacyCard({required this.text});

  final AppLocalizations text;

  @override
  /// Names what leaves this device, which is nothing a parent did not export.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              AppIcons.privacy,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text.privacyTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(text.privacyBody),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
