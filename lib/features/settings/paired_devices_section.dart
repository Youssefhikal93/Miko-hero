import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/local_ai_messages.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

/// The devices the PC trusts, listed inside the parent-gated AI connection
/// card.
///
/// A family accumulates devices — a tablet that broke, a cousin's phone from
/// one visit — and until now the only way to see or remove one was to sit at
/// the PC. The list is read from the PC every time the card opens, because a
/// device removed on another phone must not linger here as if it still had
/// access.
class PairedDevicesSection extends ConsumerStatefulWidget {
  /// Creates the paired-device block of the AI connection card.
  const PairedDevicesSection({super.key});

  @override
  /// Keeps the loaded list and the last failure out of storage.
  ConsumerState<PairedDevicesSection> createState() {
    return _PairedDevicesSectionState();
  }
}

/// Holds the devices read from the PC and the outcome of the last read.
class _PairedDevicesSectionState extends ConsumerState<PairedDevicesSection> {
  List<BridgePairedDevice>? _devices;
  Object? _failure;
  bool _isLoading = true;
  bool _isRemoving = false;

  @override
  /// Reads the list from the PC as soon as the parent opens the card.
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  /// Renders the list, the failure of the last read, or a loading indicator.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          text.pairedDevicesTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Text(text.pairedDevicesBody),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_failure != null)
          _failureReport(text, _failure!)
        else
          ..._deviceRows(text),
      ],
    );
  }

  /// Reports why the PC could not be asked, and offers the read again.
  Widget _failureReport(AppLocalizations text, Object failure) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            localAiFailureMessage(text, failure),
            key: const ValueKey<String>('paired-devices-failure'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(
          key: const ValueKey<String>('paired-devices-retry'),
          onPressed: () => unawaited(_load()),
          child: Text(text.retry),
        ),
      ],
    );
  }

  /// One row per trusted device, or a sentence when the PC trusts none.
  List<Widget> _deviceRows(AppLocalizations text) {
    final devices = _devices ?? const <BridgePairedDevice>[];
    if (devices.isEmpty) {
      return <Widget>[
        Text(
          text.pairedDevicesEmpty,
          key: const ValueKey<String>('paired-devices-empty'),
        ),
      ];
    }
    return devices
        .map((device) => _deviceRow(text, device))
        .toList(growable: false);
  }

  /// Names one device, when it was paired, and when the PC last heard it.
  Widget _deviceRow(AppLocalizations text, BridgePairedDevice device) {
    final lastSeenAtUtc = device.lastSeenAtUtc;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      key: ValueKey<String>('paired-device-${device.id}'),
      leading: Icon(
        device.isCaller ? AppIcons.thisDevice : AppIcons.pairedDevice,
      ),
      title: Text(
        device.isCaller
            ? text.pairedDeviceThisDevice(device.name)
            : device.name,
      ),
      subtitle: Text(
        '${text.pairedDeviceSince(_moment(device.pairedAtUtc))}\n'
        '${lastSeenAtUtc == null ? text.pairedDeviceNeverSeen : text.pairedDeviceLastSeen(_moment(lastSeenAtUtc))}',
      ),
      isThreeLine: true,
      // This device is deliberately not removable from here: the PC refuses
      // it, and forgetting this device is the command right above.
      trailing: device.isCaller
          ? null
          : IconButton(
              key: ValueKey<String>('remove-paired-device-${device.id}'),
              tooltip: text.removePairedDevice,
              onPressed: _isRemoving
                  ? null
                  : () => unawaited(_removeDevice(device)),
              icon: const Icon(AppIcons.removeDevice),
            ),
    );
  }

  /// Formats one UTC moment in the interface language and the local zone.
  String _moment(DateTime utcMoment) {
    return DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_jm().format(utcMoment.toLocal());
  }

  /// Reads the PC's device list, replacing whatever was shown before.
  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _failure = null;
    });
    try {
      final devices = await ref
          .read(aiConnectionControllerProvider.notifier)
          .readPairedDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = error;
        _isLoading = false;
      });
    }
  }

  /// Confirms by name behind the parent gate, then removes on the PC.
  Future<void> _removeDevice(BridgePairedDevice device) async {
    final hasAccess = await requestParentAccess(context, ref);
    if (!hasAccess || !mounted) return;
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.removePairedDeviceTitle(device.name)),
        content: Text(text.removePairedDeviceBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            key: const ValueKey<String>('confirm-remove-paired-device'),
            onPressed: () => context.pop(true),
            child: Text(text.removePairedDevice),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isRemoving = true);
    try {
      await ref
          .read(aiConnectionControllerProvider.notifier)
          .removePairedDevice(device.id);
      _report(messenger, text.pairedDeviceRemoved(device.name));
    } on Exception catch (error) {
      _report(messenger, localAiFailureMessage(text, error));
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
    // The PC is the truth about who still has access, so the list is read
    // again rather than edited locally to match what was just asked for.
    await _load();
  }

  /// Shows one short outcome without leaving the settings screen.
  void _report(ScaffoldMessengerState messenger, String message) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
