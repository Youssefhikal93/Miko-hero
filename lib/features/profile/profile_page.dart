import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/profile/hero_sheet_controller.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/empty_state.dart';
import 'package:miko_hero/shared/gender_selector.dart';
import 'package:miko_hero/shared/hero_face.dart';
import 'package:miko_hero/shared/parent_gated_action.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Local profile manager for every child who can star in a story.
class ProfilePage extends ConsumerWidget {
  /// Creates the routed profile-list destination.
  const ProfilePage({super.key});

  @override
  /// Shows persisted profiles only after local storage has loaded.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final text = AppLocalizations.of(context);
    return Scaffold(
      body: AppStateBoundary(
        state: state,
        builder: (snapshot) => _ProfileList(profiles: snapshot.profiles),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/profiles/new'),
        icon: const Icon(AppIcons.addHero),
        label: Text(text.addProfile),
      ),
    );
  }
}

/// Loaded profile collection independent from asynchronous state plumbing.
class _ProfileList extends StatelessWidget {
  /// Creates a profile list in its persisted display order.
  const _ProfileList({required this.profiles});

  final List<ChildProfile> profiles;

  @override
  /// Renders an actionable empty state or one private card per child.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.profilesTitle,
            subtitle: text.profilesSubtitle,
          ),
          const SizedBox(height: 22),
          if (profiles.isEmpty)
            _NoProfiles(text: text)
          else
            ...profiles.map((profile) => _ProfileCard(profile: profile)),
          const SizedBox(height: 84),
        ],
      ),
    );
  }
}

/// One child summary with a direct route to edit local details and photo.
class _ProfileCard extends StatelessWidget {
  /// Creates a card from a validated local profile.
  const _ProfileCard({required this.profile});

  final ChildProfile profile;

  @override
  /// Keeps the personalized hero label visible beside private profile details.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: HeroFace(profile: profile, size: 64),
        title: Text(
          profile.heroName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('${text.yearsOld(profile.age)} · ${_genderName(text)}'),
        trailing: IconButton(
          tooltip: text.editProfile,
          onPressed: () => context.go('/profiles/${profile.id}'),
          icon: const Icon(AppIcons.editHero),
        ),
        onTap: () => context.go('/profiles/${profile.id}'),
      ),
    );
  }

  /// Localizes a saved choice while exposing profiles awaiting migration input.
  String _genderName(AppLocalizations text) {
    return switch (profile.gender) {
      ChildGender.unspecified => text.genderNotSet,
      ChildGender.girl => text.girl,
      ChildGender.boy => text.boy,
    };
  }
}

/// Empty profile collection with a clear first action.
class _NoProfiles extends StatelessWidget {
  /// Creates localized setup guidance.
  const _NoProfiles({required this.text});

  final AppLocalizations text;

  @override
  /// Explains why at least one profile is needed before story creation.
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.heroFamily,
      title: text.noProfilesTitle,
      body: text.noProfilesBody,
      action: FilledButton.icon(
        onPressed: () => context.go('/profiles/new'),
        icon: const Icon(AppIcons.addHero),
        label: Text(text.addProfile),
      ),
    );
  }
}

/// Editor route for a new child or one existing profile identity.
class ProfileEditorPage extends ConsumerWidget {
  /// Creates an add form when [profileId] is absent, otherwise an edit form.
  const ProfileEditorPage({this.profileId, super.key});

  /// Existing local identity to edit, or null when adding a child.
  final String? profileId;

  @override
  /// Resolves edit identities from current state before seeding form controls.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) {
        final profile = profileId == null
            ? null
            : snapshot.profileById(profileId!);
        if (profileId != null && profile == null) {
          return const _MissingProfile();
        }
        return _ProfileForm(
          key: ValueKey<String>(profile?.id ?? 'new-profile'),
          initialProfile: profile,
        );
      },
    );
  }
}

/// Stateful form that owns temporary text and picked-image values.
class _ProfileForm extends ConsumerStatefulWidget {
  /// Creates an editor for a new or previously saved child profile.
  const _ProfileForm({required this.initialProfile, super.key});

  final ChildProfile? initialProfile;

  @override
  /// Creates isolated form state so cancelled edits never reach persistence.
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

/// Mutable edit buffer for one private child profile.
class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _outfitController = TextEditingController();
  final _propController = TextEditingController();
  late final TextEditingController _nameController;
  String? _photoBase64;
  DateTime? _birthDate;
  ChildGender? _gender;
  bool _birthDateMissing = false;
  bool _saving = false;

  /// How the PC draws this child's hero, once it has answered.
  ///
  /// Never persisted on this device: it is read live from the PC every time the
  /// editor opens, because a description of one child's face has no business
  /// sitting in a phone's preferences waiting to be backed up.
  BridgeHeroSheet? _heroSheet;

  /// Whether the PC has answered at all yet.
  ///
  /// The gate on sending the wardrobe back: two empty text fields mean "the
  /// parent cleared this hero's coat" only if the PC's answer is what put them
  /// there. Before that they mean nothing has loaded, and saving them would
  /// undress a hero the parent never looked at.
  bool _heroSheetLoaded = false;
  bool _heroSheetLoading = false;

  @override
  /// Seeds the edit buffer from local state without mutating the model.
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile?.name);
    _photoBase64 = widget.initialProfile?.photoBase64;
    _birthDate = widget.initialProfile?.birthDate;
    final storedGender = widget.initialProfile?.gender;
    _gender = storedGender?.isSpecified == true ? storedGender : null;
    _loadHeroSheet();
  }

  @override
  /// Releases controllers when the profile route leaves the navigation stack.
  void dispose() {
    _nameController.dispose();
    _outfitController.dispose();
    _propController.dispose();
    super.dispose();
  }

  @override
  /// Renders fields and photo actions inside a narrow, readable layout.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      maxWidth: 760,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SectionHeading(
              title: widget.initialProfile?.heroName ?? text.addProfile,
            ),
            const SizedBox(height: 12),
            Text(
              text.profileIntro,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            _PhotoEditor(
              photoBase64: _photoBase64,
              onPick: _pickPhoto,
              onRemove: _removePhoto,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: text.childName),
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            _BirthDateField(
              birthDate: _birthDate,
              legacyAge: _legacyAge,
              enabled: !_saving,
              showRequiredError: _birthDateMissing,
              onPick: _pickBirthDate,
            ),
            const SizedBox(height: 20),
            GenderSelector(
              selectedGender: _gender,
              enabled: !_saving,
              onSelected: (gender) => setState(() => _gender = gender),
            ),
            if (_photoBase64 == null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                text.photoRequired,
                style: const TextStyle(color: AppTheme.danger),
              ),
            ],
            if (_showsHeroSheet) ...<Widget>[
              const SizedBox(height: 24),
              _HeroSheetSection(
                sheet: _heroSheet,
                isLoading: _heroSheetLoading,
                enabled: !_saving,
                outfitController: _outfitController,
                propController: _propController,
                onReadAgain: _rereadHeroSheet,
              ),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.lock),
                label: Text(text.saveProfile),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Whether this editor may show how the PC draws this child's hero.
  ///
  /// Only for a child the PC already knows by id, and only while this device
  /// holds a pairing token: an unpaired device has no PC to ask, and a child
  /// being added has no id on the PC to ask about yet.
  bool get _showsHeroSheet {
    if (widget.initialProfile == null) return false;
    final connection = ref.watch(aiConnectionControllerProvider).value;
    return connection?.isPaired ?? false;
  }

  /// Reads the hero sheet from the PC, once, when the editor opens.
  ///
  /// An unpaired device never reaches the network: the controller answers null
  /// before a request is built. A PC that cannot be reached leaves the section
  /// empty and says so once, because the profile itself is still perfectly
  /// editable without it.
  Future<void> _loadHeroSheet() async {
    final profileId = widget.initialProfile?.id;
    if (profileId == null) return;
    setState(() => _heroSheetLoading = true);
    try {
      final sheet = await ref
          .read(heroSheetControllerProvider)
          .readSheet(profileId);
      if (!mounted) return;
      setState(() {
        _heroSheet = sheet;
        _heroSheetLoaded = true;
        _heroSheetLoading = false;
        _outfitController.text = sheet?.outfit ?? '';
        _propController.text = sheet?.prop ?? '';
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _heroSheetLoading = false);
      _showMessage(AppLocalizations.of(context).heroSheetUnavailable);
    }
  }

  /// Asks the PC to read the child's photo again, behind the parent gate.
  ///
  /// The PC accepts the request rather than promising it is finished — the
  /// re-read waits for its turn at the one graphics card — so an answer that
  /// carries the same sheet back is reported as "still coming", not as a
  /// failure and not as a change that did not happen.
  Future<void> _rereadHeroSheet() async {
    final profileId = widget.initialProfile?.id;
    if (profileId == null) return;
    final previous = _heroSheet;
    await runParentGatedAction<bool, BridgeHeroSheet?>(
      context,
      ref,
      confirm: (context) async => true,
      run: (context, _) async {
        final sheet = await ref
            .read(heroSheetControllerProvider)
            .rereadFromPhoto(profileId);
        if (mounted) _showHeroSheet(sheet);
        return sheet;
      },
      report: (text, sheet) =>
          sheet == null || sheet.updatedAtUtc == previous?.updatedAtUtc
          ? text.heroSheetRereadPending
          : text.heroSheetRereadDone,
      onFailure: (text, failure) => text.heroSheetRereadFailed,
    );
  }

  /// Shows one freshly answered sheet, wardrobe fields included.
  void _showHeroSheet(BridgeHeroSheet? sheet) {
    setState(() {
      _heroSheet = sheet;
      _heroSheetLoaded = true;
      _outfitController.text = sheet?.outfit ?? '';
      _propController.text = sheet?.prop ?? '';
    });
  }

  /// Sends the wardrobe to the PC, reporting whether it got there.
  ///
  /// Skipped entirely when the PC never answered, and when neither field was
  /// touched: the sheet is the PC's row, and rewriting it unchanged would move
  /// its timestamp for nothing.
  Future<bool> _saveHeroSheet() async {
    final profileId = widget.initialProfile?.id;
    final outfit = _outfitController.text.trim();
    final prop = _propController.text.trim();
    if (profileId == null || !_heroSheetLoaded) return true;
    if (outfit == (_heroSheet?.outfit ?? '') &&
        prop == (_heroSheet?.prop ?? '')) {
      return true;
    }
    try {
      await ref
          .read(heroSheetControllerProvider)
          .saveWardrobe(profileId: profileId, outfit: outfit, prop: prop);
      return true;
    } on Exception {
      return false;
    }
  }

  /// Rejects blank names at the user-input boundary.
  String? _validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return AppLocalizations.of(context).nameRequired;
    }
    return null;
  }

  /// Age stored before birth dates existed, kept valid until a date is picked.
  int? get _legacyAge {
    final profile = widget.initialProfile;
    return profile == null || profile.birthDate != null
        ? null
        : profile.legacyAge;
  }

  /// Opens a localized calendar bounded to the supported child reading range.
  ///
  /// A legacy profile opens at roughly today minus its stored age so the
  /// parent only has to correct the day and month.
  Future<void> _pickBirthDate() async {
    final today = childCalendarDay(DateTime.now());
    final earliest = DateTime(
      today.year - maximumChildAge - 1,
      today.month,
      today.day,
    ).add(const Duration(days: 1));
    final latest = DateTime(
      today.year - minimumChildAge,
      today.month,
      today.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: _initialPickerDate(today, earliest, latest),
      firstDate: earliest,
      lastDate: latest,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthDate = childCalendarDay(picked);
      _birthDateMissing = false;
    });
  }

  /// Positions the calendar on the saved date, the legacy age, or a default.
  DateTime _initialPickerDate(
    DateTime today,
    DateTime earliest,
    DateTime latest,
  ) {
    final selected = _birthDate;
    if (selected != null && !selected.isBefore(earliest)) {
      return selected.isAfter(latest) ? latest : selected;
    }
    final years = _legacyAge ?? defaultChildProfileAgeYears;
    final approximate = DateTime(today.year - years, today.month, today.day);
    if (approximate.isBefore(earliest)) return earliest;
    return approximate.isAfter(latest) ? latest : approximate;
  }

  /// Reads a gallery image, enforces the local limit, and keeps it unsaved.
  Future<void> _pickPhoto() async {
    final text = AppLocalizations.of(context);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (bytes.length > maximumReferencePhotoBytes) {
        _showMessage(text.photoTooLarge);
        return;
      }
      setState(() => _photoBase64 = base64Encode(bytes));
    } on Exception {
      _showMessage(text.photoReadFailed);
    }
  }

  /// Removes only the unsaved photo buffer until the parent confirms save.
  void _removePhoto() {
    setState(() => _photoBase64 = null);
  }

  /// Persists validated fields and returns to the complete profile list.
  Future<void> _saveProfile() async {
    final text = AppLocalizations.of(context);
    final photoBase64 = _photoBase64;
    final gender = _gender;
    final birthDate = _birthDate;
    final age = birthDate == null
        ? _legacyAge
        : childAgeOn(birthDate, DateTime.now());
    if (!_formKey.currentState!.validate() ||
        photoBase64 == null ||
        gender == null ||
        age == null) {
      setState(() => _birthDateMissing = age == null);
      if (photoBase64 == null) _showMessage(text.photoRequired);
      if (age == null) _showMessage(text.birthDateRequired);
      return;
    }
    if (!isValidChildAge(age)) {
      _showMessage(text.ageInvalid);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(profileControllerProvider)
          .saveProfile(
            profileId: widget.initialProfile?.id,
            draft: ChildProfileDraft(
              name: _nameController.text.trim(),
              birthDate: birthDate,
              photoBase64: photoBase64,
              gender: gender,
            ),
          );
      // The PC's half of the save, and only its own failure is reported: the
      // child is already stored on this device by now, so a PC that did not
      // answer must not read as a profile that was not saved.
      final heroSheetSaved = await _saveHeroSheet();
      if (!mounted) return;
      _showMessage(
        heroSheetSaved ? text.profileSaved : text.heroSheetSaveFailed,
      );
      context.go('/kingdom');
    } on Exception {
      if (!mounted) return;
      setState(() => _saving = false);
      _showMessage(text.somethingWentWrong);
    }
  }

  /// Presents recoverable form feedback without exposing storage details.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Birth-date control that replaces the previously stored, stale age field.
class _BirthDateField extends StatelessWidget {
  /// Creates a picker row from the current unsaved edit buffer.
  const _BirthDateField({
    required this.birthDate,
    required this.legacyAge,
    required this.enabled,
    required this.showRequiredError,
    required this.onPick,
  });

  final DateTime? birthDate;
  final int? legacyAge;
  final bool enabled;
  final bool showRequiredError;
  final VoidCallback onPick;

  @override
  /// Shows the chosen day, or the legacy age that stays valid until it changes.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final selected = birthDate;
    final age = legacyAge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        InputDecorator(
          decoration: InputDecoration(
            labelText: text.birthDate,
            helperText: selected == null && age != null
                ? text.birthDateLegacyAge(age)
                : text.birthDateHelper,
            errorText: showRequiredError ? text.birthDateRequired : null,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  selected == null
                      ? text.chooseBirthDate
                      : MaterialLocalizations.of(
                          context,
                        ).formatFullDate(selected),
                ),
              ),
              TextButton.icon(
                onPressed: enabled ? onPick : null,
                icon: const Icon(AppIcons.birthDate),
                label: Text(
                  selected == null
                      ? text.chooseBirthDate
                      : text.changeBirthDate,
                ),
              ),
            ],
          ),
        ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(text.yearsOld(childAgeOn(selected, DateTime.now()))),
        ],
      ],
    );
  }
}

/// How the PC draws this child's hero: its half read-only, the parent's typed.
///
/// The split is the point of the whole section. Hair, skin and eyes are what
/// the PC read off the reference photo, so they are shown and not offered for
/// editing — the only honest way to change them is to have the photo read
/// again. The outfit and the prop were never in the photo at all, so they are
/// the parent's to write.
class _HeroSheetSection extends StatelessWidget {
  /// Creates the section from the sheet the PC last answered with.
  const _HeroSheetSection({
    required this.sheet,
    required this.isLoading,
    required this.enabled,
    required this.outfitController,
    required this.propController,
    required this.onReadAgain,
  });

  final BridgeHeroSheet? sheet;
  final bool isLoading;
  final bool enabled;
  final TextEditingController outfitController;
  final TextEditingController propController;
  final Future<void> Function() onReadAgain;

  @override
  /// Shows the derived look, the wardrobe fields, and the re-read action.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final look = sheet;
    return Card(
      key: const ValueKey<String>('hero-sheet-section'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              text.heroSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              text.heroSheetIntro,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const LinearProgressIndicator()
            else if (look != null && look.isDerived) ...<Widget>[
              Text(
                text.heroSheetReadFromPhoto,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              _DerivedTrait(label: text.heroSheetHair, value: look.hair),
              _DerivedTrait(
                label: text.heroSheetSkinTone,
                value: look.skinTone,
              ),
              _DerivedTrait(
                label: text.heroSheetEyeColor,
                value: look.eyeColor,
              ),
            ] else
              Text(text.heroSheetNotReadYet),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey<String>('hero-sheet-read-again'),
                onPressed: enabled ? onReadAgain : null,
                icon: const Icon(AppIcons.refresh),
                label: Text(text.heroSheetReadAgain),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey<String>('hero-sheet-outfit'),
              controller: outfitController,
              enabled: enabled,
              maxLength: maximumHeroSheetFieldLength,
              decoration: InputDecoration(
                labelText: text.heroSheetOutfit,
                helperText: text.heroSheetWardrobeHelper,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const ValueKey<String>('hero-sheet-prop'),
              controller: propController,
              enabled: enabled,
              maxLength: maximumHeroSheetFieldLength,
              decoration: InputDecoration(labelText: text.heroSheetProp),
            ),
          ],
        ),
      ),
    );
  }
}

/// One trait the PC read from the photo, shown as text and never as a field.
class _DerivedTrait extends StatelessWidget {
  /// Creates one labelled read-only row.
  const _DerivedTrait({required this.label, required this.value});

  final String label;
  final String value;

  @override
  /// Keeps the label and the value on one readable line.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// Photo preview and replacement actions kept separate from form validation.
class _PhotoEditor extends StatelessWidget {
  /// Creates a photo control from the current unsaved edit buffer.
  const _PhotoEditor({
    required this.photoBase64,
    required this.onPick,
    required this.onRemove,
  });

  final String? photoBase64;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  /// Shows private bytes only in memory and never resolves a public URL.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: <Widget>[
            _preview(context),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text.referencePhoto,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.tonalIcon(
                        onPressed: onPick,
                        icon: const Icon(AppIcons.photoLibrary),
                        label: Text(
                          photoBase64 == null
                              ? text.choosePhoto
                              : text.replacePhoto,
                        ),
                      ),
                      if (photoBase64 != null)
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(AppIcons.delete),
                          label: Text(text.removePhoto),
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

  /// Decodes the selected local image or displays a neutral private placeholder.
  Widget _preview(BuildContext context) {
    final encodedPhoto = photoBase64;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox.square(
        dimension: 112,
        child: encodedPhoto == null
            ? ColoredBox(
                color: AppTheme.mediaWell,
                child: Icon(
                  AppIcons.addPhoto,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Image.memory(base64Decode(encodedPhoto), fit: BoxFit.cover),
      ),
    );
  }
}

/// Recovery view for a profile URL that no longer resolves locally.
class _MissingProfile extends StatelessWidget {
  /// Creates the profile-list recovery destination.
  const _MissingProfile();

  @override
  /// Returns the parent to profiles without exposing the unresolved identity.
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.tonal(
        onPressed: () => context.go('/kingdom'),
        child: Text(AppLocalizations.of(context).somethingWentWrong),
      ),
    );
  }
}
