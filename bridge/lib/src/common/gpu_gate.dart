import 'dart:async';

/// Serializes every piece of work that needs the machine's single GPU.
///
/// The PC has one 4 GB card. Story generation loads a language model onto it
/// and illustration rendering loads a diffusion checkpoint onto it, so the
/// two must never overlap — two workers that each fit alone will together
/// exhaust the card and fail in a way neither queue can explain. Rather than
/// merging the two queues (they have different job shapes, statuses and
/// failure modes), both hold a lease from this one gate for the duration of
/// their GPU work.
///
/// Waiters are served strictly first-come-first-served, so a queue can never
/// starve the other one.
class GpuGate {
  /// Creates an idle gate.
  GpuGate();

  final List<Completer<void>> _waiting = <Completer<void>>[];
  bool _held = false;

  /// Whether a lease is currently held.
  bool get isBusy => _held;

  /// How many callers are waiting for the current lease to be released.
  int get waitingCount => _waiting.length;

  /// Waits until the GPU is free and returns the lease that holds it.
  ///
  /// Always release the returned lease in a `finally`: a lease that is never
  /// released blocks both queues forever.
  Future<GpuLease> acquire() async {
    if (_held) {
      final completer = Completer<void>();
      _waiting.add(completer);
      await completer.future;
    } else {
      _held = true;
    }
    return GpuLease._(this);
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      // Hand the gate straight to the next waiter instead of going idle, so
      // a third caller cannot jump the line between release and wake-up.
      _waiting.removeAt(0).complete();
      return;
    }
    _held = false;
  }
}

/// Exclusive hold on the GPU handed out by [GpuGate.acquire].
class GpuLease {
  GpuLease._(this._gate);

  final GpuGate _gate;
  bool _released = false;

  /// Whether this lease has already been given back.
  bool get isReleased => _released;

  /// Gives the GPU back to the next waiter. Idempotent.
  void release() {
    if (_released) {
      return;
    }
    _released = true;
    _gate._release();
  }
}
