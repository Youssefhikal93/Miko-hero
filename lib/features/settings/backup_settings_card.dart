import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/backup/backup_file_service.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/features/settings/backup_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Encrypted portable backup and restore controls for parent settings.
class BackupSettingsCard extends ConsumerStatefulWidget {
  /// Creates the backup card within the parent-protected settings route.
  const BackupSettingsCard({super.key});

  @override
  /// Creates independent busy state for one file transaction at a time.
  ConsumerState<BackupSettingsCard> createState() => _BackupSettingsCardState();
}

/// Coordinates password dialogs and user-visible file actions.
class _BackupSettingsCardState extends ConsumerState<BackupSettingsCard> {
  bool _isBusy = false;

  @override
  /// Explains portability and exposes separate export and restore actions.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_rounded),
              title: Text(text.encryptedBackupTitle),
              subtitle: Text(text.encryptedBackupBody),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: _isBusy ? null : _exportBackup,
                  icon: const Icon(Icons.file_download_rounded),
                  label: Text(text.exportEncryptedBackup),
                ),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _restoreBackup,
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: Text(text.restoreEncryptedBackup),
                ),
                if (_isBusy)
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Encrypts current state, then requires a fresh click to save the file.
  Future<void> _exportBackup() async {
    final text = AppLocalizations.of(context);
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const _BackupPasswordDialog(confirmPassword: true),
    );
    if (password == null || !mounted) return;
    _setBusy(true);
    try {
      final bytes = await ref
          .read(backupControllerProvider)
          .createBackup(password);
      if (!mounted) return;
      _setBusy(false);
      final saved = await _showPreparedBackup(bytes);
      if (saved == true && mounted) _showMessage(text.backupSaved);
    } on Exception catch (error) {
      if (mounted) _showMessage(_backupErrorMessage(text, error));
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  /// Selects, decrypts, previews, and confirms a full local replacement.
  Future<void> _restoreBackup() async {
    final text = AppLocalizations.of(context);
    _setBusy(true);
    try {
      final controller = ref.read(backupControllerProvider);
      final picked = await controller.pickBackup();
      if (picked == null || !mounted) return;
      _setBusy(false);
      final password = await showDialog<String>(
        context: context,
        builder: (context) {
          return _BackupPasswordDialog(
            confirmPassword: false,
            fileName: picked.name,
          );
        },
      );
      if (password == null || !mounted) return;
      _setBusy(true);
      final restored = await controller.decodeBackup(picked.bytes, password);
      if (!mounted) return;
      _setBusy(false);
      final confirmed = await _confirmRestore(restored);
      if (confirmed != true || !mounted) return;
      _setBusy(true);
      await controller.restore(restored);
      if (mounted) _showMessage(text.backupRestored);
    } on Exception catch (error) {
      if (mounted) _showMessage(_backupErrorMessage(text, error));
    } finally {
      if (mounted) _setBusy(false);
    }
  }

  /// Shows the browser-safe explicit save step after encryption finishes.
  Future<bool?> _showPreparedBackup(Uint8List bytes) {
    final text = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.backupReadyTitle),
        content: Text(text.backupReadyBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton.icon(
            onPressed: () async {
              try {
                final saved = await ref
                    .read(backupControllerProvider)
                    .saveBackup(bytes, text.saveBackupDialogTitle);
                if (dialogContext.mounted) dialogContext.pop(saved);
              } on Exception catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(_backupErrorMessage(text, error))),
                );
              }
            },
            icon: const Icon(Icons.download_rounded),
            label: Text(text.downloadBackup),
          ),
        ],
      ),
    );
  }

  /// Summarizes replacement scope without displaying private backup content.
  Future<bool?> _confirmRestore(AppState restored) {
    final text = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(text.confirmRestoreTitle),
        content: Text(
          text.confirmRestoreBody(
            restored.profiles.length,
            restored.stories.length,
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(text.restoreNow),
          ),
        ],
      ),
    );
  }

  /// Updates button availability only while this widget remains mounted.
  void _setBusy(bool value) {
    setState(() => _isBusy = value);
  }

  /// Presents one concise result at the settings screen boundary.
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Disposable password prompt used by export and restore flows.
class _BackupPasswordDialog extends StatefulWidget {
  /// Creates a password prompt with optional confirmation and file context.
  const _BackupPasswordDialog({required this.confirmPassword, this.fileName});

  /// Whether a second matching field is required for a new backup.
  final bool confirmPassword;

  /// Selected encrypted file name shown during restore.
  final String? fileName;

  @override
  /// Creates controllers retained only while the modal is visible.
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

/// Validates password length and optional confirmation before returning it.
class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _errorText;

  @override
  /// Clears password fields as soon as the modal leaves the widget tree.
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  /// Renders export guidance or the selected restore file name.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final fileName = widget.fileName;
    return AlertDialog(
      title: Text(
        widget.confirmPassword
            ? text.createBackupPasswordTitle
            : text.enterBackupPasswordTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            fileName == null
                ? text.backupPasswordRequirements
                : text.restoreFileName(fileName),
          ),
          const SizedBox(height: 16),
          _passwordField(_passwordController, text.backupPassword),
          if (widget.confirmPassword) ...<Widget>[
            const SizedBox(height: 10),
            _passwordField(_confirmationController, text.confirmBackupPassword),
          ],
          if (_errorText != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              _errorText!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(onPressed: () => context.pop(), child: Text(text.cancel)),
        FilledButton(onPressed: _submit, child: Text(text.continueAction)),
      ],
    );
  }

  /// Creates one obscured password field without retaining autofill state.
  Widget _passwordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(labelText: label),
    );
  }

  /// Returns only a sufficiently long, matching password to the caller.
  void _submit() {
    final text = AppLocalizations.of(context);
    final password = _passwordController.text;
    final error = password.length < minimumBackupPasswordLength
        ? text.backupPasswordRequirements
        : widget.confirmPassword && password != _confirmationController.text
        ? text.backupPasswordMismatch
        : null;
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    context.pop(password);
  }
}

/// Maps typed backup failures to safe localized messages.
String _backupErrorMessage(AppLocalizations text, Object error) {
  return switch (error) {
    BackupAuthenticationException() => text.backupWrongPassword,
    BackupFormatException() => text.backupInvalid,
    BackupTooLargeException() => text.backupTooLarge,
    BackupFileReadException() => text.backupFileReadFailed,
    UnsupportedSchemaVersionException() => text.backupNewerVersion,
    _ => text.backupFailed,
  };
}
