import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/features/settings/settings_controller.dart';
import 'package:miko_hero/features/settings/settings_group_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_language_dropdown.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';

/// Who this device is for, and which language it speaks to them in.
class FamilySettingsPage extends ConsumerWidget {
  /// Creates the routed Family group.
  const FamilySettingsPage({super.key});

  @override
  /// Rebuilds translated controls immediately after locale changes.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _FamilySettings(state: snapshot),
    );
  }
}

/// The profile entry point over the four-language interface selector.
class _FamilySettings extends ConsumerWidget {
  /// Creates the group from one immutable state snapshot.
  const _FamilySettings({required this.state});

  final AppState state;

  @override
  /// Keeps profile editing where it already lives and only links to it.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final selectedLanguage = AppLanguage.fromCode(state.locale.languageCode);
    return SettingsGroupPage(
      title: text.settingsFamilyTitle,
      subtitle: text.settingsFamilyBody,
      children: <Widget>[
        Card(
          child: ListTile(
            key: const ValueKey<String>('settings-manage-profiles'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: const Icon(AppIcons.heroFamily),
            title: Text(text.manageProfiles),
            subtitle: Text(text.profileCount(state.profiles.length)),
            trailing: const Icon(AppIcons.forward),
            onTap: () => context.go('/profiles'),
          ),
        ),
        const SizedBox(height: 16),
        Card(
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
        ),
      ],
    );
  }
}
