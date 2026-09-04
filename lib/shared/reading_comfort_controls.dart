import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Reader text size and easy-reading font controls for one child.
///
/// Lives here rather than inside one screen because two surfaces ask the same
/// question: My Kingdom, beside the story preferences of the child a parent is
/// already looking at, and the Reading page in Settings, once per child. Both
/// write through the same profile command, so a size chosen in either place is
/// the same saved value.
///
/// The values only change how existing prose is displayed and never reach a
/// generator, which is why they are stored apart from story preferences.
class ReadingComfortControls extends ConsumerWidget {
  /// Creates comfort controls for one saved child profile.
  const ReadingComfortControls({required this.profile, super.key});

  /// Child whose saved reading comfort is shown and edited.
  final ChildProfile profile;

  @override
  /// Saves every choice immediately, the way the kingdom style card does.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final settings = profile.readingSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          text.readingComfortTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(text.readingComfortBody(profile.name)),
        const SizedBox(height: 14),
        Text(text.readerTextSize),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReaderTextSize.values
              .map((size) {
                return ChoiceChip(
                  key: ValueKey<String>(
                    'reader-text-size-${profile.id}-${size.name}',
                  ),
                  selected: settings.textSize == size,
                  onSelected: (_) =>
                      _save(context, ref, settings.withTextSize(size)),
                  label: Text(readerTextSizeLabel(text, size)),
                );
              })
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        SwitchListTile(
          key: ValueKey<String>('easy-reading-font-${profile.id}'),
          contentPadding: EdgeInsets.zero,
          value: settings.easyReadingFont,
          title: Text(text.easyReadingFont),
          subtitle: Text(text.easyReadingFontHint),
          onChanged: (enabled) =>
              _save(context, ref, settings.withEasyReadingFont(enabled)),
        ),
      ],
    );
  }

  /// Persists one comfort change and confirms it with a short message.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    ChildReadingSettings settings,
  ) async {
    final text = AppLocalizations.of(context);
    try {
      await ref
          .read(profileControllerProvider)
          .setReadingSettings(profile.id, settings);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(text.readingComfortSaved(profile.name))),
        );
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }
}

/// Localizes one reader prose size while keeping its stable storage name.
String readerTextSizeLabel(AppLocalizations text, ReaderTextSize size) {
  return switch (size) {
    ReaderTextSize.small => text.textSizeSmall,
    ReaderTextSize.medium => text.textSizeMedium,
    ReaderTextSize.large => text.textSizeLarge,
    ReaderTextSize.extraLarge => text.textSizeExtraLarge,
  };
}
