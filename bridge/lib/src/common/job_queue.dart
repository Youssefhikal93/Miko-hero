import 'dart:async';

import 'package:iam_hero_bridge/src/generation/cancellation.dart';

/// Sink for privacy-safe queue log lines.
///
/// Only job ids, statuses, counts, timings and typed error codes are ever
/// passed to it — never prompts, story text, scene descriptions or child
/// names.
typedef JobLogSink = void Function(String message);

/// How many finished jobs stay readable before the oldest are dropped.
///
/// One number for every queue on purpose: the cap exists to bound memory on
/// a home PC, and no queue has a reason to remember more of its past than
/// the other.
const int maxRetainedFinishedJobs = 100;

/// The little a [JobQueue] needs to know about the snapshots it hands out.
///
/// Everything else about a job — its statuses, its counts, its JSON shape —
/// belongs to the concrete queue and never reaches the shared machinery.
abstract interface class QueuedJob {
  /// Stable job id (uuid v4).
  String get id;

  /// Device that created the job; only that device may read or cancel it.
  String get deviceId;

  /// Whether the job will never change state again.
  bool get isTerminal;
}

/// One FIFO line of jobs drained by a single worker.
///
/// The machine has one small GPU, so concurrency is not a tuning knob: a
/// single worker drains the line and every other job waits with a reported
/// queue position. Jobs live in memory only — the durable queue is the app's,
/// and a bridge restart is meant to clear in-flight work.
///
/// This class owns everything that is the same whatever is being made:
/// admission, queue positions, cancellation, the settle/retention
/// bookkeeping, content-free log lines and the pump. A subclass supplies
/// [runJob] — how to run one job, including which GPU lease granularity and
/// which failure policy that kind of work needs — plus [markCancelled], the
/// one snapshot edit the shared cancellation path cannot write itself.
///
/// [TPlan] is whatever the worker needs that must not appear in the public
/// snapshot; it is handed to [runJob] and dropped when the job settles.
abstract class JobQueue<TJob extends QueuedJob, TPlan> {
  /// Creates an empty queue.
  ///
  /// [jobLabel] prefixes every log line (`job <id> …`), [unknownJobMessage]
  /// is the [StateError] text for an id this queue never issued, [clock] and
  /// [log] are the injection seams tests replace.
  JobQueue({
    required this._jobLabel,
    required this._unknownJobMessage,
    DateTime Function()? clock,
    JobLogSink? log,
  }) : _clock = clock ?? DateTime.now,
       _log = log ?? _ignoreLog;

  final String _jobLabel;
  final String _unknownJobMessage;
  final DateTime Function() _clock;
  final JobLogSink _log;

  final Map<String, TJob> _jobs = <String, TJob>{};
  final Map<String, TPlan> _plans = <String, TPlan>{};
  final List<String> _pending = <String>[];
  final Map<String, CancellationToken> _tokens = <String, CancellationToken>{};
  final Map<String, Completer<TJob>> _settled = <String, Completer<TJob>>{};
  final List<String> _finishedOrder = <String>[];

  String? _activeJobId;
  bool _pumping = false;

  /// Returns the current snapshot of [jobId], or `null` when unknown.
  TJob? job(String jobId) => _jobs[jobId];

  /// Position of [jobId] in line, counting the running job as position 1.
  ///
  /// Returns `null` for jobs that are not waiting any more.
  int? queuePosition(String jobId) {
    final index = _pending.indexOf(jobId);
    if (index < 0) {
      return null;
    }
    return index + 1 + (_activeJobId == null ? 0 : 1);
  }

  /// Cancels [jobId] and returns its final snapshot. Idempotent.
  ///
  /// A queued job is removed from the line and settles at once, because
  /// nothing is running it and no worker will ever settle it. The running
  /// job has its token cancelled and stops where its worker chooses to look.
  /// Terminal jobs are returned unchanged.
  TJob cancel(String jobId) {
    final current = _jobs[jobId];
    if (current == null) {
      throw StateError(_unknownJobMessage);
    }
    if (current.isTerminal) {
      return current;
    }
    _pending.remove(jobId);
    final cancelled = markCancelled(current);
    _jobs[jobId] = cancelled;
    _tokens[jobId]?.cancel();
    _log('$_jobLabel $jobId cancelled');
    if (_activeJobId != jobId) {
      // Nothing is running it, so no worker will ever settle it.
      _settle(cancelled);
    }
    return cancelled;
  }

  /// Completes once [jobId] has reached a terminal state and its worker has
  /// stopped touching the library.
  Future<TJob> whenSettled(String jobId) {
    final completer = _settled[jobId];
    if (completer != null) {
      return completer.future;
    }
    final finished = _jobs[jobId];
    if (finished != null && finished.isTerminal) {
      return Future<TJob>.value(finished);
    }
    return Future<TJob>.error(
      StateError(_unknownJobMessage),
      StackTrace.current,
    );
  }

  /// Cancels every unfinished job; used when the bridge shuts down.
  void shutdown() {
    for (final id in <String>[..._pending, ?_activeJobId]) {
      final current = _jobs[id];
      if (current != null && !current.isTerminal) {
        cancel(id);
      }
    }
  }

  /// Runs one admitted job to a terminal state. Supplied by the subclass.
  ///
  /// [plan] is what was handed to [admit], [token] is cancelled the moment
  /// the parent asks to stop, and the worker is expected to leave [job]'s id
  /// in a terminal state — the pump settles it either way once this returns.
  /// Only one call is ever in flight.
  Future<void> runJob(TJob job, TPlan plan, CancellationToken token);

  /// Returns [current] rewritten as a cancelled snapshot.
  ///
  /// The shared [cancel] path decides *when* a job is cancelled; only the
  /// concrete job model knows what that looks like.
  TJob markCancelled(TJob current);

  /// Takes [job] into the line with the private [plan] its worker will need.
  ///
  /// The worker is started on a later microtask, so the returned snapshot is
  /// always the queued one and its queue position is stable for the response.
  /// [logFields] are extra `key=value` fragments for the queued log line,
  /// written before the position.
  TJob admit(
    TJob job,
    TPlan plan, {
    List<String> logFields = const <String>[],
  }) {
    _jobs[job.id] = job;
    _plans[job.id] = plan;
    _pending.add(job.id);
    _tokens[job.id] = CancellationToken();
    _settled[job.id] = Completer<TJob>();
    final fields = <String>[...logFields, 'position=${queuePosition(job.id)}'];
    _log('$_jobLabel ${job.id} queued ${fields.join(' ')}');
    scheduleMicrotask(() => unawaited(_pump()));
    return job;
  }

  /// The snapshot of [jobId], which the caller knows exists.
  TJob requireJob(String jobId) => _jobs[jobId]!;

  /// Replaces the snapshot of a job that is still running.
  ///
  /// Unknown and terminal jobs are left alone: a cancellation the parent
  /// already asked for must never be overwritten by a progress line.
  void updateJob(String jobId, TJob Function(TJob current) change) {
    final current = _jobs[jobId];
    if (current == null || current.isTerminal) {
      return;
    }
    _jobs[jobId] = change(current);
  }

  /// Replaces the snapshot of [job] unconditionally.
  ///
  /// For outcomes the worker has already decided, where the terminal guard
  /// of [updateJob] would throw the outcome away.
  void storeJob(TJob job) {
    _jobs[job.id] = job;
  }

  /// Settles [jobId] when it has reached a terminal state. Idempotent.
  ///
  /// A worker calls this once it has stopped touching the library — which is
  /// later than "the last state change" for a queue that unloads a model
  /// afterwards. The pump calls it too, as a backstop, so no job can be left
  /// with a waiter that never completes.
  void settleIfTerminal(String jobId) {
    final current = _jobs[jobId];
    if (current != null && current.isTerminal) {
      _settle(current);
    }
  }

  /// Writes one content-free log line about [jobId].
  void logJob(String jobId, String message) {
    _log('$_jobLabel $jobId $message');
  }

  /// Writes one content-free log line that belongs to the queue, not a job.
  ///
  /// For what happens after a turn is over — the gate evicting this queue's
  /// tenant, for instance — where no single job is the subject any more.
  void logLine(String message) {
    _log(message);
  }

  /// The queue's clock, in UTC.
  DateTime nowUtc() => _clock().toUtc();

  /// Milliseconds elapsed since [start], for a timing log line.
  int elapsedMs(DateTime start) =>
      _clock().toUtc().difference(start).inMilliseconds;

  Future<void> _pump() async {
    if (_pumping) {
      return;
    }
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        final id = _pending.removeAt(0);
        final job = _jobs[id];
        if (job == null || job.isTerminal) {
          continue;
        }
        _activeJobId = id;
        try {
          await runJob(
            job,
            _plans[id] as TPlan,
            _tokens[id] ?? CancellationToken(),
          );
        } finally {
          _activeJobId = null;
          settleIfTerminal(id);
        }
      }
    } finally {
      _pumping = false;
    }
  }

  void _settle(TJob job) {
    final completer = _settled.remove(job.id);
    if (completer == null) {
      // Already settled; retention must not count the same job twice.
      return;
    }
    _tokens.remove(job.id);
    _plans.remove(job.id);
    if (!completer.isCompleted) {
      completer.complete(job);
    }
    _finishedOrder.add(job.id);
    while (_finishedOrder.length > maxRetainedFinishedJobs) {
      _jobs.remove(_finishedOrder.removeAt(0));
    }
  }

  static void _ignoreLog(String message) {
    // Logging is opt-in; the bridge stays silent unless a sink is wired.
  }
}
