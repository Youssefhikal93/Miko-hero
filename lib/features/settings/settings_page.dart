import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/features/settings/ai_connection_card.dart';
import 'package:miko_hero/features/settings/backup_settings_card.dart';
import 'package:miko_hero/features/settings/parent_security_settings_card.dart';
import 'package:miko_hero/features/settings/settings_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_language_dropdown.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Language, profile, privacy, and destructive local-data controls.
class SettingsPage extends ConsumerWidget {
  /// Creates the routed settings destination.
  const SettingsPage({super.key});

  @override
  /// Rebuilds translated controls immediately after locale changes.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _SettingsContent(state: snapshot),
    );
  }
}

/// Loaded settings content with explicit persistence commands.
class _SettingsContent extends ConsumerWidget {
  /// Creates settings from one immutable state snapshot.
  const _SettingsContent({required this.state});

  final AppState state;

  @override
  /// Renders privacy facts and actions without any cloud-account controls.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(title: text.settingsTitle),
          const SizedBox(height: 22),
          _languageCard(context, ref, text),
          const SizedBox(height: 16),
          _profileCard(context, text),
          const SizedBox(height: 16),
          const ParentSecuritySettingsCard(),
          const SizedBox(height: 16),
          const AiConnectionCard(),
          const SizedBox(height: 16),
          const BackupSettingsCard(),
          const SizedBox(height: 16),
          _privacyCard(context, text),
          const SizedBox(height: 16),
          _aboutCard(context, text),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteAll(context, ref),
              icon: const Icon(Icons.delete_forever_rounded),
              label: Text(text.deleteAllData),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the four-language interface selector backed by local persistence.
  Widget _languageCard(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations text,
  ) {
    final selectedLanguage = AppLanguage.fromCode(state.locale.languageCode);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: AppLanguageDropdown(
          key: ValueKey<String>('app-language-${selectedLanguage.code}'),
          selectedLanguage: selectedLanguage,
          label: text.appLanguage,
          onSelected: (language) {
            ref.read(settingsControllerProvider).setLocale(language.locale);
          },
        ),
      ),
    );
  }

  /// Provides one route for adding or editing private child profiles.
  Widget _profileCard(BuildContext context, AppLocalizations text) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.groups_2_rounded),
        title: Text(text.manageProfiles),
        subtitle: Text(text.profileCount(state.profiles.length)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/profiles'),
      ),
    );
  }

  /// States the actual local storage behavior instead of making broad claims.
  Widget _privacyCard(BuildContext context, AppLocalizations text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.shield_rounded,
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

  /// Describes only integrations represented by current source code and plans.
  Widget _aboutCard(BuildContext context, AppLocalizations text) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: const Icon(Icons.auto_stories_rounded),
        title: Text(text.aboutTitle),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(text.aboutBody),
        ),
      ),
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
