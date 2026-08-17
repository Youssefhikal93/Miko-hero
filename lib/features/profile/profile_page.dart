import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/daughter_profile.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Private one-child profile editor with local photo handling.
class ProfilePage extends ConsumerWidget {
  /// Creates the full-screen profile route.
  const ProfilePage({super.key});

  @override
  /// Waits for persisted state before initializing editable form fields.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).profileTitle)),
      body: AppStateBoundary(
        state: state,
        builder: (snapshot) => _ProfileForm(initialProfile: snapshot.profile),
      ),
    );
  }
}

/// Stateful form that owns temporary text and picked-image values.
class _ProfileForm extends ConsumerStatefulWidget {
  /// Creates an editor for a new or previously saved profile.
  const _ProfileForm({required this.initialProfile});

  final DaughterProfile? initialProfile;

  @override
  /// Creates isolated form state so cancelled edits never reach persistence.
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

/// Mutable edit buffer for the single private profile.
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
              decoration: InputDecoration(labelText: text.daughterName),
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

  /// Persists validated fields and returns home after the write completes.
  Future<void> _saveProfile() async {
    final text = AppLocalizations.of(context);
    final photoBase64 = _photoBase64;
    if (!_formKey.currentState!.validate() || photoBase64 == null) {
      if (photoBase64 == null) _showMessage(text.photoRequired);
      return;
    }
    setState(() => _saving = true);
    final profile = DaughterProfile(
      name: _nameController.text.trim(),
      age: int.parse(_ageController.text),
      photoBase64: photoBase64,
    );
    try {
      await ref.read(appControllerProvider.notifier).saveProfile(profile);
      if (!mounted) return;
      _showMessage(text.profileSaved);
      context.go('/');
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
