import 'dart:math';

import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:uuid/uuid.dart';

/// Tunable pairing rules; defaults follow the bridge specification.
class PairingPolicy {
  /// Creates a policy.
  const PairingPolicy({
    this.codeLifetime = const Duration(minutes: 2),
    this.maxWrongAttempts = 5,
    this.rateLimitWindow = const Duration(minutes: 1),
    this.maxRequestsPerWindow = 5,
  });

  /// How long one pairing code stays valid.
  final Duration codeLifetime;

  /// Number of wrong code entries that invalidate a pending pairing.
  final int maxWrongAttempts;

  /// Rolling window used for request rate limiting.
  final Duration rateLimitWindow;

  /// Maximum pairing requests allowed within [rateLimitWindow].
  final int maxRequestsPerWindow;
}

/// Raised when too many pairing requests arrive within the rate limit window.
class RateLimitExceededException implements Exception {
  /// Creates the exception with the suggested retry delay.
  const RateLimitExceededException({required this.retryAfterSeconds});

  /// Suggested minimum wait before retrying, in whole seconds.
  final int retryAfterSeconds;

  @override
  String toString() =>
      'RateLimitExceededException(retryAfterSeconds: $retryAfterSeconds)';
}

/// A freshly issued pairing request.
class PairingRequest {
  /// Creates a request ticket.
  const PairingRequest({
    required this.pairingId,
    required this.code,
    required this.expiresAtUtc,
  });

  /// Opaque identifier returned to the phone and used to confirm.
  final String pairingId;

  /// The 6-digit code. Only ever surfaced on the PC console, never in HTTP
  /// responses.
  final String code;

  /// When the code stops being valid.
  final DateTime expiresAtUtc;
}

/// Why a confirmation attempt was denied.
enum PairingDenialReason {
  /// No pending pairing exists under the given id (or it was invalidated).
  unknownPairingId,

  /// The pairing existed but its code lifetime has passed.
  expired,

  /// The submitted code does not match.
  wrongCode,
}

/// Outcome of a pairing confirmation attempt.
sealed class PairingConfirmOutcome {
  const PairingConfirmOutcome();
}

/// The code matched and the device may be registered.
class PairingApproved extends PairingConfirmOutcome {
  /// Creates an approval carrying the pairing id that was consumed.
  const PairingApproved({required this.pairingId});

  /// The pairing id that was consumed by this approval.
  final String pairingId;
}

/// The confirmation was rejected.
class PairingDenied extends PairingConfirmOutcome {
  /// Creates a denial with its reason.
  const PairingDenied(this.reason);

  /// Machine-readable denial reason mapped to typed JSON errors.
  final PairingDenialReason reason;
}

/// One pending pairing kept in memory until confirmed, expired or invalidated.
class _PendingPairing {
  _PendingPairing({required this.codeDigestHex, required this.expiresAtUtc});

  final String codeDigestHex;
  final DateTime expiresAtUtc;
  int wrongAttempts = 0;
}

/// Issues and confirms short-lived pairing codes entirely in memory.
///
/// Codes are generated from a secure random source, stored only as SHA-256
/// digests, compared in constant time, and never logged or returned over
/// HTTP. Pending pairings vanish on restart by design: pairing is a live,
/// human-in-the-loop ceremony.
class PairingService {
  /// Creates a service. [clock] is injectable for deterministic tests.
  PairingService({
    this.policy = const PairingPolicy(),
    this._uuid = const Uuid(),
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  /// Tunable rules applied to every pairing ceremony.
  final PairingPolicy policy;
  final Uuid _uuid;
  final DateTime Function() _now;

  final Map<String, _PendingPairing> _pending = <String, _PendingPairing>{};
  final List<DateTime> _recentRequestTimes = <DateTime>[];

  /// Issues a new pairing request unless the rolling-window rate limit
  /// ([PairingPolicy.maxRequestsPerWindow] per
  /// [PairingPolicy.rateLimitWindow]) is exhausted, in which case a
  /// [RateLimitExceededException] is thrown before any code is generated.
  PairingRequest issueRequest() {
    final nowUtc = _now().toUtc();
    _purgeExpired(nowUtc);
    _enforceRateLimit(nowUtc);
    final pairingId = _uuid.v4();
    final code = _generateCode();
    final expiresAtUtc = nowUtc.add(policy.codeLifetime);
    _pending[pairingId] = _PendingPairing(
      codeDigestHex: sha256Hex(code),
      expiresAtUtc: expiresAtUtc,
    );
    return PairingRequest(
      pairingId: pairingId,
      code: code,
      expiresAtUtc: expiresAtUtc,
    );
  }

  /// Attempts to confirm [pairingId] with [code].
  ///
  /// Wrong codes count towards [PairingPolicy.maxWrongAttempts]; reaching the
  /// limit invalidates the pending pairing so even the correct code is no
  /// longer accepted. A successful confirmation consumes the pairing.
  PairingConfirmOutcome confirm({
    required String pairingId,
    required String code,
  }) {
    final nowUtc = _now().toUtc();
    final pending = _pending[pairingId];
    if (pending == null) {
      return const PairingDenied(PairingDenialReason.unknownPairingId);
    }
    if (!nowUtc.isBefore(pending.expiresAtUtc)) {
      _pending.remove(pairingId);
      return const PairingDenied(PairingDenialReason.expired);
    }
    final matches = constantTimeHexDigestEquals(
      sha256Hex(code),
      pending.codeDigestHex,
    );
    if (!matches) {
      pending.wrongAttempts += 1;
      if (pending.wrongAttempts >= policy.maxWrongAttempts) {
        _pending.remove(pairingId);
      }
      return const PairingDenied(PairingDenialReason.wrongCode);
    }
    _pending.remove(pairingId);
    return PairingApproved(pairingId: pairingId);
  }

  /// Number of currently pending pairings; useful for tests and metrics.
  int get pendingCount => _pending.length;

  void _purgeExpired(DateTime nowUtc) {
    _pending.removeWhere(
      (_, pending) => !nowUtc.isBefore(pending.expiresAtUtc),
    );
  }

  void _enforceRateLimit(DateTime nowUtc) {
    final windowStart = nowUtc.subtract(policy.rateLimitWindow);
    _recentRequestTimes.removeWhere((time) => time.isBefore(windowStart));
    if (_recentRequestTimes.length >= policy.maxRequestsPerWindow) {
      final oldestKept = _recentRequestTimes.first;
      final waitUntil = oldestKept.add(policy.rateLimitWindow);
      var remainingMs = waitUntil.difference(nowUtc).inMilliseconds + 1000;
      if (remainingMs < 1000) {
        remainingMs = 1000;
      }
      throw RateLimitExceededException(
        retryAfterSeconds: (remainingMs / 1000).ceil(),
      );
    }
    _recentRequestTimes.add(nowUtc);
  }

  String _generateCode() {
    final secureRandom = Random.secure();
    final value = secureRandom.nextInt(1000000);
    return value.toString().padLeft(6, '0');
  }
}
