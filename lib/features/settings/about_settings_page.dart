import 'package:flutter/material.dart';
import 'package:miko_hero/features/settings/settings_group_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';

/// What this app is, and what actually writes and draws its stories.
class AboutSettingsPage extends StatelessWidget {
  /// Creates the routed About group.
  const AboutSettingsPage({super.key});

  @override
  /// Describes only integrations represented by current source code and plans.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SettingsGroupPage(
      title: text.aboutTitle,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  AppIcons.stories,
                  size: 38,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  text.appName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(text.aboutBody),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
