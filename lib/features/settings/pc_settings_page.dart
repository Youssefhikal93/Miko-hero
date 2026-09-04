import 'package:flutter/material.dart';
import 'package:miko_hero/features/settings/ai_connection_card.dart';
import 'package:miko_hero/features/settings/settings_group_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// The family PC: the generator, its address, pairing, devices, and syncing.
///
/// The whole AI connection card moves here unchanged. It was the reason the old
/// settings page ran several screens tall on a phone, and it is the one group
/// that genuinely needs a page to itself.
class PcSettingsPage extends StatelessWidget {
  /// Creates the routed The PC group.
  const PcSettingsPage({super.key});

  @override
  /// Hands the whole card the page it always needed.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return SettingsGroupPage(
      title: text.settingsPcTitle,
      subtitle: text.settingsPcBody,
      children: const <Widget>[AiConnectionCard()],
    );
  }
}
