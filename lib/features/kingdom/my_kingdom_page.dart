import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/kingdom/kingdom_decorations.dart';
import 'package:miko_hero/features/kingdom/kingdom_style_card.dart';
import 'package:miko_hero/features/kingdom/story_preferences_card.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Family profile hub for switching heroes and personalizing their app colors.
class MyKingdomPage extends ConsumerWidget {
  /// Creates the routed My Kingdom destination.
  const MyKingdomPage({super.key});

  @override
  /// Waits for local family state before exposing profile or theme commands.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _KingdomContent(state: snapshot),
    );
  }
}

/// Loaded My Kingdom content kept independent from asynchronous state plumbing.
class _KingdomContent extends ConsumerWidget {
  /// Creates a profile hub from one immutable application snapshot.
  const _KingdomContent({required this.state});

  final AppState state;

  @override
  /// Keeps profile switching, editing, and color controls in one short flow.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final activeProfile = state.activeProfile;
    return ScreenLayout(
      maxWidth: 900,
      backgroundGradient: activeProfile == null
          ? null
          : kingdomBackdropGradient(activeProfile.kingdomTheme.backdrop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (activeProfile != null) ...<Widget>[
            KingdomCastle(
              style: activeProfile.kingdomTheme.castle,
              color: Color(activeProfile.themeColorValue),
            ),
            const SizedBox(height: 12),
          ],
          SectionHeading(
            title: text.kingdomTitle,
            subtitle: text.kingdomSubtitle,
          ),
          const SizedBox(height: 24),
          if (state.profiles.isEmpty)
            _EmptyKingdom(text: text)
          else ...<Widget>[
            _ProfileChooser(
              profiles: state.profiles,
              activeProfileId: activeProfile?.id,
              onSelected: (profile) => _activateProfile(context, ref, profile),
            ),
            const SizedBox(height: 18),
            if (activeProfile == null)
              _ChooseHeroPrompt(text: text)
            else ...<Widget>[
              _ProfileSummary(profile: activeProfile),
              const SizedBox(height: 18),
              StoryPreferencesCard(profile: activeProfile),
              const SizedBox(height: 18),
              KingdomStyleCard(profile: activeProfile),
              const SizedBox(height: 18),
              _ThemeCard(
                profile: activeProfile,
                onSelected: (color) {
                  _saveThemeColor(context, ref, activeProfile, color);
                },
                onCustomColor: () {
                  _chooseCustomColor(context, ref, activeProfile);
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Persists the active identity before allowing its theme to control the app.
  Future<void> _activateProfile(
    BuildContext context,
    WidgetRef ref,
    ChildProfile profile,
  ) async {
    try {
      await ref.read(profileControllerProvider).activateProfile(profile.id);
    } on Exception {
      if (context.mounted) _showError(context);
    }
  }

  /// Applies one opaque color to only the selected child profile.
  Future<void> _saveThemeColor(
    BuildContext context,
    WidgetRef ref,
    ChildProfile profile,
    Color color,
  ) async {
    final text = AppLocalizations.of(context);
    try {
      await ref
          .read(profileControllerProvider)
          .setThemeColor(profile.id, color.toARGB32());
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.profileThemeSaved(profile.name))),
      );
    } on Exception {
      if (context.mounted) _showError(context);
    }
  }

  /// Opens the local picker and saves only a color explicitly confirmed by the parent.
  Future<void> _chooseCustomColor(
    BuildContext context,
    WidgetRef ref,
    ChildProfile profile,
  ) async {
    final selectedColor = await showDialog<Color>(
      context: context,
      builder: (context) {
        return _CustomColorPickerDialog(
          initialColor: Color(profile.themeColorValue),
        );
      },
    );
    if (selectedColor == null || !context.mounted) return;
    await _saveThemeColor(context, ref, profile, selectedColor);
  }

  /// Presents a recoverable storage error without exposing private profile data.
  void _showError(BuildContext context) {
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
  }
}

/// Empty state that routes directly to the existing private profile editor.
class _EmptyKingdom extends StatelessWidget {
  /// Creates setup guidance from the current interface localization.
  const _EmptyKingdom({required this.text});

  final AppLocalizations text;

  @override
  /// Keeps the new destination useful before the first child has been added.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            const Icon(Icons.castle_rounded, size: 54),
            const SizedBox(height: 14),
            Text(
              text.noProfilesTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(text.noProfilesBody, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go('/profiles/new'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(text.addProfile),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profile choices that immediately restore each child's saved application color.
class _ProfileChooser extends StatelessWidget {
  /// Creates choices in the same stable order used by local persistence.
  const _ProfileChooser({
    required this.profiles,
    required this.activeProfileId,
    required this.onSelected,
  });

  final List<ChildProfile> profiles;
  final String? activeProfileId;
  final ValueChanged<ChildProfile> onSelected;

  @override
  /// Uses real local profile photos so similarly named heroes remain distinct.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.activeHero,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: profiles
                  .map((profile) {
                    return ChoiceChip(
                      key: ValueKey<String>('kingdom-profile-${profile.id}'),
                      selected: profile.id == activeProfileId,
                      onSelected: (_) => onSelected(profile),
                      avatar: KingdomAvatar(
                        photoBase64: profile.photoBase64,
                        frame: profile.kingdomTheme.frame,
                        color: Color(profile.themeColorValue),
                        radius: 12,
                      ),
                      label: Text(profile.heroName),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guidance shown only when migrated profiles have no active identity yet.
class _ChooseHeroPrompt extends StatelessWidget {
  /// Creates a localized prompt with no automatic profile assumption.
  const _ChooseHeroPrompt({required this.text});

  final AppLocalizations text;

  @override
  /// Requires an explicit parent choice before exposing profile-specific settings.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: <Widget>[
            const Icon(Icons.touch_app_rounded),
            const SizedBox(width: 14),
            Expanded(child: Text(text.chooseHero)),
          ],
        ),
      ),
    );
  }
}

/// Active child summary with explicit paths for name editing and profile creation.
class _ProfileSummary extends StatelessWidget {
  /// Creates a summary from one validated local child profile.
  const _ProfileSummary({required this.profile});

  final ChildProfile profile;

  @override
  /// Keeps name changes in the existing validated editor rather than duplicating forms.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            KingdomAvatar(
              photoBase64: profile.photoBase64,
              frame: profile.kingdomTheme.frame,
              color: Color(profile.themeColorValue),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        kingdomSymbolIcon(profile.kingdomTheme.symbol),
                        color: Color(profile.themeColorValue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile.heroName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(text.yearsOld(profile.age)),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: () => context.go('/profiles/${profile.id}'),
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(text.editHeroProfile),
                      ),
                      TextButton.icon(
                        onPressed: () => context.go('/profiles/new'),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(text.addAnotherHero),
                      ),
                    ],
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

/// Preset palettes and a custom picker scoped to the active child profile.
class _ThemeCard extends StatelessWidget {
  /// Creates theme controls for one active child.
  const _ThemeCard({
    required this.profile,
    required this.onSelected,
    required this.onCustomColor,
  });

  final ChildProfile profile;
  final ValueChanged<Color> onSelected;
  final VoidCallback onCustomColor;

  @override
  /// Marks the stored ARGB value while allowing an unlimited custom alternative.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final selectedValue = profile.themeColorValue;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.themeColor,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(text.themeColorHint(profile.name)),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _paletteChoices(text)
                  .map((choice) {
                    return ChoiceChip(
                      key: ValueKey<String>('theme-${choice.color.toARGB32()}'),
                      selected: choice.color.toARGB32() == selectedValue,
                      onSelected: (_) => onSelected(choice.color),
                      avatar: _ColorDot(color: choice.color),
                      label: Text(choice.label),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onCustomColor,
              icon: const Icon(Icons.palette_rounded),
              label: Text(text.customColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Localizes labels without duplicating the actual palette color values.
  List<_PaletteChoice> _paletteChoices(AppLocalizations text) {
    return <_PaletteChoice>[
      _PaletteChoice(label: text.goldenTheme, color: AppTheme.amber),
      _PaletteChoice(label: text.roseTheme, color: AppTheme.girlPink),
      _PaletteChoice(label: text.purpleTheme, color: AppTheme.purple),
      _PaletteChoice(label: text.cyanTheme, color: AppTheme.boyCyan),
      _PaletteChoice(label: text.greenTheme, color: AppTheme.green),
    ];
  }
}

/// One localized label and opaque preset color offered by My Kingdom.
class _PaletteChoice {
  /// Groups the translated name with the exact color persisted on selection.
  const _PaletteChoice({required this.label, required this.color});

  final String label;
  final Color color;
}

/// Small color preview used inside preset choice chips.
class _ColorDot extends StatelessWidget {
  /// Creates a circular preview from one opaque palette color.
  const _ColorDot({required this.color});

  final Color color;

  @override
  /// Preserves the true selected color independently from the current app theme.
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: const SizedBox.square(dimension: 22),
    );
  }
}

/// Local HSV picker that never sends a child's color choice off the device.
class _CustomColorPickerDialog extends StatefulWidget {
  /// Seeds the picker from the active child's currently persisted color.
  const _CustomColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  /// Creates an isolated edit buffer until the parent confirms the dialog.
  State<_CustomColorPickerDialog> createState() {
    return _CustomColorPickerDialogState();
  }
}

/// Mutable hue, intensity, and brightness buffer for one custom color choice.
class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late HSVColor _selectedColor;

  @override
  /// Converts the saved opaque color into editable HSV controls.
  void initState() {
    super.initState();
    _selectedColor = HSVColor.fromColor(widget.initialColor);
  }

  @override
  /// Returns a color only from the explicit confirmation action.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.customColorTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _colorPreview(),
            const SizedBox(height: 18),
            _hueControl(text),
            _intensityControl(text),
            _brightnessControl(text),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_selectedColor.toColor()),
          child: Text(text.applyColor),
        ),
      ],
    );
  }

  /// Shows the exact opaque color that will be stored after confirmation.
  Widget _colorPreview() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: 84,
      decoration: BoxDecoration(
        color: _selectedColor.toColor(),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  /// Adjusts the full color wheel without changing intensity or brightness.
  Widget _hueControl(AppLocalizations text) {
    return _sliderLabel(
      text.hue,
      Slider(
        value: _selectedColor.hue,
        min: 0,
        max: 360,
        activeColor: _selectedColor.toColor(),
        onChanged: (hue) {
          setState(() => _selectedColor = _selectedColor.withHue(hue));
        },
      ),
    );
  }

  /// Adjusts color intensity while retaining the selected hue and brightness.
  Widget _intensityControl(AppLocalizations text) {
    return _sliderLabel(
      text.intensity,
      Slider(
        value: _selectedColor.saturation,
        activeColor: _selectedColor.toColor(),
        onChanged: (saturation) {
          setState(() {
            _selectedColor = _selectedColor.withSaturation(saturation);
          });
        },
      ),
    );
  }

  /// Restricts brightness above near-black so controls retain visible accents.
  Widget _brightnessControl(AppLocalizations text) {
    return _sliderLabel(
      text.brightness,
      Slider(
        value: _selectedColor.value.clamp(0.25, 1),
        min: 0.25,
        activeColor: _selectedColor.toColor(),
        onChanged: (brightness) {
          setState(() => _selectedColor = _selectedColor.withValue(brightness));
        },
      ),
    );
  }

  /// Keeps every control label visible above its platform-native slider.
  Widget _sliderLabel(String label, Widget slider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        slider,
      ],
    );
  }
}
