import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_language_dropdown.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/gender_selector.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Guided story request form backed by the explicit local demo generator.
class StoryCreationPage extends ConsumerWidget {
  /// Creates the routed story-creation destination.
  const StoryCreationPage({super.key});

  @override
  /// Blocks generation until at least one persisted profile is available.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) {
        if (snapshot.profiles.isEmpty) return const _ProfileRequired();
        return _StoryForm(profiles: snapshot.profiles, locale: snapshot.locale);
      },
    );
  }
}

/// Direct recovery path when story creation is opened before profile setup.
class _ProfileRequired extends StatelessWidget {
  /// Creates a blocking state with one route back to profile setup.
  const _ProfileRequired();

  @override
  /// Explains the requirement and routes directly to a new private profile.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      maxWidth: 620,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: <Widget>[
              const Icon(Icons.person_add_alt_1_rounded, size: 46),
              const SizedBox(height: 14),
              Text(
                text.profileNeeded,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go('/profiles/new'),
                child: Text(text.setUpProfile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temporary form state retained until a request is generated or abandoned.
class _StoryForm extends ConsumerStatefulWidget {
  /// Creates a form using available profiles and the current interface locale.
  const _StoryForm({required this.profiles, required this.locale});

  final List<ChildProfile> profiles;
  final Locale locale;

  @override
  /// Creates isolated controls so incomplete ideas are not persisted.
  ConsumerState<_StoryForm> createState() => _StoryFormState();
}

/// Mutable story request buffer and generation progress state.
class _StoryFormState extends ConsumerState<_StoryForm> {
  final _formKey = GlobalKey<FormState>();
  final _themeController = TextEditingController();
  final _moralController = TextEditingController();
  String? _selectedProfileId;
  ChildGender? _selectedGender;
  late AppLanguage _language;
  StoryLength _length = StoryLength.short;
  IllustrationStyle _style = IllustrationStyle.pictureBook;
  bool _savingProfileSelection = false;
  bool _generating = false;

  @override
  /// Defaults story language to the parent's current interface language.
  void initState() {
    super.initState();
    _language = AppLanguage.fromCode(widget.locale.languageCode);
  }

  @override
  /// Releases temporary controllers after leaving the creation screen.
  void dispose() {
    _themeController.dispose();
    _moralController.dispose();
    super.dispose();
  }

  @override
  /// Renders validated inputs and an honest explanation of demo behavior.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final selectedProfile = _profileById(_selectedProfileId);
    return ScreenLayout(
      maxWidth: 820,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.createStoryTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            _profileField(text),
            if (_selectedProfileId != null) ...<Widget>[
              const SizedBox(height: 16),
              GenderSelector(
                key: ValueKey<String>(_selectedProfileId!),
                selectedGender: _selectedGender,
                enabled: !_generating && !_savingProfileSelection,
                onSelected: _genderSelected,
              ),
            ],
            const SizedBox(height: 16),
            _DemoNotice(text: text),
            if (selectedProfile != null) ...<Widget>[
              const SizedBox(height: 16),
              _SavedPreferencesNotice(profile: selectedProfile),
            ],
            const SizedBox(height: 20),
            _languageField(text),
            const SizedBox(height: 16),
            _themeField(text),
            const SizedBox(height: 16),
            _moralField(text),
            const SizedBox(height: 16),
            _lengthField(text),
            const SizedBox(height: 16),
            _styleField(text),
            const SizedBox(height: 28),
            _generateButton(text),
            if (_generating) ...<Widget>[
              const SizedBox(height: 22),
              _GenerationProgress(text: text),
            ],
          ],
        ),
      ),
    );
  }

  /// Requires the parent to choose which child will star in this story.
  Widget _profileField(AppLocalizations text) {
    return DropdownButtonFormField<String>(
      key: const ValueKey<String>('story-profile-selector'),
      initialValue: _selectedProfileId,
      decoration: InputDecoration(labelText: text.chooseHeroProfile),
      hint: Text(text.selectHeroProfile),
      items: widget.profiles.map((profile) {
        return DropdownMenuItem<String>(
          value: profile.id,
          child: Text(profile.heroName),
        );
      }).toList(),
      validator: (profileId) {
        return profileId == null ? text.profileSelectionRequired : null;
      },
      onChanged: _generating || _savingProfileSelection
          ? null
          : (profileId) => _profileSelected(profileId),
    );
  }

  /// Loads a profile's saved choice and applies its theme when already known.
  void _profileSelected(String? profileId) {
    if (profileId == null) return;
    final profile = widget.profiles.firstWhere(
      (candidate) => candidate.id == profileId,
    );
    final selectedGender = profile.gender.isSpecified ? profile.gender : null;
    setState(() {
      _selectedProfileId = profileId;
      _selectedGender = selectedGender;
      _language = profile.storyPreferences.defaultLanguage;
    });
    if (selectedGender != null) {
      setState(() => _savingProfileSelection = true);
      unawaited(_persistProfileSelection(profileId, selectedGender));
    }
  }

  /// Persists a deliberate Girl/Boy choice and updates the active app palette.
  void _genderSelected(ChildGender gender) {
    final profileId = _selectedProfileId;
    if (profileId == null || _savingProfileSelection) return;
    setState(() {
      _selectedGender = gender;
      _savingProfileSelection = true;
    });
    unawaited(_persistProfileSelection(profileId, gender));
  }

  /// Serializes profile selection and restores persisted input after a failure.
  Future<void> _persistProfileSelection(
    String profileId,
    ChildGender gender,
  ) async {
    try {
      await ref
          .read(profileControllerProvider)
          .selectProfile(profileId, gender);
    } on Exception {
      if (!mounted) return;
      final persistedProfile = ref
          .read(appControllerProvider)
          .value
          ?.profileById(profileId);
      setState(() {
        _selectedGender = persistedProfile?.gender.isSpecified == true
            ? persistedProfile?.gender
            : null;
      });
      _showError();
    } finally {
      if (mounted) setState(() => _savingProfileSelection = false);
    }
  }

  /// Builds the language selector from the four supported story contracts.
  Widget _languageField(AppLocalizations text) {
    return AppLanguageDropdown(
      selectedLanguage: _language,
      label: text.storyLanguage,
      enabled: !_generating,
      onSelected: (language) => setState(() => _language = language),
    );
  }

  /// Creates the required free-text adventure theme boundary.
  Widget _themeField(AppLocalizations text) {
    return TextFormField(
      controller: _themeController,
      enabled: !_generating,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: text.theme,
        hintText: text.themeHint,
      ),
      validator: (theme) {
        return theme == null || theme.trim().isEmpty
            ? text.themeRequired
            : null;
      },
    );
  }

  /// Creates the required educational-value input boundary.
  Widget _moralField(AppLocalizations text) {
    return TextFormField(
      controller: _moralController,
      enabled: !_generating,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: text.moral,
        hintText: text.moralHint,
      ),
      validator: (moral) {
        return moral == null || moral.trim().isEmpty
            ? text.moralRequired
            : null;
      },
    );
  }

  /// Creates the page-count selector whose values map to exact generator limits.
  Widget _lengthField(AppLocalizations text) {
    return DropdownButtonFormField<StoryLength>(
      initialValue: _length,
      decoration: InputDecoration(labelText: text.storyLength),
      items: StoryLength.values.map((length) {
        return DropdownMenuItem<StoryLength>(
          value: length,
          child: Text(_lengthName(text, length)),
        );
      }).toList(),
      onChanged: _generating
          ? null
          : (length) => setState(() => _length = length!),
    );
  }

  /// Creates the visual-style selector reserved for future ComfyUI prompts.
  Widget _styleField(AppLocalizations text) {
    return DropdownButtonFormField<IllustrationStyle>(
      initialValue: _style,
      decoration: InputDecoration(labelText: text.illustrationStyle),
      items: IllustrationStyle.values.map((style) {
        return DropdownMenuItem<IllustrationStyle>(
          value: style,
          child: Text(_styleName(text, style)),
        );
      }).toList(),
      onChanged: _generating
          ? null
          : (style) => setState(() => _style = style!),
    );
  }

  /// Prevents duplicate generation and exposes progress inside the primary action.
  Widget _generateButton(AppLocalizations text) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _generating || _savingProfileSelection
            ? null
            : _generateStory,
        icon: _generating
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(text.generateStory),
      ),
    );
  }

  /// Validates the request, persists the demo book, and opens its reader.
  Future<void> _generateStory() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = _selectedProfile();
    final gender = _selectedGender!;
    setState(() => _generating = true);
    try {
      await ref
          .read(profileControllerProvider)
          .selectProfile(profile.id, gender);
      final story = await ref
          .read(storyControllerProvider)
          .createStory(_storyRequest(profile, gender));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).storyCreated)),
      );
      context.go('/review/${story.id}');
    } on Exception {
      if (!mounted) return;
      setState(() => _generating = false);
      _showError();
    }
  }

  /// Captures one immutable request from the already-validated edit buffer.
  StoryRequest _storyRequest(ChildProfile profile, ChildGender gender) {
    return StoryRequest(
      hero: StoryHero(
        profileId: profile.id,
        name: profile.name,
        gender: gender,
      ),
      prompt: StoryPrompt(
        theme: _themeController.text.trim(),
        moral: _moralController.text.trim(),
        preferences: profile.storyPreferences,
      ),
      presentation: StoryPresentation(
        language: _language,
        length: _length,
        style: _style,
      ),
    );
  }

  /// Resolves the validated profile identity from the current widget snapshot.
  ChildProfile _selectedProfile() {
    return widget.profiles.firstWhere(
      (candidate) => candidate.id == _selectedProfileId,
    );
  }

  /// Resolves an optional form selection without assuming a profile exists.
  ChildProfile? _profileById(String? profileId) {
    if (profileId == null) return null;
    for (final profile in widget.profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  /// Shows recoverable local-write or generation failure feedback.
  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
    );
  }

  /// Returns the translated description of an exact story length.
  String _lengthName(AppLocalizations text, StoryLength length) {
    return switch (length) {
      StoryLength.short => text.shortLength,
      StoryLength.medium => text.mediumLength,
      StoryLength.long => text.longLength,
    };
  }

  /// Returns the translated label for a future illustration workflow.
  String _styleName(AppLocalizations text, IllustrationStyle style) {
    return switch (style) {
      IllustrationStyle.pictureBook => text.pictureBookStyle,
      IllustrationStyle.watercolor => text.watercolorStyle,
      IllustrationStyle.colorful3d => text.threeDStyle,
    };
  }
}

/// Visible confirmation that saved per-child prompt rules are being copied.
class _SavedPreferencesNotice extends StatelessWidget {
  /// Creates a prompt-context summary for the selected hero.
  const _SavedPreferencesNotice({required this.profile});

  final ChildProfile profile;

  @override
  /// Shows only saved inspiration plus the active safety-rule count.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final preferences = profile.storyPreferences;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.savedPreferencesInUse(
                profile.name,
                preferences.excludedTopics.length,
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (preferences.favoriteThings.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(text.favoriteThingsValue(preferences.favoriteThings)),
            ],
            if (preferences.recurringWorld.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(text.recurringWorldValue(preferences.recurringWorld)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Persistent explanation that the current generator is an offline sample.
class _DemoNotice extends StatelessWidget {
  /// Creates the notice from localized copy.
  const _DemoNotice({required this.text});

  final AppLocalizations text;

  @override
  /// Prevents placeholder generation from being mistaken for connected AI.
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2B2113),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.science_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(text.demoModeNotice),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => context.go('/generation'),
                    icon: const Icon(Icons.monitor_heart_outlined),
                    label: Text(text.openGenerationCenter),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Accessible progress panel displayed for the complete generation transaction.
class _GenerationProgress extends StatelessWidget {
  /// Creates progress copy from the current interface localization.
  const _GenerationProgress({required this.text});

  final AppLocalizations text;

  @override
  /// Announces the active operation while preventing duplicate submission.
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      text.generatingTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(text.generatingBody),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
