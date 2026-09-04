import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/features/settings/settings_group_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/empty_state.dart';
import 'package:miko_hero/shared/reading_comfort_controls.dart';

/// How story pages look for each child, and where reading aloud is decided.
class ReadingSettingsPage extends ConsumerWidget {
  /// Creates the routed Reading group.
  const ReadingSettingsPage({super.key});

  @override
  /// Rebuilds as soon as a saved reading choice changes.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _ReadingSettings(state: snapshot),
    );
  }
}

/// One reading-comfort block per child, then the note about narration.
class _ReadingSettings extends StatelessWidget {
  /// Creates the group from one immutable state snapshot.
  const _ReadingSettings({required this.state});

  final AppState state;

  @override
  /// Says plainly that narration is chosen per reading and stored nowhere.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SettingsGroupPage(
      title: text.settingsReadingTitle,
      subtitle: text.settingsReadingBody,
      children: <Widget>[
        if (state.profiles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: EmptyState(
              icon: AppIcons.heroPortrait,
              title: text.settingsNoHeroes,
              action: FilledButton.icon(
                onPressed: () => context.go('/profiles/new'),
                icon: const Icon(AppIcons.addHero),
                label: Text(text.setUpProfile),
              ),
            ),
          )
        else
          for (final profile in state.profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Card(
                key: ValueKey<String>('reading-comfort-${profile.id}'),
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: ReadingComfortControls(profile: profile),
                ),
              ),
            ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.narrationPlay),
                  title: Text(text.settingsNarrationTitle),
                  subtitle: Text(text.settingsNarrationBody),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
