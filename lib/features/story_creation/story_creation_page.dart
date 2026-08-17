import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/daughter_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Guided story request form backed by the explicit local demo generator.
class StoryCreationPage extends ConsumerWidget {
  /// Creates the routed story-creation destination.
  const StoryCreationPage({super.key});

  @override
  /// Blocks generation until persisted profile state is available.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) {
        final profile = snapshot.profile;
        if (profile == null) return const _ProfileRequired();
        return _StoryForm(profile: profile, locale: snapshot.locale);
      },
    );
  }
}

/// Direct recovery path when story creation is opened before profile setup.
class _ProfileRequired extends StatelessWidget {
  /// Creates a blocking state with one route back to profile setup.
  const _ProfileRequired();

  @override
  /// Explains the requirement and routes directly to the private profile form.
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
                onPressed: () => context.go('/profile'),
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
  /// Creates a form using the private profile and current interface locale.
  const _StoryForm({required this.profile, required this.locale});

  final DaughterProfile profile;
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
  late AppLanguage _language;
  StoryLength _length = StoryLength.short;
  IllustrationStyle _style = IllustrationStyle.pictureBook;
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
            _DemoNotice(text: text),
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

  /// Builds the language selector from the four supported story contracts.
  Widget _languageField(AppLocalizations text) {
    return DropdownButtonFormField<AppLanguage>(
      initialValue: _language,
      decoration: InputDecoration(labelText: text.storyLanguage),
      items: AppLanguage.values.map((language) {
        return DropdownMenuItem<AppLanguage>(
          value: language,
          child: Text(_languageName(text, language)),
        );
      }).toList(),
      onChanged: _generating
          ? null
          : (language) => setState(() => _language = language!),
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
        onPressed: _generating ? null : _generateStory,
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
    setState(() => _generating = true);
    final request = _storyRequest();
    try {
      final story = await ref
          .read(appControllerProvider.notifier)
          .createStory(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).storyCreated)),
      );
      context.go('/story/${story.id}');
    } on Exception {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).somethingWentWrong),
        ),
      );
    }
  }

  /// Captures one immutable request from the already-validated edit buffer.
  StoryRequest _storyRequest() {
    return StoryRequest(
      heroName: widget.profile.name,
      theme: _themeController.text.trim(),
      moral: _moralController.text.trim(),
      presentation: StoryPresentation(
        language: _language,
        length: _length,
        style: _style,
      ),
    );
  }

  /// Returns the translated display name for a supported language.
  String _languageName(AppLocalizations text, AppLanguage language) {
    return switch (language) {
      AppLanguage.english => text.english,
      AppLanguage.arabic => text.arabic,
      AppLanguage.swedish => text.swedish,
      AppLanguage.somali => text.somali,
    };
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
            const Icon(Icons.science_outlined, color: AppTheme.amber),
            const SizedBox(width: 12),
            Expanded(child: Text(text.demoModeNotice)),
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
