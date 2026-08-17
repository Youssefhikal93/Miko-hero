import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
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
      appBar: AppBar(title: Text(text.profilesTitle)),
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
        subtitle: Text(text.yearsOld(profile.age)),
        trailing: IconButton(
          tooltip: text.editProfile,
          onPressed: () => context.go('/profiles/${profile.id}'),
          icon: const Icon(Icons.edit_rounded),
        ),
        onTap: () => context.go('/profiles/${profile.id}'),
      ),
    );
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
        return Scaffold(
          appBar: AppBar(
            title: Text(
              profile == null
                  ? AppLocalizations.of(context).addProfile
                  : profile.heroName,
            ),
          ),
          body: _ProfileForm(
            key: ValueKey<String>(profile?.id ?? 'new-profile'),
            initialProfile: profile,
          ),
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
  late final TextEditingController _ageController;
  String? _photoBase64;
  bool _saving = false;

  @override
  /// Seeds the edit buffer from local state without mutating the model.
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile?.name);
    _ageController = TextEditingController(
      text: widget.initialProfile?.age.toString(),
    );
    _photoBase64 = widget.initialProfile?.photoBase64;
  }

  @override
  /// Releases controllers when the profile route leaves the navigation stack.
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
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
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: text.age),
              validator: _validateAge,
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

  /// Restricts age to the supported child reading range of 1 through 17.
  String? _validateAge(String? ageText) {
    final age = int.tryParse(ageText ?? '');
    if (age == null || age < 1 || age > 17) {
      return AppLocalizations.of(context).ageInvalid;
    }
    return null;
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
    if (!_formKey.currentState!.validate() || photoBase64 == null) {
      if (photoBase64 == null) _showMessage(text.photoRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(appControllerProvider.notifier)
          .saveProfile(
            profileId: widget.initialProfile?.id,
            name: _nameController.text.trim(),
            age: int.parse(_ageController.text),
            photoBase64: photoBase64,
          );
      if (!mounted) return;
      _showMessage(text.profileSaved);
      context.go('/profiles');
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
            _preview(),
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
  Widget _preview() {
    final encodedPhoto = photoBase64;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox.square(
        dimension: 112,
        child: encodedPhoto == null
            ? const ColoredBox(
                color: Color(0xFF222635),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  size: 36,
                  color: AppTheme.amber,
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
    return Scaffold(
      body: Center(
        child: FilledButton.tonal(
          onPressed: () => context.go('/profiles'),
          child: Text(AppLocalizations.of(context).somethingWentWrong),
        ),
      ),
    );
  }
}
