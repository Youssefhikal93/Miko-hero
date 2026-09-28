import 'dart:async';

import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:test/test.dart';

/// The queue's own behaviour, proved without a server, a model or a GPU.
///
/// Both real queues inherit every line of this: positions, cancellation,
/// settling, retention and the single worker. A fake job whose run is held
/// open by a [Completer] makes the states that are hard to hit over HTTP —
/// cancel exactly while running, a hundred and one finished jobs, a shutdown
/// mid-line — ordinary to write.
void main() {
  test('a queued job reports its place behind the running one', () async {
    final queue = _FakeQueue();
    final first = queue.enqueue('a');
    final second = queue.enqueue('b');

    expect(
      queue.queuePosition(first.id),
      1,
      reason: 'nothing is running yet, so the first in line is first',
    );
    expect(queue.queuePosition(second.id), 2);

    await queue.started.first;

    expect(
      queue.queuePosition(first.id),
      isNull,
      reason: 'the running job is not waiting any more',
    );
    expect(
      queue.queuePosition(second.id),
      2,
      reason: 'the running job counts as position 1',
    );

    queue.releaseAll();
    await queue.whenSettled(second.id);
  });

  test('cancelling a queued job settles it without ever running it', () async {
    final queue = _FakeQueue();
    final running = queue.enqueue('a');
    await queue.started.first;
    final waiting = queue.enqueue('b');

    final cancelled = queue.cancel(waiting.id);
    expect(cancelled.status, _FakeStatus.cancelled);
    expect(
      await queue.whenSettled(waiting.id),
      isA<_FakeJob>().having(
        (job) => job.status,
        'status',
        _FakeStatus.cancelled,
      ),
    );

    queue.releaseAll();
    await queue.whenSettled(running.id);
    expect(queue.ranJobIds, <String>['a'], reason: 'b never reached a worker');
  });

  test('cancelling the running job cancels its token', () async {
    final queue = _FakeQueue();
    final job = queue.enqueue('a');
    await queue.started.first;

    queue.cancel(job.id);
    expect(queue.tokens.single.isCancelled, isTrue);

    queue.releaseAll();
    final settled = await queue.whenSettled(job.id);
    expect(
      settled.status,
      _FakeStatus.cancelled,
      reason: 'a worker that sees a cancelled token writes no outcome',
    );
  });

  test('cancelling a finished job returns it unchanged', () async {
    final queue = _FakeQueue();
    final job = queue.enqueue('a');
    queue.releaseAll();
    final settled = await queue.whenSettled(job.id);
    expect(settled.status, _FakeStatus.completed);

    final first = queue.cancel(job.id);
    final second = queue.cancel(job.id);

    expect(first.status, _FakeStatus.completed);
    expect(second.status, _FakeStatus.completed);
    expect(
      queue.job(job.id)!.status,
      _FakeStatus.completed,
      reason: 'cancellation after the fact is a no-op, not a rewrite',
    );
  });

  test('cancelling an id the queue never issued is a StateError', () {
    final queue = _FakeQueue();
    expect(() => queue.cancel('nobody'), throwsA(isA<StateError>()));
  });

  test('whenSettled answers for a job that already settled', () async {
    final queue = _FakeQueue();
    final job = queue.enqueue('a');
    queue.releaseAll();
    await queue.whenSettled(job.id);

    final again = await queue.whenSettled(job.id);
    expect(again.status, _FakeStatus.completed);
  });

  test('only the hundred most recent finished jobs stay readable', () async {
    final queue = _FakeQueue();
    final ids = <String>[];
    for (var index = 0; index <= maxRetainedFinishedJobs; index++) {
      ids.add(queue.enqueue('job-$index').id);
      queue.releaseAll();
    }
    await queue.whenSettled(ids.last);

    expect(
      queue.job(ids.first),
      isNull,
      reason: 'the oldest of a hundred and one is dropped',
    );
    expect(queue.job(ids[1]), isNotNull);
    expect(queue.job(ids.last), isNotNull);
  });

  test('shutdown abandons everything still in line', () async {
    final queue = _FakeQueue();
    final running = queue.enqueue('a');
    await queue.started.first;
    final second = queue.enqueue('b');
    final third = queue.enqueue('c');

    queue.shutdown();

    expect(queue.job(second.id)!.status, _FakeStatus.cancelled);
    expect(queue.job(third.id)!.status, _FakeStatus.cancelled);
    expect(queue.job(running.id)!.status, _FakeStatus.cancelled);

    queue.releaseAll();
    await queue.whenSettled(running.id);
    expect(
      queue.ranJobIds,
      <String>['a'],
      reason: 'the abandoned line is never drained after a shutdown',
    );
  });

  test('the pump runs one job at a time and never re-enters', () async {
    final queue = _FakeQueue();
    final ids = <String>[
      for (final name in <String>['a', 'b', 'c']) queue.enqueue(name).id,
    ];

    await queue.started.first;
    expect(queue.concurrentRuns, 1);
    queue.releaseAll();
    await queue.whenSettled(ids.last);

    expect(queue.ranJobIds, <String>['a', 'b', 'c'], reason: 'strictly FIFO');
    expect(
      queue.peakConcurrentRuns,
      1,
      reason: 'a second pump must find the first one already draining',
    );
  });

  test('a queued job logs its position behind the label it was given', () {
    final lines = <String>[];
    final queue = _FakeQueue(log: lines.add);
    final job = queue.enqueue('a');

    expect(lines.single, 'fake job ${job.id} queued plan=a position=1');
  });
}

/// Lifecycle of a fake job: two live states, three terminal ones.
enum _FakeStatus { queued, running, completed, cancelled }

/// The smallest thing a [JobQueue] can carry.
class _FakeJob implements QueuedJob {
  const _FakeJob({
    required this.id,
    required this.deviceId,
    required this.status,
  });

  @override
  final String id;

  @override
  final String deviceId;

  final _FakeStatus status;

  @override
  bool get isTerminal =>
      status == _FakeStatus.completed || status == _FakeStatus.cancelled;

  _FakeJob copyWith({_FakeStatus? status}) =>
      _FakeJob(id: id, deviceId: deviceId, status: status ?? this.status);
}

/// A queue whose worker does nothing but wait to be let go.
class _FakeQueue extends JobQueue<_FakeJob, String> {
  _FakeQueue({super.log})
    : super(jobLabel: 'fake job', unknownJobMessage: 'Unknown fake job.');

  final StreamController<String> _started =
      StreamController<String>.broadcast();
  final List<Completer<void>> _gates = <Completer<void>>[];
  bool _released = false;

  /// Ids in the order the worker actually picked them up.
  final List<String> ranJobIds = <String>[];

  /// Tokens the pump handed to the worker, newest last.
  final List<CancellationToken> tokens = <CancellationToken>[];

  /// How many runs are in flight right now; the queue promises at most one.
  int concurrentRuns = 0;

  /// The highest [concurrentRuns] ever observed.
  int peakConcurrentRuns = 0;

  /// Fires once for every job the worker starts.
  Stream<String> get started => _started.stream;

  /// Queues a job named [id], with its own name as the private plan.
  _FakeJob enqueue(String id) => admit(
    _FakeJob(id: id, deviceId: 'device', status: _FakeStatus.queued),
    id,
    logFields: <String>['plan=$id'],
  );

  /// Lets every held run — and every run still to start — finish at once.
  ///
  /// Sticky on purpose: a test that releases before the pump has even picked
  /// the job up would otherwise wait forever for a gate that did not exist
  /// yet.
  void releaseAll() {
    _released = true;
    for (final gate in _gates) {
      if (!gate.isCompleted) {
        gate.complete();
      }
    }
    _gates.clear();
  }

  @override
  _FakeJob markCancelled(_FakeJob current) =>
      current.copyWith(status: _FakeStatus.cancelled);

  @override
  Future<void> runJob(
    _FakeJob job,
    String plan,
    CancellationToken token,
  ) async {
    ranJobIds.add(job.id);
    tokens.add(token);
    concurrentRuns++;
    peakConcurrentRuns = concurrentRuns > peakConcurrentRuns
        ? concurrentRuns
        : peakConcurrentRuns;
    updateJob(
      job.id,
      (current) => current.copyWith(status: _FakeStatus.running),
    );
    final gate = Completer<void>();
    if (_released) {
      gate.complete();
    } else {
      _gates.add(gate);
    }
    _started.add(job.id);
    try {
      await gate.future;
      if (!token.isCancelled) {
        storeJob(requireJob(job.id).copyWith(status: _FakeStatus.completed));
      }
    } finally {
      concurrentRuns--;
    }
  }
}
