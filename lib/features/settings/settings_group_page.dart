import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// The frame every Settings group opens in: its own header, then its content.
///
/// Each group is a routed screen rather than a card on one long page, so the
/// header belongs to the page and the shell adds none — the same arrangement
/// Create and the reader already use. The back control returns to the Settings
/// root, which is where every one of these pages is reached from.
class SettingsGroupPage extends StatelessWidget {
  /// Creates one group page titled [title] over [children].
  const SettingsGroupPage({
    required this.title,
    required this.children,
    this.subtitle,
    super.key,
  });

  /// Name of the group, printed in the page's own header.
  final String title;

  /// One sentence saying what the group decides, omitted when the rows do.
  final String? subtitle;

  /// Content of the group, laid out in one column under the header.
  final List<Widget> children;

  @override
  /// Keeps the group readable on a phone and centred in a desktop window.
  Widget build(BuildContext context) {
    return ScreenLayout(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsPageHeader(title: title),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(subtitle!, style: AppTheme.caption),
          ],
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );
  }
}

/// Back control and screen name, in the redesign's own header idiom.
class SettingsPageHeader extends StatelessWidget {
  /// Creates the header of one Settings group page.
  const SettingsPageHeader({required this.title, super.key});

  /// Name printed beside the back control.
  final String title;

  @override
  /// Puts the way back first, the way every self-headed screen does.
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          key: const ValueKey<String>('settings-group-back'),
          onPressed: () => _leave(context),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AppIcons.back),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
      ],
    );
  }

  /// Returns to the Settings root, which is the only way into these pages.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/settings');
    }
  }
}

/// One irreversible command, printed apart from everything else on its page.
///
/// Kept off the Settings root on purpose: deleting a family's whole library is
/// not something a parent should be one mis-tap away from while reading a list
/// of groups. It sits at the bottom of the page that owns it, in the danger
/// ink, behind the same parent gate as the rest of Settings.
class SettingsDangerAction extends StatelessWidget {
  /// Creates the destructive action [label] runs.
  const SettingsDangerAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.note,
    super.key,
  });

  /// What the command does, in the parent's language.
  final String label;

  /// Glyph naming the command.
  final IconData icon;

  /// Runs the command, which asks for confirmation itself.
  final VoidCallback onPressed;

  /// Sentence printed above the command, when one is worth printing.
  final String? note;

  @override
  /// Separates the command from the page above it before printing it.
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(height: 40),
        Text(
          AppLocalizations.of(context).settingsDangerZone.toUpperCase(),
          style: AppTheme.overline,
        ),
        if (note != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(note!, style: AppTheme.caption),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
          ),
        ),
      ],
    );
  }
}
