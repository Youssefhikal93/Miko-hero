import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Protects parent-only destinations while preserving the surrounding shell.
class ParentAccessGate extends ConsumerWidget {
  /// Creates a gate around one routed parent destination.
  const ParentAccessGate({required this.child, super.key});

  /// Parent destination rendered when access is open for this session.
  final Widget child;

  @override
  /// Shows setup-free content or a localized PIN unlock panel.
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(parentAccessControllerProvider);
    return access.when(
      data: (value) => !value.isConfigured || value.isUnlocked
          ? child
          : const _ParentUnlockPanel(),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const _ParentAccessError(),
    );
  }
}

/// Requests parent access for a protected action on an otherwise open screen.
Future<bool> requestParentAccess(BuildContext context, WidgetRef ref) async {
  try {
    final access = await ref.read(parentAccessControllerProvider.future);
    if (!access.isConfigured || access.isUnlocked) return true;
    if (!context.mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => const _ParentUnlockDialog(),
        ) ??
        false;
  } on Exception {
    if (!context.mounted) return false;
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    return false;
  }
}

/// Full-page unlock prompt used by parent-only routes.
class _ParentUnlockPanel extends StatelessWidget {
  /// Creates the routed unlock panel.
  const _ParentUnlockPanel();

  @override
  /// Centers the shared PIN form within the available shell content.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.lock_rounded, size: 42),
                  const SizedBox(height: 14),
                  Text(
                    text.parentAreaLocked,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(text.enterParentPin, textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  const _ParentUnlockForm(closeDialogOnSuccess: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal PIN request used before destructive actions such as story deletion.
class _ParentUnlockDialog extends StatelessWidget {
  /// Creates the protected-action dialog.
  const _ParentUnlockDialog();

  @override
  /// Renders a compact unlock form that returns success to its caller.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.parentAreaLocked),
      content: const _ParentUnlockForm(closeDialogOnSuccess: true),
    );
  }
}

/// Stateful PIN input shared by routed and modal parent access prompts.
class _ParentUnlockForm extends ConsumerStatefulWidget {
  /// Creates a form with optional modal completion behavior.
  const _ParentUnlockForm({required this.closeDialogOnSuccess});

  /// Whether successful unlock should return true from the current dialog.
  final bool closeDialogOnSuccess;

  @override
  /// Creates disposable text and busy state for one unlock attempt.
  ConsumerState<_ParentUnlockForm> createState() => _ParentUnlockFormState();
}

/// Owns one PIN field without retaining it after this widget is disposed.
class _ParentUnlockFormState extends ConsumerState<_ParentUnlockForm> {
  final _pinController = TextEditingController();
  bool _isBusy = false;
  String? _errorText;

  @override
  /// Clears the entered PIN when the unlock prompt leaves the widget tree.
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  /// Renders numeric PIN input, validation feedback, and an unlock action.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          controller: _pinController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          decoration: InputDecoration(
            labelText: text.parentPin,
            errorText: _errorText,
          ),
          onSubmitted: (_) => _unlock(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isBusy ? null : _unlock,
            icon: _isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_open_rounded),
            label: Text(text.unlock),
          ),
        ),
      ],
    );
  }

  /// Verifies the entered PIN and updates the panel or modal result.
  Future<void> _unlock() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      final success = await ref
          .read(parentAccessControllerProvider.notifier)
          .unlock(_pinController.text);
      if (!mounted) return;
      if (success && widget.closeDialogOnSuccess) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() {
        _isBusy = false;
        _errorText = success
            ? null
            : AppLocalizations.of(context).incorrectParentPin;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorText = AppLocalizations.of(context).somethingWentWrong;
      });
    }
  }
}

/// Safe error state for a corrupt local parent-verifier record.
class _ParentAccessError extends ConsumerWidget {
  /// Creates the local-security error panel.
  const _ParentAccessError();

  @override
  /// Offers a read-only retry without removing configured protection.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 12),
          Text(text.somethingWentWrong),
          const SizedBox(height: 16),
          FilledButton.tonal(
            onPressed: () => ref.invalidate(parentAccessControllerProvider),
            child: Text(text.retry),
          ),
        ],
      ),
    );
  }
}
