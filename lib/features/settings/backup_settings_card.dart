import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/features/settings/backup_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/encrypted_file_messages.dart';
import 'package:miko_hero/shared/encryption_password_dialog.dart';

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
    final password = await showEncryptionPasswordDialog(
      context,
      copy: _passwordCopy(text, text.createBackupPasswordTitle),
      confirmPassword: true,
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
      if (mounted) _showMessage(backupFileMessage(text, error));
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
      final restored = await controller.openBackup(
        askPassword: (fileName) async {
          if (!mounted) return null;
          // The parent is reading a dialog, not waiting on this device.
          _setBusy(false);
          final password = await showEncryptionPasswordDialog(
            context,
            copy: _passwordCopy(text, text.enterBackupPasswordTitle),
            confirmPassword: false,
            fileContext: text.restoreFileName(fileName),
          );
          if (password != null && mounted) _setBusy(true);
          return password;
        },
      );
      if (restored == null || !mounted) return;
      _setBusy(false);
      final confirmed = await _confirmRestore(restored);
      if (confirmed != true || !mounted) return;
      _setBusy(true);
      await controller.restore(restored);
      if (mounted) _showMessage(text.backupRestored);
    } on Exception catch (error) {
      if (mounted) _showMessage(backupFileMessage(text, error));
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
                  SnackBar(content: Text(backupFileMessage(text, error))),
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

/// Builds the backup wording for the shared encryption password prompt.
EncryptionPasswordCopy _passwordCopy(AppLocalizations text, String title) {
  return EncryptionPasswordCopy(
    title: title,
    passwordLabel: text.backupPassword,
    confirmLabel: text.confirmBackupPassword,
    requirements: text.backupPasswordRequirements,
    mismatch: text.backupPasswordMismatch,
    cancel: text.cancel,
    confirmAction: text.continueAction,
  );
}
