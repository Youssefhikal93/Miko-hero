import 'dart:async';

/// Cooperative cancellation signal shared by one generation job and the
/// HTTP call it currently has in flight.
///
/// Cancellation is one-way and idempotent: once cancelled a token stays
/// cancelled, so late listeners still observe it.
class CancellationToken {
  /// Creates a token that has not been cancelled yet.
  CancellationToken();

  final Completer<void> _cancelled = Completer<void>();

  /// Whether [cancel] has already been called.
  bool get isCancelled => _cancelled.isCompleted;

  /// Completes as soon as the token is cancelled.
  ///
  /// It never completes with an error, so listeners can await it without a
  /// guard, and it never completes at all when the work finishes normally.
  Future<void> get whenCancelled => _cancelled.future;

  /// Requests cancellation. Calling this more than once has no effect.
  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }
}
