import 'dart:async';

import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_queue.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_errors.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_job.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_renderer.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:uuid/uuid.dart';

/// How many finished illustration jobs stay readable before the oldest go.
const int maxRetainedFinishedIllustrationJobs = 100;

/// Runs illustration jobs strictly one at a time, and never while a story is
/// being written.
///
/// The queue is the story queue's twin — FIFO, one worker, in-memory jobs,
/// content-free logs, a retained-job cap — with two differences that come
/// from what it renders. It holds a [GpuGate] lease for each individual
/// page rather than for a whole job, so a story that was queued behind a
/// ten-page book waits for one page instead of ten; and a page that fails
/// does not fail the book, it just marks its own row `failed` and lets the
/// remaining pages carry on.
///
/// A job with a reference photo runs one extra render before its first page:
/// the photo is redrawn as a storybook portrait, and that portrait — never the
/// photo — is what the pages use as their face reference. It takes a lease of
/// its own, on the same terms as a page.
class IllustrationQueue {
  /// Creates a queue.
  ///
  /// [client] is the ComfyUI seam replaced by tests, [gate] is the shared
  /// one-GPU lock (pass the same instance as the story queue), and [log]
  /// receives content-free progress lines.
  factory IllustrationQueue({
    required BridgeConfig config,
    required MasterLibrary library,
    ComfyUiClient client = const IoComfyUiClient(),
    GpuGate? gate,
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
    GenerationLogSink? log,
    Duration? pollInterval,
  }) {
    // The queue and its renderer read and write the same rows, so they share
    // one repository rather than each building an equivalent copy.
    final repository = IllustrationRepository(library: library);
    return IllustrationQueue._(
      repository: repository,
      renderer: IllustrationRenderer(
        config: config,
        library: library,
        client: client,
        repository: repository,
        photoStore: ProfilePhotoStore(library: library),
        clock: clock,
        pollInterval: pollInterval,
      ),
      gate: gate ?? GpuGate(),
      uuid: uuid,
      clock: clock ?? DateTime.now,
      log: log ?? _ignoreLog,
    );
  }

  IllustrationQueue._({
    required this._repository,
    required this._renderer,
    required this._gate,
    required this._uuid,
    required this._clock,
    required this._log,
  });

  final IllustrationRepository _repository;
  final IllustrationRenderer _renderer;
  final GpuGate _gate;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final GenerationLogSink _log;

  final Map<String, IllustrationJob> _jobs = <String, IllustrationJob>{};
  final Map<String, _RenderPlan> _plans = <String, _RenderPlan>{};
  final List<String> _pending = <String>[];
  final Map<String, CancellationToken> _tokens = <String, CancellationToken>{};
  final Map<String, Completer<IllustrationJob>> _settled =
      <String, Completer<IllustrationJob>>{};
  final List<String> _finishedOrder = <String>[];

  String? _activeJobId;
  bool _pumping = false;

  /// Queues every page of [storyId] that still needs an image.
  ///
  /// Returns `null` when no such story exists, so the caller can answer a
  /// typed `404`. Pages that are already `completed` are skipped, which is
  /// what makes a second call after a partial failure cheap. A story whose
  /// pages are all done still produces a job — one that finishes
  /// immediately with a page count of zero.
  IllustrationJob? enqueue({
    required String deviceId,
    required String storyId,
    required StoryIllustrationStyle style,
    required StoryGenderContext? gender,
  }) {
    final targets = _repository.readTargets(storyId);
    if (targets == null) {
      return null;
    }
    final now = _clock().toUtc();
    final job = IllustrationJob(
      id: _uuid.v4(),
      deviceId: deviceId,
      storyId: storyId,
      pageCount: targets.pending.length,
      status: IllustrationJobStatus.queued,
      createdAtUtc: now,
      updatedAtUtc: now,
      progress: targets.pending.isEmpty
          ? 'Every page already has a picture.'
          : 'Waiting for the local renderer.',
    );
    _jobs[job.id] = job;
    _plans[job.id] = _RenderPlan(
      targets: targets,
      style: style,
      gender: gender,
    );
    _pending.add(job.id);
    _tokens[job.id] = CancellationToken();
    _settled[job.id] = Completer<IllustrationJob>();
    _log(
      'illustration job ${job.id} queued pages=${job.pageCount} '
      'position=${queuePosition(job.id)}',
    );
    scheduleMicrotask(() => unawaited(_pump()));
    return job;
  }

  /// Returns the current snapshot of [jobId], or `null` when unknown.
  IllustrationJob? job(String jobId) => _jobs[jobId];

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
  /// A queued job leaves the line at once. The running job stops after the
  /// page it is currently rendering: interrupting mid-image would waste the
  /// minute already spent on it and leave ComfyUI holding the card.
  IllustrationJob cancel(String jobId) {
    final current = _jobs[jobId];
    if (current == null) {
      throw StateError('Unknown illustration job.');
    }
    if (current.status.isTerminal) {
      return current;
    }
    _pending.remove(jobId);
    final cancelled = current.copyWith(
      status: IllustrationJobStatus.cancelled,
      updatedAtUtc: _clock().toUtc(),
      progress: 'Cancelled.',
    );
    _jobs[jobId] = cancelled;
    _tokens[jobId]?.cancel();
    _log('illustration job $jobId cancelled');
    if (_activeJobId != jobId) {
      // Nothing is running it, so no worker will ever settle it.
      _settle(cancelled);
    }
    return cancelled;
  }

  /// Completes once [jobId] has reached a terminal state and its worker has
  /// stopped touching the library.
  Future<IllustrationJob> whenSettled(String jobId) {
    final completer = _settled[jobId];
    if (completer != null) {
      return completer.future;
    }
    final finished = _jobs[jobId];
    if (finished != null && finished.status.isTerminal) {
      return Future<IllustrationJob>.value(finished);
    }
    return Future<IllustrationJob>.error(
      StateError('Unknown illustration job.'),
      StackTrace.current,
    );
  }

  /// Cancels every unfinished job; used when the bridge shuts down.
  void shutdown() {
    for (final id in <String>[..._pending, ?_activeJobId]) {
      final current = _jobs[id];
      if (current != null && !current.status.isTerminal) {
        cancel(id);
      }
    }
  }

  Future<void> _pump() async {
    if (_pumping) {
      return;
    }
    _pumping = true;
    try {
      while (_pending.isNotEmpty) {
        final id = _pending.removeAt(0);
        final job = _jobs[id];
        if (job == null || job.status.isTerminal) {
          continue;
        }
        _activeJobId = id;
        try {
          await _runJob(id);
        } finally {
          _activeJobId = null;
        }
      }
    } finally {
      _pumping = false;
    }
  }

  Future<void> _runJob(String jobId) async {
    final start = _clock().toUtc();
    final token = _tokens[jobId] ?? CancellationToken();
    final plan = _plans.remove(jobId)!;
    final pages = plan.targets.pending;

    if (token.isCancelled) {
      _settleCancelled(jobId, start);
      return;
    }
    if (pages.isEmpty) {
      _finish(jobId, start, progress: 'Every page already has a picture.');
      return;
    }
    if (!await _renderer.isComfyUiReachable()) {
      // Not one page's fault: leave every row exactly as it was so the next
      // attempt still sees them as work to do rather than as failures.
      _fail(
        jobId,
        const IllustrationFailure(
          code: IllustrationFailureCode.comfyUiUnavailable,
          message: 'The local ComfyUI server could not be reached.',
        ),
        start,
      );
      return;
    }

    final String? photoImageName = await _renderer.uploadReferencePhoto(
      plan.targets.profileId,
    );
    String? referenceImageName;
    if (photoImageName != null) {
      if (token.isCancelled) {
        _settleCancelled(jobId, start);
        return;
      }
      // Stage one, once per job: redraw the photo as a storybook portrait so
      // the face adapter reads a drawing rather than a photograph. It is a
      // full render on the same card, so it takes the same one-GPU lease a
      // page takes — a story must never be generated alongside it.
      _transition(
        jobId,
        status: IllustrationJobStatus.rendering,
        // Named for what the parent sees, not for the pass: the wait is real
        // and reporting "waiting for the renderer" through it would be a lie.
        progress: 'Drawing the hero.',
      );
      final GpuLease lease = await _gate.acquire();
      try {
        referenceImageName = await _renderer.renderStylizedReference(
          storyId: plan.targets.storyId,
          photoImageName: photoImageName,
          style: plan.style,
          gender: plan.gender,
        );
      } finally {
        lease.release();
      }
    }
    _log(
      'illustration job $jobId rendering pages=${pages.length} '
      'photo=${photoImageName == null ? 'no' : 'yes'} '
      'reference=${referenceImageName == null ? 'no' : 'stylized'}',
    );

    var completed = 0;
    var failed = 0;
    for (var index = 0; index < pages.length; index++) {
      if (token.isCancelled) {
        _settleCancelled(jobId, start, completed: completed, failed: failed);
        return;
      }
      final target = pages[index];
      _transition(
        jobId,
        status: IllustrationJobStatus.rendering,
        progress: 'Rendering page ${index + 1} of ${pages.length}.',
        completedPageCount: completed,
        failedPageCount: failed,
      );
      // One lease per page: the story queue may slip in between pages, but
      // never alongside one.
      final GpuLease lease = await _gate.acquire();
      try {
        await _renderer.renderPage(
          target: target,
          storyId: plan.targets.storyId,
          style: plan.style,
          gender: plan.gender,
          referenceImageName: referenceImageName,
        );
        completed++;
        _log('illustration job $jobId page=${target.pageIndex} rendered');
      } on IllustrationException catch (error) {
        failed++;
        _markFailed(jobId, plan.targets.storyId, target.illustrationId);
        _log(
          'illustration job $jobId page=${target.pageIndex} '
          'error=${error.code.wireCode}',
        );
      } catch (_) {
        failed++;
        _markFailed(jobId, plan.targets.storyId, target.illustrationId);
        // Details are dropped on purpose: they can quote scene text.
        _log(
          'illustration job $jobId page=${target.pageIndex} '
          'error=${IllustrationFailureCode.internalError.wireCode}',
        );
      } finally {
        lease.release();
      }
    }

    if (token.isCancelled) {
      _settleCancelled(jobId, start, completed: completed, failed: failed);
      return;
    }
    if (completed == 0) {
      _fail(
        jobId,
        const IllustrationFailure(
          code: IllustrationFailureCode.comfyUiFailed,
          message: 'No page of this story could be illustrated.',
        ),
        start,
        completed: completed,
        failed: failed,
      );
      return;
    }
    _finish(
      jobId,
      start,
      progress: failed == 0
          ? 'All $completed pages illustrated.'
          : '$completed of ${pages.length} pages illustrated.',
      completed: completed,
      failed: failed,
    );
  }

  void _markFailed(String jobId, String storyId, String illustrationId) {
    try {
      _repository.markStatus(
        illustrationId: illustrationId,
        storyId: storyId,
        status: failedIllustrationStatus,
        nowUtc: _clock().toUtc(),
      );
    } on Exception catch (_) {
      // The page already failed; a bookkeeping failure on top of it must not
      // take the remaining pages down with it.
      _log('illustration job $jobId status write failed');
    }
  }

  void _transition(
    String jobId, {
    required IllustrationJobStatus status,
    required String progress,
    int? completedPageCount,
    int? failedPageCount,
  }) {
    final current = _jobs[jobId];
    if (current == null || current.status.isTerminal) {
      return;
    }
    _jobs[jobId] = current.copyWith(
      status: status,
      progress: progress,
      updatedAtUtc: _clock().toUtc(),
      completedPageCount: completedPageCount,
      failedPageCount: failedPageCount,
    );
  }

  void _finish(
    String jobId,
    DateTime start, {
    required String progress,
    int completed = 0,
    int failed = 0,
  }) {
    final current = _jobs[jobId]!;
    if (current.status.isTerminal) {
      // Cancelled while this worker was between awaits. Cancellation is the
      // decision the parent made; it must not be overwritten by an outcome.
      _settleCancelled(jobId, start, completed: completed, failed: failed);
      return;
    }
    final finished = current.copyWith(
      status: IllustrationJobStatus.completed,
      progress: progress,
      updatedAtUtc: _clock().toUtc(),
      completedPageCount: completed,
      failedPageCount: failed,
    );
    _jobs[jobId] = finished;
    _log(
      'illustration job $jobId completed pages=$completed failed=$failed '
      'in ${_elapsedMs(start)} ms',
    );
    _settle(finished);
  }

  void _fail(
    String jobId,
    IllustrationFailure failure,
    DateTime start, {
    int completed = 0,
    int failed = 0,
  }) {
    final current = _jobs[jobId]!;
    if (current.status.isTerminal) {
      _settleCancelled(jobId, start, completed: completed, failed: failed);
      return;
    }
    final finished = current.copyWith(
      status: IllustrationJobStatus.failed,
      progress: 'Illustration failed.',
      updatedAtUtc: _clock().toUtc(),
      completedPageCount: completed,
      failedPageCount: failed,
      failure: failure,
    );
    _jobs[jobId] = finished;
    _log(
      'illustration job $jobId failed code=${failure.code.wireCode} '
      'after ${_elapsedMs(start)} ms',
    );
    _settle(finished);
  }

  void _settleCancelled(
    String jobId,
    DateTime start, {
    int completed = 0,
    int failed = 0,
  }) {
    final current = _jobs[jobId]!.copyWith(
      completedPageCount: completed,
      failedPageCount: failed,
    );
    _jobs[jobId] = current;
    _log(
      'illustration job $jobId stopped pages=$completed '
      'after ${_elapsedMs(start)} ms',
    );
    _settle(current);
  }

  void _settle(IllustrationJob job) {
    _tokens.remove(job.id);
    _plans.remove(job.id);
    final completer = _settled.remove(job.id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(job);
    }
    _finishedOrder.add(job.id);
    while (_finishedOrder.length > maxRetainedFinishedIllustrationJobs) {
      _jobs.remove(_finishedOrder.removeAt(0));
    }
  }

  int _elapsedMs(DateTime start) =>
      _clock().toUtc().difference(start).inMilliseconds;

  static void _ignoreLog(String message) {
    // Logging is opt-in; the bridge stays silent unless a sink is wired.
  }
}

/// Everything one queued job needs, kept out of the public snapshot.
///
/// The scene descriptions in here are story content and must never be
/// serialized into a job status response.
class _RenderPlan {
  const _RenderPlan({
    required this.targets,
    required this.style,
    required this.gender,
  });

  final StoryIllustrationTargets targets;
  final StoryIllustrationStyle style;
  final StoryGenderContext? gender;
}
