import 'dart:async';

import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:test/test.dart';

/// A tenant that writes everything it is asked to do into a shared list.
///
/// The list is the whole point: the invariant under test is an *order* —
/// nothing else may touch the card between one tenant's body and its
/// eviction — and an order can only be asserted by recording it.
class _RecordingTenant implements GpuTenant {
  _RecordingTenant(this.name, this.events, {this.onEvict});

  @override
  final String name;

  /// Shared event log, in the order the gate caused things to happen.
  final List<String> events;

  /// Extra behaviour for [evict]: a hang, a throw, or nothing.
  final Future<void> Function()? onEvict;

  @override
  Future<void> evict() async {
    events.add('$name-evict');
    await onEvict?.call();
  }

  /// A body that records its start, awaits [hold] when given, and records its
  /// end.
  Future<String> Function() body({Future<void>? hold}) {
    return () async {
      events.add('$name-run');
      if (hold != null) {
        await hold;
      }
      events.add('$name-done');
      return name;
    };
  }
}

/// Lets the event loop drain so a handover that is already in flight lands.
Future<void> _drain() async {
  for (var tick = 0; tick < 20; tick++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'a different tenant waits for the departing one to be evicted',
    () async {
      final events = <String>[];
      final gate = GpuGate();
      final a = _RecordingTenant('a', events);
      final b = _RecordingTenant('b', events);
      final hold = Completer<void>();

      final first = gate.run(a, a.body(hold: hold.future));
      await _drain();
      final second = gate.run(b, b.body());
      await _drain();
      expect(events, <String>['a-run'], reason: 'b may not start behind a');

      hold.complete();
      await Future.wait<Object?>(<Future<Object?>>[first, second]);

      expect(events, <String>[
        'a-run',
        'a-done',
        'a-evict',
        'b-run',
        'b-done',
        // Nobody left in line: the card goes idle, so b lets go too.
        'b-evict',
      ]);
    },
  );

  test('the eviction finishes before the next tenant is woken', () async {
    final events = <String>[];
    final releaseEviction = Completer<void>();
    final gate = GpuGate();
    final a = _RecordingTenant(
      'a',
      events,
      onEvict: () => releaseEviction.future,
    );
    final b = _RecordingTenant('b', events);

    final first = gate.run(a, a.body());
    await _drain();
    final second = gate.run(b, b.body());
    await _drain();

    expect(events, <String>[
      'a-run',
      'a-done',
      'a-evict',
    ], reason: 'b must wait until the card has actually been freed');
    releaseEviction.complete();
    await Future.wait<Object?>(<Future<Object?>>[first, second]);
    expect(events, <String>[
      'a-run',
      'a-done',
      'a-evict',
      'b-run',
      'b-done',
      'b-evict',
    ]);
  });

  test('the same tenant twice in a row is not evicted in between', () async {
    final events = <String>[];
    final gate = GpuGate();
    final a = _RecordingTenant('a', events);
    final hold = Completer<void>();

    final first = gate.run(a, a.body(hold: hold.future));
    await _drain();
    // Queued while the first turn is still open, so the gate sees the same
    // tenant waiting — a book rendering its second page, not a handover.
    final second = gate.run(a, a.body());
    await _drain();
    hold.complete();
    await Future.wait<Object?>(<Future<Object?>>[first, second]);

    expect(events, <String>[
      'a-run',
      'a-done',
      'a-run',
      'a-done',
      // Once, at the end: the card is going idle and the machine gets its
      // VRAM back.
      'a-evict',
    ]);
  });

  test(
    'an eviction that hangs past the timeout still hands the card on',
    () async {
      final events = <String>[];
      final logged = <String>[];
      final gate = GpuGate(
        evictionTimeout: const Duration(milliseconds: 20),
        log: logged.add,
      );
      final stuck = Completer<void>();
      addTearDown(stuck.complete);
      final a = _RecordingTenant('a', events, onEvict: () => stuck.future);
      final b = _RecordingTenant('b', events);

      final first = gate.run(a, a.body());
      await _drain();
      final second = gate.run(b, b.body());

      await Future.wait<Object?>(<Future<Object?>>[first, second]);
      expect(events, <String>[
        'a-run',
        'a-done',
        'a-evict',
        'b-run',
        'b-done',
        'b-evict',
      ]);
      expect(logged, hasLength(1));
      expect(logged.single, contains('a'));
    },
  );

  test('an eviction that throws still hands the card on', () async {
    final events = <String>[];
    final logged = <String>[];
    final gate = GpuGate(log: logged.add);
    final a = _RecordingTenant(
      'a',
      events,
      onEvict: () => Future<void>.error(StateError('no free call')),
    );
    final b = _RecordingTenant('b', events);

    final first = gate.run(a, a.body());
    await _drain();
    final second = gate.run(b, b.body());

    await Future.wait<Object?>(<Future<Object?>>[first, second]);
    expect(events, <String>[
      'a-run',
      'a-done',
      'a-evict',
      'b-run',
      'b-done',
      'b-evict',
    ]);
    expect(
      logged,
      hasLength(1),
      reason: 'only the failing eviction is worth a line',
    );
  });

  test('a body that throws is still evicted and still hands over', () async {
    final events = <String>[];
    final gate = GpuGate();
    final a = _RecordingTenant('a', events);
    final b = _RecordingTenant('b', events);
    final failure = StateError('the render died');

    // The expectation is attached before the first await on purpose: an
    // errored future nobody is listening to is reported as a crash.
    final Future<void> first = expectLater(
      gate.run<void>(a, () async {
        events.add('a-run');
        throw failure;
      }),
      throwsA(same(failure)),
    );
    await _drain();
    final second = gate.run(b, b.body());

    await first;
    expect(await second, 'b');
    expect(events, <String>['a-run', 'a-evict', 'b-run', 'b-done', 'b-evict']);
  });

  test('three waiters are served first-come-first-served', () async {
    final events = <String>[];
    final gate = GpuGate();
    final a = _RecordingTenant('a', events);
    final b = _RecordingTenant('b', events);
    final c = _RecordingTenant('c', events);
    final hold = Completer<void>();

    final runs = <Future<String>>[gate.run(a, a.body(hold: hold.future))];
    await _drain();
    runs.add(gate.run(b, b.body()));
    await _drain();
    runs.add(gate.run(c, c.body()));
    await _drain();

    hold.complete();
    expect(await Future.wait(runs), <String>['a', 'b', 'c']);
    expect(events.where((event) => event.endsWith('-run')).toList(), <String>[
      'a-run',
      'b-run',
      'c-run',
    ]);
  });

  test('isBusy and waitingCount report the line', () async {
    final events = <String>[];
    final gate = GpuGate();
    final a = _RecordingTenant('a', events);
    final b = _RecordingTenant('b', events);
    final hold = Completer<void>();

    expect(gate.isBusy, isFalse);
    expect(gate.waitingCount, 0);

    final first = gate.run(a, a.body(hold: hold.future));
    await _drain();
    expect(gate.isBusy, isTrue);
    expect(gate.waitingCount, 0);

    final second = gate.run(b, b.body());
    await _drain();
    expect(gate.waitingCount, 1, reason: 'b is in line behind a');

    hold.complete();
    await Future.wait<Object?>(<Future<Object?>>[first, second]);
    expect(gate.isBusy, isFalse);
    expect(gate.waitingCount, 0);
  });
}
