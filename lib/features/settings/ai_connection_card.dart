import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/settings/library_sync_section.dart';
import 'package:miko_hero/features/settings/paired_devices_section.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';

/// Parent-only controls for the generator mode, the PC bridge, and pairing.
///
/// Lives behind the parent gate on the settings route: no child-facing screen
/// shows an address, a pairing code, or the paired state.
class AiConnectionCard extends ConsumerWidget {
  /// Creates the AI connection card inside the protected settings route.
  const AiConnectionCard({super.key});

  @override
  /// Renders the stored connection once local settings are readable.
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(aiConnectionControllerProvider);
    return connection.when(
      data: (value) => _LoadedAiConnectionCard(connection: value),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => _AiConnectionErrorCard(
        onRetry: () => ref.invalidate(aiConnectionControllerProvider),
      ),
    );
  }
}

/// Loaded generator mode, bridge address, health probe, and pairing controls.
class _LoadedAiConnectionCard extends ConsumerStatefulWidget {
  /// Creates the card from one immutable connection snapshot.
  const _LoadedAiConnectionCard({required this.connection});

  final AiConnectionState connection;

  @override
  /// Keeps the address field and the last health result out of storage.
  ConsumerState<_LoadedAiConnectionCard> createState() {
    return _LoadedAiConnectionCardState();
  }
}

/// Holds the editable address and the most recent connection test result.
class _LoadedAiConnectionCardState
    extends ConsumerState<_LoadedAiConnectionCard> {
  late final TextEditingController _addressController;
  BridgeHealth? _health;
  String? _message;
  bool _isBusy = false;

  @override
  /// Starts the address field from the value stored on this device.
  void initState() {
    super.initState();
    _addressController = TextEditingController(
      text: widget.connection.settings.baseUrl.toString(),
    );
  }

  @override
  /// Releases the address field when the settings screen goes away.
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  /// Groups the generator choice, the address, the probe, and pairing.
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
              leading: const Icon(AppIcons.bridge),
              title: Text(text.aiConnectionTitle),
              subtitle: Text(text.aiConnectionBody),
            ),
            Text(
              text.aiConnectionParentNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 18),
            _modeField(text),
            const SizedBox(height: 18),
            _addressField(text),
            const SizedBox(height: 12),
            _actions(text),
            if (_health != null) ...<Widget>[
              const SizedBox(height: 12),
              _healthReport(text, _health!),
            ],
            if (_message != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _message!,
                key: const ValueKey<String>('ai-connection-message'),
              ),
            ],
            const Divider(height: 32),
            _pairingSection(text),
            // Only a paired device may ask the PC who else is paired, so an
            // unpaired one is not shown an empty list it cannot fill.
            if (widget.connection.isPaired) ...<Widget>[
              const Divider(height: 32),
              const PairedDevicesSection(),
            ],
            const Divider(height: 32),
            const LibrarySyncSection(),
          ],
        ),
      ),
    );
  }

  /// Lets the parent choose the demo sample or the AI on the family PC.
  Widget _modeField(AppLocalizations text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          text.storyGeneratorMode,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<StoryGeneratorMode>(
          key: const ValueKey<String>('story-generator-mode'),
          segments: <ButtonSegment<StoryGeneratorMode>>[
            ButtonSegment<StoryGeneratorMode>(
              value: StoryGeneratorMode.demo,
              icon: const Icon(AppIcons.demo),
              label: Text(text.demoGeneratorMode),
            ),
            ButtonSegment<StoryGeneratorMode>(
              value: StoryGeneratorMode.localAi,
              icon: const Icon(AppIcons.localAi),
              label: Text(text.localAiGeneratorMode),
            ),
          ],
          selected: <StoryGeneratorMode>{widget.connection.settings.mode},
          onSelectionChanged: _isBusy
              ? null
              : (selection) => unawaited(_setMode(selection.first)),
        ),
      ],
    );
  }

  /// Collects the bridge origin the parent's PC listens on.
  Widget _addressField(AppLocalizations text) {
    return TextField(
      controller: _addressController,
      enabled: !_isBusy,
      keyboardType: TextInputType.url,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: text.bridgeAddress,
        hintText: text.bridgeAddressHint,
      ),
    );
  }

  /// Offers saving the address and probing the three PC dependencies.
  Widget _actions(AppLocalizations text) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        FilledButton.tonalIcon(
          onPressed: _isBusy ? null : () => unawaited(_saveAddress()),
          icon: const Icon(AppIcons.save),
          label: Text(text.saveBridgeAddress),
        ),
        OutlinedButton.icon(
          onPressed: _isBusy ? null : () => unawaited(_testConnection()),
          icon: _isBusy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(AppIcons.testConnection),
          label: Text(text.testBridgeConnection),
        ),
      ],
    );
  }

  /// Reports the three probed statuses in the interface language.
  Widget _healthReport(AppLocalizations text, BridgeHealth health) {
    return Column(
      children: <Widget>[
        _statusRow(text, text.ollamaStatus, health.isOllamaAvailable),
        _statusRow(text, text.comfyUiStatus, health.isComfyUiAvailable),
        _statusRow(text, text.bridgeLibraryStatus, health.isLibraryAvailable),
      ],
    );
  }

  /// Shows one dependency with its state available as text, not only color.
  Widget _statusRow(AppLocalizations text, String title, bool isAvailable) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isAvailable ? AppIcons.bridgeAvailable : AppIcons.bridgeUnavailable,
        color: isAvailable ? Colors.greenAccent : Colors.orangeAccent,
      ),
      title: Text(title),
      trailing: Text(
        isAvailable ? text.bridgeStatusReady : text.bridgeStatusUnavailable,
      ),
    );
  }

  /// Shows the paired state and the pairing or forgetting command.
  Widget _pairingSection(AppLocalizations text) {
    final deviceName = widget.connection.pairedDeviceName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          deviceName == null
              ? text.deviceNotPaired
              : text.devicePairedAs(deviceName),
        ),
        const SizedBox(height: 12),
        if (deviceName == null)
          FilledButton.icon(
            onPressed: _isBusy ? null : () => unawaited(_pairDevice()),
            icon: const Icon(AppIcons.pair),
            label: Text(text.pairWithPc),
          )
        else
          OutlinedButton.icon(
            onPressed: _isBusy ? null : () => unawaited(_forgetDevice()),
            icon: const Icon(AppIcons.forgetDevice),
            label: Text(text.forgetPairedDevice),
          ),
      ],
    );
  }

  /// Persists the generator choice and reports the switch to the parent.
  Future<void> _setMode(StoryGeneratorMode mode) async {
    final text = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await ref.read(aiConnectionControllerProvider.notifier).setMode(mode);
      if (mounted) _showSnackBar(text.storyGeneratorModeSaved);
    } on Exception {
      if (mounted) setState(() => _message = text.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Validates and persists the typed bridge address.
  Future<void> _saveAddress() async {
    final text = AppLocalizations.of(context);
    if (parseBridgeBaseUrl(_addressController.text) == null) {
      setState(() => _message = text.bridgeAddressInvalid);
      return;
    }
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await ref
          .read(aiConnectionControllerProvider.notifier)
          .setBaseUrl(_addressController.text);
      if (mounted) {
        setState(() => _health = null);
        _showSnackBar(text.bridgeAddressSaved);
      }
    } on Exception {
      if (mounted) setState(() => _message = text.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Probes the bridge and reports its dependencies or a typed failure.
  Future<void> _testConnection() async {
    final text = AppLocalizations.of(context);
    setState(() {
      _isBusy = true;
      _message = null;
      _health = null;
    });
    try {
      final health = await ref
          .read(aiConnectionControllerProvider.notifier)
          .readHealth();
      if (!mounted) return;
      setState(() {
        _health = health;
        _message = text.bridgeReachable(health.version);
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _message = localAiFailureMessage(text, error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Runs the human-in-the-loop pairing ceremony in a modal.
  Future<void> _pairDevice() async {
    final paired = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PairingDialog(),
    );
    if (paired != true || !mounted) return;
    setState(() => _message = null);
    _showSnackBar(AppLocalizations.of(context).devicePaired);
  }

  /// Confirms before deleting the stored token from this device.
  Future<void> _forgetDevice() async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.forgetPairedDeviceTitle),
        content: Text(text.forgetPairedDeviceBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(text.forgetPairedDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _isBusy = true;
      _message = null;
    });
    try {
      await ref.read(aiConnectionControllerProvider.notifier).forgetDevice();
      if (mounted) _showSnackBar(text.pairedDeviceForgotten);
    } on Exception {
      if (mounted) setState(() => _message = text.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Shows one short confirmation without repeating it inside the card.
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Pairing modal: request a code on the PC, then confirm it from this device.
class _PairingDialog extends ConsumerStatefulWidget {
  /// Creates a non-dismissible pairing transaction.
  const _PairingDialog();

  @override
  /// Keeps the pending pairing identity and both fields inside the modal.
  ConsumerState<_PairingDialog> createState() => _PairingDialogState();
}

/// Holds the pending pairing identity and the parent's typed values.
class _PairingDialogState extends ConsumerState<_PairingDialog> {
  final _codeController = TextEditingController();
  final _deviceNameController = TextEditingController();
  String? _pairingId;
  String? _errorText;
  bool _isBusy = false;

  @override
  /// Asks the PC for a code as soon as the parent opens the modal.
  void initState() {
    super.initState();
    unawaited(_requestPairing());
  }

  @override
  /// Clears the typed code and device name with the modal.
  void dispose() {
    _codeController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  @override
  /// Shows the code entry only once the PC has a pending pairing.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(text.pairDeviceTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(text.pairDeviceBody),
          if (_pairingId != null) ...<Widget>[
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: bridgePairingCodeLength,
              decoration: InputDecoration(
                labelText: text.pairingCode,
                counterText: '',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _deviceNameController,
              maxLength: maximumPairedDeviceNameLength,
              decoration: InputDecoration(
                labelText: text.pairedDeviceNameLabel,
                hintText: text.pairedDeviceNameHint,
                counterText: '',
              ),
            ),
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
        TextButton(
          onPressed: _isBusy ? null : () => context.pop(false),
          child: Text(text.cancel),
        ),
        if (_pairingId == null)
          FilledButton(
            onPressed: _isBusy ? null : () => unawaited(_requestPairing()),
            child: Text(text.retry),
          )
        else
          FilledButton(
            key: const ValueKey<String>('confirm-pairing'),
            onPressed: _isBusy ? null : () => unawaited(_confirmPairing()),
            child: Text(text.confirmPairing),
          ),
      ],
    );
  }

  /// Starts a pairing so the 6-digit code appears on the PC console.
  Future<void> _requestPairing() async {
    setState(() {
      _isBusy = true;
      _errorText = null;
    });
    try {
      final pairingId = await ref
          .read(aiConnectionControllerProvider.notifier)
          .startPairing();
      if (!mounted) return;
      setState(() => _pairingId = pairingId);
    } on Exception catch (error) {
      if (!mounted) return;
      final text = AppLocalizations.of(context);
      setState(() => _errorText = localAiFailureMessage(text, error));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Confirms the typed code and stores the token the PC issues once.
  Future<void> _confirmPairing() async {
    final text = AppLocalizations.of(context);
    final code = _codeController.text;
    final deviceName = _deviceNameController.text;
    final error = !isValidBridgePairingCode(code)
        ? text.pairingCodeInvalid
        : !isValidPairedDeviceName(deviceName)
        ? text.pairedDeviceNameInvalid(maximumPairedDeviceNameLength)
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
      await ref
          .read(aiConnectionControllerProvider.notifier)
          .confirmPairing(
            pairingId: _pairingId!,
            code: code,
            deviceName: deviceName,
          );
      if (mounted) context.pop(true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _errorText = localAiFailureMessage(text, error);
        _codeController.clear();
      });
    }
  }
}

/// Retry surface used only when the stored connection cannot be read.
class _AiConnectionErrorCard extends StatelessWidget {
  /// Creates an error card with a non-destructive reload action.
  const _AiConnectionErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  /// Leaves malformed stored settings untouched and offers a retry.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(AppIcons.error),
        title: Text(text.somethingWentWrong),
        trailing: TextButton(onPressed: onRetry, child: Text(text.retry)),
      ),
    );
  }
}
