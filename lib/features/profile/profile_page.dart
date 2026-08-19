import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/features/profile/profile_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/gender_selector.dart';
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
        icon: const Icon(Icons.person_add_alt_1_rounded),
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
        leading: CircleAvatar(
          radius: 32,
          backgroundImage: MemoryImage(base64Decode(profile.photoBase64)),
        ),
        title: Text(
          profile.heroName,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text('${text.yearsOld(profile.age)} · ${_genderName(text)}'),
        trailing: IconButton(
          tooltip: text.editProfile,
          onPressed: () => context.go('/profiles/${profile.id}'),
          icon: const Icon(Icons.edit_rounded),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: <Widget>[
            const Icon(Icons.groups_2_outlined, size: 52),
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
  late final TextEditingController _nameController;
  String? _photoBase64;
  DateTime? _birthDate;
  ChildGender? _gender;
  bool _birthDateMissing = false;
  bool _saving = false;

  @override
  /// Seeds the edit buffer from local state without mutating the model.
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile?.name);
    _photoBase64 = widget.initialProfile?.photoBase64;
    _birthDate = widget.initialProfile?.birthDate;
    final storedGender = widget.initialProfile?.gender;
    _gender = storedGender?.isSpecified == true ? storedGender : null;
  }

  @override
  /// Releases controllers when the profile route leaves the navigation stack.
  void dispose() {
    _nameController.dispose();
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
                style: const TextStyle(color: Colors.redAccent),
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
                    : const Icon(Icons.lock_rounded),
                label: Text(text.saveProfile),
              ),
            ),
          ],
        ),
      ),
    );
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
      if (!mounted) return;
      _showMessage(text.profileSaved);
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
                icon: const Icon(Icons.event_rounded),
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
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          photoBase64 == null
                              ? text.choosePhoto
                              : text.replacePhoto,
                        ),
                      ),
                      if (photoBase64 != null)
                        TextButton.icon(
                          onPressed: onRemove,
                          icon: const Icon(Icons.delete_outline),
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
                color: Color(0xFF222635),
                child: Icon(
                  Icons.add_a_photo_outlined,
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
