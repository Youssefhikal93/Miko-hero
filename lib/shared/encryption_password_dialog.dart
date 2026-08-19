import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/backup/encrypted_backup_codec.dart';

/// Localized wording for one encryption password prompt.
///
/// Passed in rather than read inside the dialog so a backup file and a single
/// story file can each name themselves correctly in every language.
class EncryptionPasswordCopy {
  /// Groups every localized string one password prompt needs.
  const EncryptionPasswordCopy({
    required this.title,
    required this.passwordLabel,
    required this.confirmLabel,
    required this.requirements,
    required this.mismatch,
    required this.cancel,
    required this.confirmAction,
  });

  /// Dialog title describing which file the password protects.
  final String title;

  /// Label of the password field.
  final String passwordLabel;

  /// Label of the confirmation field, used only when confirming a new password.
  final String confirmLabel;

  /// Explanation of the minimum length and that the password is unrecoverable.
  final String requirements;

  /// Message shown when the two entered passwords differ.
  final String mismatch;

  /// Label of the dismissing action.
  final String cancel;

  /// Label of the submitting action.
  final String confirmAction;
}

/// Collects one password for an encrypted local file, or null when dismissed.
///
/// The entered secret exists only inside the dialog's controllers and is
/// discarded with them; nothing about it is persisted.
Future<String?> showEncryptionPasswordDialog(
  BuildContext context, {
  required EncryptionPasswordCopy copy,
  required bool confirmPassword,
  String? fileContext,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => EncryptionPasswordDialog(
      copy: copy,
      confirmPassword: confirmPassword,
      fileContext: fileContext,
    ),
  );
}

/// Disposable password prompt shared by backup and story-file flows.
class EncryptionPasswordDialog extends StatefulWidget {
  /// Creates a prompt with optional confirmation and selected-file context.
  const EncryptionPasswordDialog({
    required this.copy,
    required this.confirmPassword,
    this.fileContext,
    super.key,
  });

  /// Localized wording describing the protected file.
  final EncryptionPasswordCopy copy;

  /// Whether a second matching field is required for a new file.
  final bool confirmPassword;

  /// Sentence naming the selected file, shown instead of the requirements.
  final String? fileContext;

  @override
  /// Creates controllers retained only while the modal is visible.
  State<EncryptionPasswordDialog> createState() {
    return _EncryptionPasswordDialogState();
  }
}

/// Validates password length and optional confirmation before returning it.
class _EncryptionPasswordDialogState extends State<EncryptionPasswordDialog> {
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
  /// Renders creation guidance or the selected file's name.
  Widget build(BuildContext context) {
    final copy = widget.copy;
    return AlertDialog(
      title: Text(copy.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(widget.fileContext ?? copy.requirements),
          const SizedBox(height: 16),
          _passwordField(_passwordController, copy.passwordLabel),
          if (widget.confirmPassword) ...<Widget>[
            const SizedBox(height: 10),
            _passwordField(_confirmationController, copy.confirmLabel),
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
        TextButton(onPressed: () => context.pop(), child: Text(copy.cancel)),
        FilledButton(onPressed: _submit, child: Text(copy.confirmAction)),
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
    final copy = widget.copy;
    final password = _passwordController.text;
    final error = password.length < minimumBackupPasswordLength
        ? copy.requirements
        : widget.confirmPassword && password != _confirmationController.text
        ? copy.mismatch
        : null;
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    context.pop(password);
  }
}
