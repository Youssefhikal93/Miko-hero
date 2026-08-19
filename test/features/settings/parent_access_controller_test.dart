import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/security/parent_security_service.dart';
import 'package:miko_hero/features/settings/parent_access_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies PIN throttling against real preference-backed persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const correctPin = '4729';
  const wrongPin = '1111';

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('five wrong PINs refuse the next attempt for thirty seconds', () async {
    final clock = _AdjustableClock(DateTime.utc(2026, 8, 19, 20));
    final container = _lockedContainer(clock);
    final controller = await _configuredController(container, correctPin);

    for (var attempt = 1; attempt < parentPinFreeAttempts; attempt++) {
      final result = await controller.unlock(wrongPin);
      expect(result.outcome, ParentUnlockOutcome.incorrectPin);
    }
    final throttling = await controller.unlock(wrongPin);
    final refused = await controller.unlock(correctPin);

    expect(throttling.outcome, ParentUnlockOutcome.cooldown);
    expect(throttling.remainingCooldown, const Duration(seconds: 30));
    expect(refused.outcome, ParentUnlockOutcome.cooldown);
    expect(
      container.read(parentAccessControllerProvider).value?.isUnlocked,
      isFalse,
    );
  });

  test(
    'each further wrong PIN escalates the wait up to five minutes',
    () async {
      final clock = _AdjustableClock(DateTime.utc(2026, 8, 19, 20));
      final container = _lockedContainer(clock);
      final controller = await _configuredController(container, correctPin);
      final waits = <Duration>[];

      for (var attempt = 0; attempt < parentPinFreeAttempts + 4; attempt++) {
        final result = await controller.unlock(wrongPin);
        waits.add(result.remainingCooldown);
        clock.now = clock.now.add(result.remainingCooldown);
      }

      expect(waits.skip(parentPinFreeAttempts - 1), <Duration>[
        const Duration(seconds: 30),
        const Duration(minutes: 1),
        const Duration(minutes: 2),
        const Duration(minutes: 5),
        const Duration(minutes: 5),
      ]);
    },
  );

  test('the correct PIN unlocks once the cooldown has elapsed', () async {
    final clock = _AdjustableClock(DateTime.utc(2026, 8, 19, 20));
    final container = _lockedContainer(clock);
    final controller = await _configuredController(container, correctPin);
    for (var attempt = 0; attempt < parentPinFreeAttempts; attempt++) {
      await controller.unlock(wrongPin);
    }

    clock.now = clock.now.add(const Duration(seconds: 31));
    final unlocked = await controller.unlock(correctPin);
    final repository = await container.read(localRepositoryProvider.future);
    final saved = await repository.readParentSecurity();

    expect(unlocked.isUnlocked, isTrue);
    expect(
      container.read(parentAccessControllerProvider).value?.isUnlocked,
      isTrue,
    );
    expect(saved?.failedAttempts, 0);
    expect(saved?.lockedUntil, isNull);
  });

  test('the attempt counter survives an app restart', () async {
    final clock = _AdjustableClock(DateTime.utc(2026, 8, 19, 20));
    final container = _lockedContainer(clock);
    final controller = await _configuredController(container, correctPin);
    for (var attempt = 0; attempt < parentPinFreeAttempts; attempt++) {
      await controller.unlock(wrongPin);
    }

    final restarted = _lockedContainer(clock);
    final restoredState = await restarted.read(
      parentAccessControllerProvider.future,
    );

    expect(restoredState.isUnlocked, isFalse);
    expect(restoredState.record?.failedAttempts, parentPinFreeAttempts);
    expect(
      restoredState.remainingCooldown(clock.now),
      const Duration(seconds: 30),
    );
  });

  test(
    'changing the PIN requires the current one and counts attempts',
    () async {
      final clock = _AdjustableClock(DateTime.utc(2026, 8, 19, 20));
      final container = _lockedContainer(clock);
      final controller = await _configuredController(container, correctPin);
      await controller.unlock(correctPin);

      final refused = await controller.verifyPin(wrongPin);
      final stillOpen = container
          .read(parentAccessControllerProvider)
          .value
          ?.isUnlocked;
      final accepted = await controller.verifyPin(correctPin);
      await controller.setPin('86420');

      expect(refused.outcome, ParentUnlockOutcome.incorrectPin);
      expect(stillOpen, isTrue);
      expect(accepted.isUnlocked, isTrue);
      expect((await controller.verifyPin('86420')).isUnlocked, isTrue);
      expect((await controller.verifyPin(correctPin)).isUnlocked, isFalse);
    },
  );

  test('backgrounding the app re-locks an unlocked parent session', () async {
    final clock = _AdjustableClock(DateTime.utc(2026, 8, 19, 20));
    final container = _lockedContainer(clock);
    final controller = await _configuredController(container, correctPin);
    await controller.unlock(correctPin);
    expect(
      container.read(parentAccessControllerProvider).value?.isUnlocked,
      isTrue,
    );

    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );

    expect(
      container.read(parentAccessControllerProvider).value?.isUnlocked,
      isFalse,
    );
  });
}

/// Creates a container whose PIN work is fast and whose clock is controlled.
ProviderContainer _lockedContainer(_AdjustableClock clock) {
  final container = ProviderContainer(
    overrides: [
      parentSecurityServiceProvider.overrideWithValue(
        ParentSecurityService(deriver: _fakeDeriver),
      ),
      parentSecurityClockProvider.overrideWithValue(clock.call),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Configures a PIN and locks the session so attempts are actually verified.
Future<ParentAccessController> _configuredController(
  ProviderContainer container,
  String pin,
) async {
  await container.read(parentAccessControllerProvider.future);
  final controller = container.read(parentAccessControllerProvider.notifier);
  await controller.setPin(pin);
  controller.lock();
  return controller;
}

/// Stands in for Argon2id so attempt-policy tests stay fast.
///
/// The real derivation is covered by `parent_security_service_test.dart`;
/// repeating it here would add minutes of CPU work per wrong PIN without
/// proving anything about throttling. Still salt- and PIN-dependent, so a
/// wrong PIN never matches a stored verifier.
Future<Uint8List> _fakeDeriver(ParentPinDerivation derivation) async {
  final pinBytes = utf8.encode(derivation.pin);
  return Uint8List.fromList(
    List<int>.generate(
      parentSecurityHashLength,
      (index) =>
          (pinBytes[index % pinBytes.length] +
              derivation.salt[index % derivation.salt.length]) &
          0xFF,
    ),
  );
}

/// Clock a test can move forward to step over a stored cooldown.
class _AdjustableClock {
  /// Starts at a fixed instant so cooldown maths stay deterministic.
  _AdjustableClock(this.now);

  /// Current instant reported to the controller.
  DateTime now;

  /// Reads the current instant as a plain clock function.
  DateTime call() => now;
}
