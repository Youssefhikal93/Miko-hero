import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Optional local parent-PIN status and management controls.
class ParentSecuritySettingsCard extends ConsumerWidget {
  /// Creates the security card within the already protected settings route.
  const ParentSecuritySettingsCard({super.key});

  @override
  /// Renders actions appropriate to configured or open local access.
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(parentAccessControllerProvider);
    return access.when(
      data: (value) => _LoadedSecurityCard(access: value),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => _SecurityErrorCard(
        onRetry: () => ref.invalidate(parentAccessControllerProvider),
      ),
    );
  }
}

/// Loaded PIN status with setup, lock, and removal commands.
class _LoadedSecurityCard extends ConsumerWidget {
  /// Creates controls from the current parent-access snapshot.
  const _LoadedSecurityCard({required this.access});

  final ParentAccessState access;

  @override
  /// Keeps security actions together without mixing backup responsibilities.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: Text(text.parentSecurityTitle),
              subtitle: Text(text.parentSecurityBody),
            ),
            Text(
              access.isConfigured
                  ? text.parentPinConfigured
                  : text.parentPinNotConfigured,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: access.isConfigured
                  ? _configuredActions(context, ref, text)
                  : <Widget>[
                      FilledButton.icon(
                        onPressed: () => _setPin(context, ref),
                        icon: const Icon(Icons.pin_rounded),
                        label: Text(text.setParentPin),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }

  /// Builds actions that are meaningful only after PIN setup.
  List<Widget> _configuredActions(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations text,
  ) {
    return <Widget>[
      FilledButton.tonalIcon(
        onPressed: () => _setPin(context, ref),
        icon: const Icon(Icons.password_rounded),
        label: Text(text.changeParentPin),
      ),
      OutlinedButton.icon(
        onPressed: () {
          ref.read(parentAccessControllerProvider.notifier).lock();
        },
        icon: const Icon(Icons.lock_rounded),
        label: Text(text.lockParentArea),
      ),
      TextButton.icon(
        onPressed: () => _removePin(context, ref),
        icon: const Icon(Icons.lock_open_rounded),
        label: Text(text.removeParentPin),
      ),
    ];
  }

  /// Collects matching PIN fields before persisting a one-way verifier.
  Future<void> _setPin(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PinSetupDialog(),
    );
    if (saved != true || !context.mounted) return;
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.parentPinSaved)));
  }

  /// Requires confirmation before removing the device-local access barrier.
  Future<void> _removePin(BuildContext context, WidgetRef ref) async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.removeParentPinTitle),
        content: Text(text.removeParentPinBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(text.removeParentPin),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(parentAccessControllerProvider.notifier).disablePin();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.parentPinRemoved)));
    } on Exception {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
    }
  }
}

/// PIN setup dialog with local validation and disposable secret fields.
class _PinSetupDialog extends ConsumerStatefulWidget {
  /// Creates a non-dismissible PIN setup transaction.
  const _PinSetupDialog();

  @override
  /// Creates field controllers retained only while the dialog is visible.
  ConsumerState<_PinSetupDialog> createState() => _PinSetupDialogState();
}

/// Validates matching numeric PIN fields before calling the controller.
class _PinSetupDialogState extends ConsumerState<_PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  String? _errorText;
  bool _isBusy = false;

  @override
  /// Clears both PIN fields when setup completes or is cancelled.
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  /// Renders matching obscured PIN inputs and a single save action.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.setParentPin),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(text.parentPinRequirements),
          const SizedBox(height: 16),
          _pinField(_pinController, text.newParentPin, autofocus: true),
          const SizedBox(height: 10),
          _pinField(_confirmationController, text.confirmParentPin),
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
        TextButton(
          onPressed: _isBusy ? null : () => context.pop(false),
          child: Text(text.cancel),
        ),
        FilledButton(
          onPressed: _isBusy ? null : _save,
          child: Text(text.saveParentPin),
        ),
      ],
    );
  }

  /// Creates one constrained numeric secret field.
  Widget _pinField(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 8,
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }

  /// Validates and persists the new verifier before closing successfully.
  Future<void> _save() async {
    final text = AppLocalizations.of(context);
    final pin = _pinController.text;
    final service = ref.read(parentSecurityServiceProvider);
    final error = !service.isValidPin(pin)
        ? text.parentPinRequirements
        : pin != _confirmationController.text
        ? text.parentPinMismatch
        : null;
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      await ref.read(parentAccessControllerProvider.notifier).setPin(pin);
      if (mounted) context.pop(true);
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorText = text.somethingWentWrong;
      });
    }
  }
}

/// Retry surface used only when the local verifier cannot be read.
class _SecurityErrorCard extends StatelessWidget {
  /// Creates an error card with a caller-provided reload action.
  const _SecurityErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  /// Avoids offering destructive reset when the security record is malformed.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.error_outline_rounded),
        title: Text(text.somethingWentWrong),
        trailing: TextButton(onPressed: onRetry, child: Text(text.retry)),
      ),
    );
  }
}
