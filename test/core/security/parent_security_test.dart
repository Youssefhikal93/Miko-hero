import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/security/parent_security.dart';

/// Verifies the stored attempt history that throttles parent-PIN entry.
void main() {
  final now = DateTime.utc(2026, 8, 19, 20);

  test('the first four wrong PINs are accepted without a cooldown', () {
    var record = _record();

    for (var attempt = 1; attempt < parentPinFreeAttempts; attempt++) {
      record = record.withFailedAttempt(now);
      expect(record.failedAttempts, attempt);
      expect(record.isInCooldown(now), isFalse);
    }
  });

  test('the fifth wrong PIN starts the escalating cooldown', () {
    var record = _record();
    final cooldowns = <Duration>[];

    for (var attempt = 0; attempt < parentPinFreeAttempts + 4; attempt++) {
      record = record.withFailedAttempt(now);
      cooldowns.add(record.remainingCooldown(now));
    }

    expect(cooldowns.take(parentPinFreeAttempts - 1), <Duration>[
      Duration.zero,
      Duration.zero,
      Duration.zero,
      Duration.zero,
    ]);
    expect(cooldowns.skip(parentPinFreeAttempts - 1), <Duration>[
      const Duration(seconds: 30),
      const Duration(minutes: 1),
      const Duration(minutes: 2),
      const Duration(minutes: 5),
      const Duration(minutes: 5),
    ]);
  });

  test('an elapsed cooldown reopens input without clearing the history', () {
    final record = _record().withFailedAttempt(now).withFailedAttempt(now);
    var throttled = record;
    for (var attempt = 0; attempt < 3; attempt++) {
      throttled = throttled.withFailedAttempt(now);
    }

    expect(
      throttled.isInCooldown(now.add(const Duration(seconds: 29))),
      isTrue,
    );
    expect(
      throttled.isInCooldown(now.add(const Duration(seconds: 31))),
      isFalse,
    );
    expect(throttled.failedAttempts, parentPinFreeAttempts);
  });

  test('a correct PIN clears both the counter and the cooldown', () {
    var record = _record();
    for (var attempt = 0; attempt < parentPinFreeAttempts + 2; attempt++) {
      record = record.withFailedAttempt(now);
    }

    final unlocked = record.withoutFailedAttempts();

    expect(unlocked.failedAttempts, 0);
    expect(unlocked.lockedUntil, isNull);
    expect(unlocked.isInCooldown(now), isFalse);
    expect(unlocked.verifierBase64, record.verifierBase64);
  });

  test('the attempt history survives a storage round trip', () {
    final record = _record().withFailedAttempt(now).withFailedAttempt(now);

    final restored = ParentSecurityRecord.fromJson(record.toJson());

    expect(restored.failedAttempts, 2);
    expect(restored.lockedUntil, record.lockedUntil);
    expect(restored.saltBase64, record.saltBase64);
  });

  test('a version-one record decodes with an empty attempt history', () {
    final restored = ParentSecurityRecord.fromJson(<String, Object?>{
      'version': 1,
      'salt': base64Encode(List<int>.filled(parentSecuritySaltLength, 1)),
      'verifier': base64Encode(List<int>.filled(parentSecurityHashLength, 2)),
    });

    expect(restored.failedAttempts, 0);
    expect(restored.lockedUntil, isNull);
    expect(restored.isInCooldown(now), isFalse);
  });

  test('a record from a newer version is refused', () {
    expect(
      () => ParentSecurityRecord.fromJson(<String, Object?>{
        'version': parentSecurityVersion + 1,
        'salt': base64Encode(List<int>.filled(parentSecuritySaltLength, 1)),
        'verifier': base64Encode(List<int>.filled(parentSecurityHashLength, 2)),
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

/// Builds a verifier record with obviously fake, correctly sized bytes.
ParentSecurityRecord _record() {
  return ParentSecurityRecord(
    saltBase64: base64Encode(List<int>.filled(parentSecuritySaltLength, 7)),
    verifierBase64: base64Encode(List<int>.filled(parentSecurityHashLength, 9)),
  );
}
