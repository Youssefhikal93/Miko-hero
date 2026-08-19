import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';

/// Supplies PIN hashing and verification without exposing it to widgets.
final parentSecurityServiceProvider = Provider<ParentSecurityService>((ref) {
  return ParentSecurityService();
});

/// Supplies the clock used for PIN attempt throttling.
final parentSecurityClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Exposes optional parent-PIN setup and this-session access state.
final parentAccessControllerProvider =
    AsyncNotifierProvider<ParentAccessController, ParentAccessState>(
      ParentAccessController.new,
    );

/// Owns local parent-PIN persistence, attempt throttling, and session locking.
class ParentAccessController extends AsyncNotifier<ParentAccessState> {
  _ParentLifecycleObserver? _lifecycleObserver;

  @override
  /// Loads the optional verifier and defaults unconfigured devices to open.
  Future<ParentAccessState> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    final record = await repository.readParentSecurity();
    _observeAppLifecycle();
    return ParentAccessState(record: record, isUnlocked: record == null);
  }

  /// Verifies one PIN and unlocks parent controls for this app session.
  ///
  /// Refuses input during a cooldown, counts every wrong PIN, and clears the
  /// attempt history as soon as the correct PIN arrives.
  Future<ParentUnlockResult> unlock(String pin) async {
    final current = state.requireValue;
    if (!current.isConfigured || current.isUnlocked) {
      return const ParentUnlockResult.unlocked();
    }
    return _attempt(pin, unlockSession: true);
  }

  /// Verifies the current PIN for re-authentication without changing access.
  ///
  /// Used by Change PIN; wrong attempts throttle exactly like unlocking.
  Future<ParentUnlockResult> verifyPin(String pin) async {
    final current = state.requireValue;
    if (!current.isConfigured) return const ParentUnlockResult.unlocked();
    return _attempt(pin, unlockSession: false);
  }

  /// Hashes and persists a new PIN, leaving this session unlocked.
  Future<void> setPin(String pin) async {
    final service = ref.read(parentSecurityServiceProvider);
    final record = await service.createRecord(pin);
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveParentSecurity(record);
    state = AsyncData(ParentAccessState(record: record, isUnlocked: true));
  }

  /// Locks configured parent controls until the correct PIN is entered.
  void lock() {
    final current = state.value;
    final record = current?.record;
    if (current == null || record == null || !current.isUnlocked) return;
    state = AsyncData(ParentAccessState(record: record, isUnlocked: false));
  }

  /// Removes the device-local PIN verifier and opens parent controls.
  Future<void> disablePin() async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.removeParentSecurity();
    state = const AsyncData(ParentAccessState(record: null, isUnlocked: true));
  }

  /// Applies the throttling policy around one Argon2id verification.
  Future<ParentUnlockResult> _attempt(
    String pin, {
    required bool unlockSession,
  }) async {
    final current = state.requireValue;
    final record = current.record!;
    final now = ref.read(parentSecurityClockProvider)();
    final waiting = record.remainingCooldown(now);
    if (waiting > Duration.zero) return ParentUnlockResult.cooldown(waiting);
    final service = ref.read(parentSecurityServiceProvider);
    final isValid = await service.verify(pin, record);
    final savedRecord = isValid
        ? record.withoutFailedAttempts()
        : record.withFailedAttempt(now);
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveParentSecurity(savedRecord);
    state = AsyncData(
      ParentAccessState(
        record: savedRecord,
        isUnlocked: isValid
            ? unlockSession || current.isUnlocked
            : current.isUnlocked,
      ),
    );
    if (isValid) return const ParentUnlockResult.unlocked();
    final cooldown = savedRecord.remainingCooldown(now);
    return cooldown > Duration.zero
        ? ParentUnlockResult.cooldown(cooldown)
        : const ParentUnlockResult.incorrectPin();
  }

  /// Re-locks a configured PIN whenever the app leaves the foreground.
  ///
  /// Registered once per controller instance and removed with the provider so
  /// a backgrounded phone never hands parent controls to the next person.
  void _observeAppLifecycle() {
    if (_lifecycleObserver != null) return;
    final observer = _ParentLifecycleObserver(lock);
    _lifecycleObserver = observer;
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(observer);
      _lifecycleObserver = null;
    });
  }
}

/// Lifecycle listener that reports only backgrounding to the controller.
class _ParentLifecycleObserver extends WidgetsBindingObserver {
  /// Creates an observer that calls [_onBackground] when the app is hidden.
  _ParentLifecycleObserver(this._onBackground);

  final VoidCallback _onBackground;

  @override
  /// Treats paused and hidden as leaving the foreground; ignores resume.
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _onBackground();
    }
  }
}
