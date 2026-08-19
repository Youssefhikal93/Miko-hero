import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';

/// Supplies PIN hashing and verification without exposing it to widgets.
final parentSecurityServiceProvider = Provider<ParentSecurityService>((ref) {
  return ParentSecurityService();
});

/// Exposes optional parent-PIN setup and this-session access state.
final parentAccessControllerProvider =
    AsyncNotifierProvider<ParentAccessController, ParentAccessState>(
      ParentAccessController.new,
    );

/// Owns local parent-PIN persistence and explicit session locking.
class ParentAccessController extends AsyncNotifier<ParentAccessState> {
  @override
  /// Loads the optional verifier and defaults unconfigured devices to open.
  Future<ParentAccessState> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    final record = await repository.readParentSecurity();
    return ParentAccessState(record: record, isUnlocked: record == null);
  }

  /// Verifies one PIN and unlocks parent controls for this app session.
  Future<bool> unlock(String pin) async {
    final current = state.requireValue;
    final record = current.record;
    if (record == null || current.isUnlocked) return true;
    final service = ref.read(parentSecurityServiceProvider);
    final isValid = await service.verify(pin, record);
    if (isValid) {
      state = AsyncData(ParentAccessState(record: record, isUnlocked: true));
    }
    return isValid;
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
    final current = state.requireValue;
    final record = current.record;
    if (record == null) return;
    state = AsyncData(ParentAccessState(record: record, isUnlocked: false));
  }

  /// Removes the device-local PIN verifier and opens parent controls.
  Future<void> disablePin() async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.removeParentSecurity();
    state = const AsyncData(ParentAccessState(record: null, isUnlocked: true));
  }
}
