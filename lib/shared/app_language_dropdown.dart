import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';

/// Four-language selector shared by app and story settings.
class AppLanguageDropdown extends StatelessWidget {
  /// Creates a full-width selector using localized language names.
  const AppLanguageDropdown({
    required this.selectedLanguage,
    required this.label,
    required this.onSelected,
    this.enabled = true,
    super.key,
  });

  /// Language currently displayed in the closed selector.
  final AppLanguage selectedLanguage;

  /// Localized field label describing what the language controls.
  final String label;

  /// Reports a deliberate, non-null language choice.
  final ValueChanged<AppLanguage> onSelected;

  /// Whether the menu accepts a new selection.
  final bool enabled;

  static const _menuStyle = MenuStyle(
    backgroundColor: WidgetStatePropertyAll<Color>(AppTheme.tile),
    surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
    elevation: WidgetStatePropertyAll<double>(10),
    padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(vertical: 8),
    ),
    shape: WidgetStatePropertyAll<OutlinedBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        side: BorderSide(color: AppTheme.hairline),
      ),
    ),
  );

  static const _entryStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll<Size>(Size.fromHeight(54)),
    padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
  );

  @override
  /// Renders a full-width Material 3 menu with clear language badges.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final primary = Theme.of(context).colorScheme.primary;
    return DropdownMenu<AppLanguage>(
      initialSelection: selectedLanguage,
      enabled: enabled,
      expandedInsets: EdgeInsets.zero,
      enableSearch: false,
      requestFocusOnTap: false,
      selectOnly: true,
      label: Text(label),
      leadingIcon: Icon(AppIcons.language, color: primary),
      trailingIcon: const Icon(AppIcons.dropdownClosed),
      selectedTrailingIcon: const Icon(AppIcons.dropdownOpen),
      inputDecorationTheme: _inputDecoration(primary),
      menuStyle: _menuStyle,
      dropdownMenuEntries: _languageEntries(text, primary),
      onSelected: _notifySelection,
    );
  }

  /// Matches the field outline to the active child profile's accent.
  InputDecorationTheme _inputDecoration(Color primary) {
    final outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: primary.withValues(alpha: 0.42)),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: AppTheme.sunken,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: outline,
      enabledBorder: outline,
    );
  }

  /// Builds one menu entry for every currently supported application language.
  List<DropdownMenuEntry<AppLanguage>> _languageEntries(
    AppLocalizations text,
    Color primary,
  ) {
    return AppLanguage.values
        .map((language) {
          return DropdownMenuEntry<AppLanguage>(
            value: language,
            label: _languageName(text, language),
            leadingIcon: _LanguageBadge(language: language),
            trailingIcon: language == selectedLanguage
                ? Icon(AppIcons.selectedLanguage, color: primary)
                : null,
            style: _entryStyle,
          );
        })
        .toList(growable: false);
  }

  /// Uses the current interface locale for every language display name.
  String _languageName(AppLocalizations text, AppLanguage language) {
    return switch (language) {
      AppLanguage.english => text.english,
      AppLanguage.arabic => text.arabic,
      AppLanguage.swedish => text.swedish,
      AppLanguage.somali => text.somali,
    };
  }

  /// Ignores framework null events and reports only complete selections.
  void _notifySelection(AppLanguage? language) {
    if (language != null) onSelected(language);
  }
}

/// Compact ISO badge displayed beside each localized language name.
class _LanguageBadge extends StatelessWidget {
  /// Creates a badge for one supported application language.
  const _LanguageBadge({required this.language});

  final AppLanguage language;

  @override
  /// Uses the active profile accent while preserving high text contrast.
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: 38,
      height: 30,
      alignment: Alignment.center,
      decoration: _decoration(primary),
      child: Text(language.code.toUpperCase(), style: _textStyle(primary)),
    );
  }

  /// Applies a subtle profile-colored surface without reducing contrast.
  BoxDecoration _decoration(Color primary) {
    return BoxDecoration(
      color: primary.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: primary.withValues(alpha: 0.34)),
    );
  }

  /// Keeps two-letter language codes compact and visually distinct.
  TextStyle _textStyle(Color primary) {
    return AppTheme.codeBadge.copyWith(color: primary);
  }
}
