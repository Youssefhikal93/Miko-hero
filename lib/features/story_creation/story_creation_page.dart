import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/generation_progress_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/gender_selector.dart';
import 'package:miko_hero/shared/hero_face.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_artwork.dart';

/// Tap-first story request form backed by the parent's selected generator.
class StoryCreationPage extends ConsumerWidget {
  /// Creates the routed story-creation destination.
  const StoryCreationPage({super.key});

  @override
  /// Observes persisted state and delegates transient states to one boundary.
  Widget build(BuildContext context, WidgetRef ref) {
    return AppStateBoundary(
      state: ref.watch(appControllerProvider),
      builder: (snapshot) =>
          _StoryForm(profiles: snapshot.profiles, locale: snapshot.locale),
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
  final _heroFieldKey = GlobalKey<FormFieldState<String>>();
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
  /// Lays the request out as four tapped sections above one written action.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final selectedProfile = _profileById(_selectedProfileId);
    final usesLocalAi = ref
        .watch(aiConnectionControllerProvider)
        .value
        ?.usesLocalAi;
    return ScreenLayout(
      maxWidth: 820,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StoryHeader(text: text, usesLocalAi: usesLocalAi),
            const SizedBox(height: 28),
            _sectionTitle(text.whoIsTheHero),
            const SizedBox(height: 10),
            _heroField(text),
            if (selectedProfile != null &&
                !selectedProfile.gender.isSpecified) ...<Widget>[
              const SizedBox(height: 18),
              GenderSelector(
                key: ValueKey<String>(_selectedProfileId!),
                selectedGender: _selectedGender,
                enabled: !_generating && !_savingProfileSelection,
                onSelected: _genderSelected,
              ),
            ],
            const SizedBox(height: 26),
            _sectionTitle(text.whatHappens),
            const SizedBox(height: 10),
            _themeField(text),
            const SizedBox(height: 10),
            _moralField(text),
            const SizedBox(height: 26),
            _sectionTitle(text.howLong),
            const SizedBox(height: 10),
            _lengthField(text),
            const SizedBox(height: 26),
            _sectionTitle(text.lookAndLanguage),
            const SizedBox(height: 10),
            _styleField(text),
            const SizedBox(height: 12),
            _languageField(text),
            if (selectedProfile != null) ...<Widget>[
              const SizedBox(height: 24),
              _SavedPreferencesNotice(profile: selectedProfile),
            ],
            const SizedBox(height: 14),
            _writeButton(text, generatorKnown: usesLocalAi != null),
            if (_generating) ...<Widget>[
              const SizedBox(height: 22),
              const _GenerationProgress(),
            ],
          ],
        ),
      ),
    );
  }

  /// Names one section in the quiet uppercase label the redesign uses.
  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.mutedDeep,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
      ),
    );
  }

  /// Requires the parent to tap the child who will star in this story.
  Widget _heroField(AppLocalizations text) {
    return FormField<String>(
      key: _heroFieldKey,
      initialValue: _selectedProfileId,
      validator: (profileId) =>
          profileId == null ? text.profileSelectionRequired : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final profile in widget.profiles) ...<Widget>[
                  _HeroCard(
                    key: ValueKey<String>('story-hero-${profile.id}'),
                    profile: profile,
                    gender: _cardGender(profile),
                    selected: profile.id == _selectedProfileId,
                    enabled: !_generating && !_savingProfileSelection,
                    onTap: () => _profileSelected(profile.id),
                  ),
                  const SizedBox(width: 10),
                ],
                _AddHeroCard(
                  key: const ValueKey<String>('story-add-hero'),
                  label: text.add,
                  enabled: !_generating,
                ),
              ],
            ),
          ),
          if (field.hasError) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              field.errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  /// Shows a just-made Girl/Boy choice on the card that is missing one.
  ChildGender _cardGender(ChildProfile profile) {
    if (profile.id != _selectedProfileId || _selectedGender == null) {
      return profile.gender;
    }
    return _selectedGender!;
  }

  /// Loads a profile's saved choice and applies its theme when already known.
  void _profileSelected(String profileId) {
    final profile = widget.profiles.firstWhere(
      (candidate) => candidate.id == profileId,
    );
    final selectedGender = profile.gender.isSpecified ? profile.gender : null;
    setState(() {
      _selectedProfileId = profileId;
      _selectedGender = selectedGender;
      _language = profile.storyPreferences.defaultLanguage;
    });
    _heroFieldKey.currentState?.didChange(profileId);
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
    } on Exception catch (error) {
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
      _showError(error);
    } finally {
      if (mounted) setState(() => _savingProfileSelection = false);
    }
  }

  /// Creates the required free-text adventure theme boundary.
  Widget _themeField(AppLocalizations text) {
    return TextFormField(
      key: const ValueKey<String>('story-theme'),
      controller: _themeController,
      enabled: !_generating,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: text.themeHint),
      validator: (theme) =>
          theme == null || theme.trim().isEmpty ? text.themeRequired : null,
    );
  }

  /// Creates the required educational-value input boundary.
  Widget _moralField(AppLocalizations text) {
    return TextFormField(
      key: const ValueKey<String>('story-moral'),
      controller: _moralController,
      enabled: !_generating,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(hintText: text.lessonHint),
      validator: (moral) =>
          moral == null || moral.trim().isEmpty ? text.moralRequired : null,
    );
  }

  /// Offers the three page counts the generator contract already accepts.
  Widget _lengthField(AppLocalizations text) {
    return Row(
      children: StoryLength.values
          .map((length) {
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: length == StoryLength.values.last ? 0 : 10,
                ),
                child: _LengthSegment(
                  key: ValueKey<String>('story-length-${length.name}'),
                  pageCount: length.pageCount,
                  pagesLabel: text.pages,
                  selected: _length == length,
                  enabled: !_generating,
                  onTap: () => setState(() => _length = length),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  /// Offers each illustration direction under the swatch it produces.
  Widget _styleField(AppLocalizations text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: IllustrationStyle.values
          .map((style) {
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: style == IllustrationStyle.values.last ? 0 : 10,
                ),
                child: _StyleCard(
                  key: ValueKey<String>('story-style-${style.name}'),
                  label: _styleName(text, style),
                  swatch: _styleSwatch(style),
                  selected: _style == style,
                  enabled: !_generating,
                  onTap: () => setState(() => _style = style),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  /// Offers every story language written in the script that language reads in.
  Widget _languageField(AppLocalizations text) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppLanguage.values
            .map((language) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  key: ValueKey<String>('story-language-${language.code}'),
                  // Each chip is written in its own script, so the Arabic one
                  // needs the Arabic-capable face whatever the interface uses.
                  label: Text(
                    _storyLanguageName(text, language),
                    style: language.usesLatinScript
                        ? null
                        : TextStyle(
                            fontFamily: interfaceFontFamilyFor(language),
                            fontVariations: const <FontVariation>[],
                          ),
                  ),
                  showCheckmark: false,
                  selected: _language == language,
                  onSelected: _generating
                      ? null
                      : (_) => setState(() => _language = language),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  /// Prevents duplicate generation and waits for the saved generator selection.
  Widget _writeButton(AppLocalizations text, {required bool generatorKnown}) {
    final blocked = _generating || _savingProfileSelection || !generatorKnown;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey<String>('story-submit'),
        onPressed: blocked ? null : _generateStory,
        icon: _generating
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded),
        label: Text(text.writeTheStory),
      ),
    );
  }

  /// Validates the request, persists the generated draft, and opens its review.
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
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _generating = false);
      _showError(error);
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

  /// Resolves an optional card selection without assuming a profile exists.
  ChildProfile? _profileById(String? profileId) {
    if (profileId == null) return null;
    for (final profile in widget.profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  /// Shows recoverable local-write or generation failure feedback.
  void _showError(Object error) {
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(localAiFailureMessage(text, error))),
      );
  }

  /// Names a story language in that language's own script.
  String _storyLanguageName(AppLocalizations text, AppLanguage language) {
    return switch (language) {
      AppLanguage.english => text.storyLanguageEnglish,
      AppLanguage.arabic => text.storyLanguageArabic,
      AppLanguage.swedish => text.storyLanguageSwedish,
      AppLanguage.somali => text.storyLanguageSomali,
    };
  }

  /// Names one illustration direction in the parent's interface language.
  String _styleName(AppLocalizations text, IllustrationStyle style) {
    return switch (style) {
      IllustrationStyle.pictureBook => text.pictureBookStyle,
      IllustrationStyle.watercolor => text.watercolorStyle,
      IllustrationStyle.colorful3d => text.threeDStyle,
    };
  }

  /// Suggests one illustration direction with color alone, never a photo.
  ///
  /// Reads the shared artwork table for the hero chosen so far, so the card a
  /// parent taps carries the colours the finished story will actually wear.
  List<Color> _styleSwatch(IllustrationStyle style) {
    return StoryArtwork.swatchFor(style, _selectedGender);
  }
}

/// Back control, screen name, and generator identity for the request in hand.
class _StoryHeader extends StatelessWidget {
  /// Creates the header above an editable request.
  const _StoryHeader({required this.text, required this.usesLocalAi});

  final AppLocalizations text;
  final bool? usesLocalAi;

  @override
  /// Keeps the title beside the pill naming the generator that will run.
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          onPressed: () => _leave(context),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text.createStoryTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 10),
        _GeneratorPill(text: text, usesLocalAi: usesLocalAi),
      ],
    );
  }

  /// Returns where the parent came from, or home when this was the entry point.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// Compact honest label for the generator this request will actually use.
class _GeneratorPill extends StatelessWidget {
  /// Creates the pill, or a spinner while the saved selection is still loading.
  const _GeneratorPill({required this.text, required this.usesLocalAi});

  final AppLocalizations text;
  final bool? usesLocalAi;

  @override
  /// Never claims Demo before the saved Local AI selection has been read.
  Widget build(BuildContext context) {
    final localAi = usesLocalAi;
    if (localAi == null) {
      return const SizedBox.square(
        dimension: 32,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final notice = localAi ? text.localAiModeNotice : text.demoModeNotice;
    return Tooltip(
      message: notice,
      child: Semantics(
        label: notice,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.candle.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                localAi ? Icons.memory_rounded : Icons.science_outlined,
                size: 16,
                color: AppTheme.candle,
              ),
              const SizedBox(width: 6),
              Text(
                localAi ? text.localAiGeneratorLabel : text.demoGeneratorLabel,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.candleLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One child profile offered as a direct, single-tap hero choice.
class _HeroCard extends StatelessWidget {
  /// Creates a card carrying the child's photo, name, age, and Girl/Boy.
  const _HeroCard({
    required this.profile,
    required this.gender,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final ChildProfile profile;
  final ChildGender gender;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  /// Rings the chosen card in the active accent and keeps the rest quiet.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 100,
          constraints: const BoxConstraints(minHeight: 128),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? accent : AppTheme.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              HeroFace(profile: profile, size: 44),
              const SizedBox(height: 8),
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppTheme.light : AppTheme.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _heroDetail(text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.mutedDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// States the age, and the Girl/Boy context whenever the profile carries one.
  String _heroDetail(AppLocalizations text) {
    if (!gender.isSpecified) return text.yearsOld(profile.age);
    final genderName = gender == ChildGender.girl ? text.girl : text.boy;
    return text.heroAgeGender(profile.age, genderName);
  }
}

/// Direct route into the existing profile creation flow.
class _AddHeroCard extends StatelessWidget {
  /// Creates the card that adds a hero the family has not set up yet.
  const _AddHeroCard({required this.label, required this.enabled, super.key});

  final String label;
  final bool enabled;

  @override
  /// Opens profile creation without inventing a second way to save a child.
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: enabled ? () => context.go('/profiles/new') : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 100,
          constraints: const BoxConstraints(minHeight: 128),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppTheme.mutedDeep,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppTheme.mutedDeep),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One page count in the exact 6/8/10 request contract.
class _LengthSegment extends StatelessWidget {
  /// Creates a segment showing the pages this option produces.
  const _LengthSegment({
    required this.pageCount,
    required this.pagesLabel,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final int pageCount;
  final String pagesLabel;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  /// Prints the number itself, because the count is the whole choice.
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 72,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.12) : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? accent : AppTheme.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                '$pageCount',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: selected ? accent : AppTheme.muted,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              Text(
                pagesLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? accent : AppTheme.mutedDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Illustration-style choice shown as the colors it will draw in.
class _StyleCard extends StatelessWidget {
  /// Creates a style card above its localized name.
  const _StyleCard({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String label;
  final List<Color> swatch;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  /// Shows the swatch first so the choice reads without knowing the words.
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.tile,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? accent : AppTheme.hairline),
          ),
          child: Column(
            children: <Widget>[
              Container(
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: swatch),
                ),
              ),
              SizedBox(
                height: 48,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: selected ? AppTheme.light : AppTheme.muted,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visible confirmation that saved per-child prompt rules are being copied.
class _SavedPreferencesNotice extends StatelessWidget {
  /// Creates the notice for the currently chosen hero.
  const _SavedPreferencesNotice({required this.profile});

  final ChildProfile profile;

  @override
  /// Names the child and counts the safety exclusions this request carries.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Text(
      text.savedPreferencesInUse(
        profile.name,
        profile.storyPreferences.excludedTopics.length,
      ),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppTheme.mutedDeep),
    );
  }
}

/// Accessible progress panel displayed for the complete generation transaction.
class _GenerationProgress extends ConsumerWidget {
  /// Creates the panel shown only while a request is running.
  const _GenerationProgress();

  @override
  /// Announces the paired PC's localized stage as the generation advances.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final progress = ref.watch(generationProgressProvider);
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
                    Text(
                      progress == null
                          ? text.generatingBody
                          : localAiProgressMessage(text, progress),
                    ),
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
