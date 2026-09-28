import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_language_dropdown.dart';
import 'package:miko_hero/shared/reading_comfort_controls.dart';

/// Per-child story defaults, recurring world, interests, and safety controls.
class StoryPreferencesCard extends ConsumerWidget {
  /// Creates preference controls for the active My Kingdom profile.
  const StoryPreferencesCard({required this.profile, super.key});

  /// Active child whose preferences are summarized and edited.
  final ChildProfile profile;

  @override
  /// Summarizes saved context and opens one isolated edit transaction.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final preferences = profile.storyPreferences;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.shelf),
              title: Text(text.storyPreferencesTitle),
              subtitle: Text(text.storyPreferencesBody(profile.name)),
            ),
            _PreferenceSummary(preferences: preferences),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => _editPreferences(context, ref),
              icon: const Icon(AppIcons.storyPreferences),
              label: Text(text.editStoryPreferences),
            ),
            const Divider(height: 34),
            ReadingComfortControls(profile: profile),
          ],
        ),
      ),
    );
  }

  /// Persists only a preference set explicitly confirmed in the dialog.
  Future<void> _editPreferences(BuildContext context, WidgetRef ref) async {
    final preferences = await showDialog<ChildStoryPreferences>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _StoryPreferencesDialog(initial: profile.storyPreferences);
      },
    );
    if (preferences == null || !context.mounted) return;
    final text = AppLocalizations.of(context);
    try {
      await ref
          .read(profileControllerProvider)
          .setStoryPreferences(profile.id, preferences);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.storyPreferencesSaved(profile.name))),
      );
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }
}

/// Compact read-only summary that avoids exposing empty placeholder values.
class _PreferenceSummary extends StatelessWidget {
  /// Creates a summary from one validated preference snapshot.
  const _PreferenceSummary({required this.preferences});

  final ChildStoryPreferences preferences;

  @override
  /// Shows default language plus optional inspiration and safety counts.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final entries = <String>[
      text.defaultStoryLanguageValue(
        appLanguageName(text, preferences.defaultLanguage),
      ),
      if (preferences.favoriteThings.isNotEmpty)
        text.favoriteThingsValue(preferences.favoriteThings),
      if (preferences.recurringWorld.isNotEmpty)
        text.recurringWorldValue(preferences.recurringWorld),
      text.safetyRulesValue(preferences.excludedTopics.length),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(entry),
            ),
          )
          .toList(growable: false),
    );
  }
}

/// Dialog that owns unsaved preference fields and safety-chip selection.
class _StoryPreferencesDialog extends StatefulWidget {
  /// Creates an edit buffer from the selected child's current preferences.
  const _StoryPreferencesDialog({required this.initial});

  final ChildStoryPreferences initial;

  @override
  /// Creates disposable text fields and copied selection state.
  State<_StoryPreferencesDialog> createState() {
    return _StoryPreferencesDialogState();
  }
}

/// Mutable preference buffer that returns a model only after validation.
class _StoryPreferencesDialogState extends State<_StoryPreferencesDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _favoriteThingsController;
  late final TextEditingController _recurringWorldController;
  late AppLanguage _defaultLanguage;
  late Set<SafetyTopic> _excludedTopics;

  @override
  /// Seeds isolated fields from the currently persisted child settings.
  void initState() {
    super.initState();
    final initial = widget.initial;
    _favoriteThingsController = TextEditingController(
      text: initial.favoriteThings,
    );
    _recurringWorldController = TextEditingController(
      text: initial.recurringWorld,
    );
    _defaultLanguage = initial.defaultLanguage;
    _excludedTopics = initial.excludedTopics.toSet();
  }

  @override
  /// Releases parent-entered text when the dialog closes.
  void dispose() {
    _favoriteThingsController.dispose();
    _recurringWorldController.dispose();
    super.dispose();
  }

  @override
  /// Renders language, context fields, and independently selectable exclusions.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.editStoryPreferences),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AppLanguageDropdown(
                  selectedLanguage: _defaultLanguage,
                  label: text.defaultStoryLanguage,
                  onSelected: (language) {
                    setState(() => _defaultLanguage = language);
                  },
                ),
                const SizedBox(height: 16),
                _preferenceField(
                  controller: _favoriteThingsController,
                  label: text.favoriteThings,
                  hint: text.favoriteThingsHint,
                ),
                const SizedBox(height: 16),
                _preferenceField(
                  controller: _recurringWorldController,
                  label: text.recurringWorld,
                  hint: text.recurringWorldHint,
                ),
                const SizedBox(height: 20),
                Text(
                  text.safetyControls,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(text.safetyControlsHint),
                const SizedBox(height: 12),
                _safetyTopics(text),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(), child: Text(text.cancel)),
        FilledButton(onPressed: _save, child: Text(text.savePreferences)),
      ],
    );
  }

  /// Creates one optional, length-limited parent context field.
  Widget _preferenceField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maximumPreferenceTextLength,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  /// Builds translated safety choices without deriving policy from gender.
  Widget _safetyTopics(AppLocalizations text) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SafetyTopic.values
          .map((topic) {
            return FilterChip(
              selected: _excludedTopics.contains(topic),
              label: Text(_safetyTopicName(text, topic)),
              onSelected: (selected) {
                setState(() {
                  selected
                      ? _excludedTopics.add(topic)
                      : _excludedTopics.remove(topic);
                });
              },
            );
          })
          .toList(growable: false),
    );
  }

  /// Returns a validated immutable preference snapshot to the caller.
  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.pop(
      ChildStoryPreferences(
        defaultLanguage: _defaultLanguage,
        favoriteThings: _favoriteThingsController.text.trim(),
        recurringWorld: _recurringWorldController.text.trim(),
        excludedTopics: Set<SafetyTopic>.unmodifiable(_excludedTopics),
      ),
    );
  }
}

/// Localizes one exclusion while retaining its stable storage enum.
String _safetyTopicName(AppLocalizations text, SafetyTopic topic) {
  return switch (topic) {
    SafetyTopic.frighteningContent => text.avoidFrighteningContent,
    SafetyTopic.violence => text.avoidViolence,
    SafetyTopic.bullying => text.avoidBullying,
    SafetyTopic.griefAndLoss => text.avoidGriefAndLoss,
  };
}
