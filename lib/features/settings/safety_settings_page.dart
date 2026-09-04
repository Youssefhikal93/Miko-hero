import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/features/settings/parent_security_settings_card.dart';
import 'package:miko_hero/features/settings/settings_group_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';

/// The parent PIN, what locking does, and the topics stories stay away from.
class SafetySettingsPage extends ConsumerWidget {
  /// Creates the routed Safety group.
  const SafetySettingsPage({super.key});

  @override
  /// Rebuilds the exclusion count as soon as a child's preferences change.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _SafetySettings(state: snapshot),
    );
  }
}

/// The PIN card over the entry point to the per-child topic exclusions.
class _SafetySettings extends StatelessWidget {
  /// Creates the group from one immutable state snapshot.
  const _SafetySettings({required this.state});

  final AppState state;

  @override
  /// Links to the exclusions rather than copying the editor that owns them.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final excluded = <SafetyTopic>{
      for (final profile in state.profiles)
        ...profile.storyPreferences.excludedTopics,
    };
    return SettingsGroupPage(
      title: text.settingsSafetyTitle,
      subtitle: text.settingsSafetyBody,
      children: <Widget>[
        const ParentSecuritySettingsCard(),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            key: const ValueKey<String>('settings-safety-topics'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: const Icon(AppIcons.storyPreferences),
            title: Text(text.safetyControls),
            subtitle: Text(
              '${text.safetyRulesValue(excluded.length)}\n'
              '${text.settingsSafetyTopicsBody}',
            ),
            isThreeLine: true,
            trailing: const Icon(AppIcons.forward),
            onTap: () => context.go('/kingdom'),
          ),
        ),
      ],
    );
  }
}
