import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:miko_hero/features/settings/settings_summaries.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// The Settings root: six groups, each saying what is currently true.
///
/// Nothing is edited here. Every control a parent can change lives on the page
/// of the group that owns it, so the root stays a short list a phone shows in
/// one screen instead of seven expanded forms stacked on each other.
class SettingsPage extends ConsumerWidget {
  /// Creates the routed settings destination.
  const SettingsPage({super.key});

  @override
  /// Rebuilds translated rows immediately after locale changes.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _SettingsGroups(state: snapshot),
    );
  }
}

/// The grouped rows, each over the one line its own stored state says.
class _SettingsGroups extends ConsumerWidget {
  /// Creates the root list from one immutable state snapshot.
  const _SettingsGroups({required this.state});

  final AppState state;

  @override
  /// Reads every summary from stored state, never from the PC.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final connection = ref.watch(aiConnectionControllerProvider).value;
    final sync = ref.watch(librarySyncControllerProvider).value;
    final access = ref.watch(parentAccessControllerProvider).value;
    final language = AppLanguage.fromCode(state.locale.languageCode);
    return ScreenLayout(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.settingsTitle,
            subtitle: text.settingsSubtitle,
          ),
          const SizedBox(height: 22),
          _SettingsGroupRow(
            group: 'family',
            icon: AppIcons.heroFamily,
            title: text.settingsFamilyTitle,
            summary: familySummary(text, state.profiles, language),
            route: '/settings/family',
          ),
          _SettingsGroupRow(
            group: 'reading',
            icon: AppIcons.reading,
            title: text.settingsReadingTitle,
            summary: readingSummary(text, state.profiles),
            route: '/settings/reading',
          ),
          _SettingsGroupRow(
            group: 'pc',
            icon: AppIcons.bridge,
            title: text.settingsPcTitle,
            summary: pcSummary(
              text,
              connection: connection,
              sync: sync,
              localeName: Localizations.localeOf(context).toString(),
            ),
            route: '/settings/pc',
          ),
          _SettingsGroupRow(
            group: 'safety',
            icon: AppIcons.parentSecurity,
            title: text.settingsSafetyTitle,
            summary: safetySummary(
              text,
              access: access,
              profiles: state.profiles,
            ),
            route: '/settings/safety',
          ),
          _SettingsGroupRow(
            group: 'data',
            icon: AppIcons.storedData,
            title: text.settingsDataTitle,
            summary: dataSummary(text, state.stories.length),
            route: '/settings/data',
          ),
          _SettingsGroupRow(
            group: 'about',
            icon: AppIcons.stories,
            title: text.aboutTitle,
            summary: text.settingsAboutSummary,
            route: '/settings/about',
          ),
        ],
      ),
    );
  }
}

/// One group of settings, named over the line saying what it currently holds.
class _SettingsGroupRow extends StatelessWidget {
  /// Creates the row that opens [route].
  const _SettingsGroupRow({
    required this.group,
    required this.icon,
    required this.title,
    required this.summary,
    required this.route,
  });

  /// Stable name of the group, used only to key the row and its summary.
  final String group;

  /// Glyph naming what the group decides.
  final IconData icon;

  /// Name of the group in the interface language.
  final String title;

  /// One line about what this group currently holds.
  final String summary;

  /// Page the row opens.
  final String route;

  @override
  /// Prints the summary under the name and opens the group on a tap.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          key: ValueKey<String>('settings-group-$group'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              summary,
              key: ValueKey<String>('settings-summary-$group'),
              style: AppTheme.caption,
            ),
          ),
          trailing: const Icon(AppIcons.forward),
          onTap: () => context.go(route),
        ),
      ),
    );
  }
}
