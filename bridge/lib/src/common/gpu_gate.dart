import 'dart:async';

/// Sink for the gate's own content-free lines.
typedef GpuGateLogSink = void Function(String message);

/// Something that loads the machine's single GPU and can be asked to let go.
///
/// One instance per queue, not per job: [GpuGate] compares tenants by identity
/// to decide whether the card is changing hands, so the story queue must
/// always hand it the same object and so must the illustration queue.
abstract interface class GpuTenant {
  /// Short, content-free name for logs, e.g. `ollama`.
  String get name;

  /// Frees whatever this tenant left resident on the card.
  ///
  /// Called by [GpuGate] once this tenant's turn is over and the next turn
  /// belongs to somebody else. It must never throw for an ordinary failure —
  /// but if it does, or if it hangs, the gate carries on regardless: a card
  /// that could not be freed is a worse render, while a gate stuck waiting on
  /// an eviction is both queues stopped forever.
  Future<void> evict();
}

/// Serializes every piece of work that needs the machine's single GPU, and
/// clears the card between the two tenants that share it.
///
/// The PC has one 4 GB card. Story generation loads a language model onto it
/// and illustration rendering loads a diffusion checkpoint onto it, so the
/// two must never overlap — two workers that each fit alone will together
/// exhaust the card and fail in a way neither queue can explain. Rather than
/// merging the two queues (they have different job shapes, statuses and
/// failure modes), both run their GPU work through this one gate.
///
/// Mutual exclusion alone is not enough, because a model that has finished
/// generating is still resident: the next tenant would find a card that is
/// nominally free and actually full. So the gate, not the queues, decides
/// when a departing tenant has to let go — before the card changes hands, and
/// again when the card goes idle, which is the only way the machine ever gets
/// its VRAM back between sessions. Two turns in a row for the same tenant are
/// left alone on purpose: interrupting ComfyUI between the pages of one book,
/// or reloading the language model between two queued stories, would pay the
/// whole load cost for nothing.
///
/// Waiters are served strictly first-come-first-served, so a queue can never
/// starve the other one.
class GpuGate {
  /// Creates an idle gate.
  ///
  /// [evictionTimeout] bounds one [GpuTenant.evict] call — a local service
  /// that stops answering must not be able to wedge both queues — and [log]
  /// receives one content-free line whenever an eviction fails or overruns.
  GpuGate({
    this.evictionTimeout = const Duration(seconds: 5),
    GpuGateLogSink? log,
  }) : _log = log ?? _ignoreLog;

  /// Wall-clock budget for one [GpuTenant.evict] call.
  ///
  /// Tenants that talk to a local service over HTTP should use this as their
  /// request timeout too, so the gate never has to abandon a call it started.
  final Duration evictionTimeout;

  final GpuGateLogSink _log;
  final List<_GpuWaiter> _waiting = <_GpuWaiter>[];
  GpuTenant? _holder;

  /// Whether some tenant currently holds the card.
  bool get isBusy => _holder != null;

  /// How many callers are waiting for their turn on the card.
  int get waitingCount => _waiting.length;

  /// Runs [body] with [tenant] in sole possession of the GPU.
  ///
  /// Returns what [body] returned. An error thrown by [body] reaches the
  /// caller unchanged, but only after the card has been freed and handed on:
  /// a failed job must never leave the next one waiting behind it.
  Future<T> run<T>(GpuTenant tenant, Future<T> Function() body) async {
    await _take(tenant);
    try {
      return await body();
    } finally {
      await _handOver(tenant);
    }
  }

  Future<void> _take(GpuTenant tenant) async {
    if (_holder == null) {
      _holder = tenant;
      return;
    }
    final waiter = _GpuWaiter(tenant);
    _waiting.add(waiter);
    // The holder is set by the handover, not here: a third caller arriving
    // between the wake-up and this line must still see a busy gate.
    await waiter.turn.future;
  }

  Future<void> _handOver(GpuTenant departing) async {
    final _GpuWaiter? next = _waiting.isEmpty ? null : _waiting.first;
    if (next == null || !identical(next.tenant, departing)) {
      await _evict(departing);
    }
    // Re-read the line: callers may have joined it while the eviction ran.
    if (_waiting.isEmpty) {
      _holder = null;
      return;
    }
    // Hand the gate straight to the next waiter instead of going idle, so a
    // third caller cannot jump the line between release and wake-up.
    final waiter = _waiting.removeAt(0);
    _holder = waiter.tenant;
    waiter.turn.complete();
  }

  Future<void> _evict(GpuTenant tenant) async {
    try {
      await tenant.evict().timeout(evictionTimeout);
    } on TimeoutException {
      // The call is left running; the card is handed on anyway. A late
      // eviction is a slow next render, a blocked gate is a dead bridge.
      _log('gpu gate: ${tenant.name} did not free the card in time');
    } catch (_) {
      // Details are dropped on purpose: they can quote a local service's
      // response body.
      _log('gpu gate: ${tenant.name} eviction failed');
    }
  }

  static void _ignoreLog(String message) {
    // Logging is opt-in; the gate stays silent unless a sink is wired.
  }
}

/// One caller queued behind the current holder, with the tenant it will run.
class _GpuWaiter {
  _GpuWaiter(this.tenant);

  final GpuTenant tenant;
  final Completer<void> turn = Completer<void>();
}
