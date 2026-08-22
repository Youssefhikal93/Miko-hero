import 'dart:async';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/generation/story_library_writer.dart';
import 'package:iam_hero_bridge/src/generation/story_prompt.dart';
import 'package:uuid/uuid.dart';

/// Sink for privacy-safe generation log lines.
///
/// Only job ids, statuses, timings and typed error codes are ever passed to
/// it — never prompts, story text, child names or model output.
typedef GenerationLogSink = void Function(String message);

/// How many finished jobs stay readable before the oldest are dropped.
const int maxRetainedFinishedJobs = 100;

/// Runs story generation jobs strictly one at a time.
///
/// The machine has one small GPU, so concurrency is not a tuning knob: a
/// single worker drains a FIFO queue and every other job waits with a
/// reported queue position. Jobs live in memory only — the durable queue is
/// the app's, and a bridge restart is meant to clear in-flight work.
class StoryGenerationQueue {
  /// Creates a queue.
  ///
  /// [client] is the Ollama seam replaced by tests, [writer] performs the
  /// transactional library write, and [log] receives content-free progress
  /// lines.
  StoryGenerationQueue({
    required this._config,
    required this._writer,
    this._client = const IoOllamaStoryClient(),
    this._uuid = const Uuid(),
    DateTime Function()? clock,
    GenerationLogSink? log,
  }) : _clock = clock ?? DateTime.now,
       _log = log ?? _ignoreLog;

  /// Runtime configuration: Ollama URL, model, timeout and attempt budget.
  final BridgeConfig _config;

  /// Transactional writer used once a draft passes validation.
  final StoryLibraryWriter _writer;

  /// The mocked-in-tests Ollama boundary.
  final OllamaStoryClient _client;

  final Uuid _uuid;
  final DateTime Function() _clock;
  final GenerationLogSink _log;

  final Map<String, GenerationJob> _jobs = <String, GenerationJob>{};
  final List<String> _pending = <String>[];
  final Map<String, CancellationToken> _tokens = <String, CancellationToken>{};
  final Map<String, Completer<GenerationJob>> _settled =
      <String, Completer<GenerationJob>>{};
  final List<String> _finishedOrder = <String>[];

  String? _activeJobId;
  bool _pumping = false;

  /// Accepts [request] on behalf of [deviceId] and returns the queued job.
  ///
  /// The worker is started on a later microtask, so the returned snapshot is
  /// always `queued` and its queue position is stable for the response.
  GenerationJob enqueue({
    required String deviceId,
    required StoryGenerationRequest request,
  }) {
    final now = _clock().toUtc();
    final job = GenerationJob(
      id: _uuid.v4(),
      deviceId: deviceId,
      request: request,
      status: GenerationJobStatus.queued,
      createdAtUtc: now,
      updatedAtUtc: now,
      progress: 'Waiting for the local model.',
    );
    _jobs[job.id] = job;
    _pending.add(job.id);
    _tokens[job.id] = CancellationToken();
    _settled[job.id] = Completer<GenerationJob>();
    _log('job ${job.id} queued position=${queuePosition(job.id)}');
    scheduleMicrotask(() => unawaited(_pump()));
    return job;
  }

  /// Returns the current snapshot of [jobId], or `null` when unknown.
  GenerationJob? job(String jobId) => _jobs[jobId];

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
  /// A queued job is removed from the line; the running job has its Ollama
  /// call aborted and never reaches persistence. Terminal jobs are returned
  /// unchanged.
  GenerationJob cancel(String jobId) {
    final current = _jobs[jobId];
    if (current == null) {
      throw StateError('Unknown generation job.');
    }
    if (current.status.isTerminal) {
      return current;
    }
    _pending.remove(jobId);
    final cancelled = current.copyWith(
      status: GenerationJobStatus.cancelled,
      updatedAtUtc: _clock().toUtc(),
      progress: 'Cancelled.',
    );
    _jobs[jobId] = cancelled;
    _tokens[jobId]?.cancel();
    _log('job $jobId cancelled');
    if (_activeJobId != jobId) {
      // Nothing is running it, so no worker will ever settle it.
      _settle(cancelled);
    }
    return cancelled;
  }

  /// Completes once [jobId] has reached a terminal state and its worker has
  /// stopped touching the library.
  Future<GenerationJob> whenSettled(String jobId) {
    final completer = _settled[jobId];
    if (completer != null) {
      return completer.future;
    }
    final finished = _jobs[jobId];
    if (finished != null && finished.status.isTerminal) {
      return Future<GenerationJob>.value(finished);
    }
    return Future<GenerationJob>.error(
      StateError('Unknown generation job.'),
      StackTrace.current,
    );
  }

  /// Cancels every unfinished job; used when the bridge shuts down.
  void shutdown() {
    for (final id in <String>[..._pending, ...?_activeIds()]) {
      final current = _jobs[id];
      if (current != null && !current.status.isTerminal) {
        cancel(id);
      }
    }
  }

  Iterable<String>? _activeIds() {
    final active = _activeJobId;
    return active == null ? null : <String>[active];
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
    final request = _jobs[jobId]!.request;
    final attempts = _config.maxGenerationAttempts;
    GenerationFailure? failure;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (token.isCancelled) {
        _settleCancelled(jobId, start);
        return;
      }
      _transition(
        jobId,
        status: GenerationJobStatus.generating,
        progress: 'Writing the story (attempt $attempt of $attempts).',
      );
      _log('job $jobId generating attempt=$attempt/$attempts');
      try {
        final response = await _callOllama(request, token);
        if (token.isCancelled) {
          _settleCancelled(jobId, start);
          return;
        }
        _transition(
          jobId,
          status: GenerationJobStatus.validating,
          progress: 'Checking the story.',
        );
        final draft = parseStoryDraft(
          readOllamaResponseText(response.bodyText),
          expectedPageCount: request.pageCount,
        );
        if (token.isCancelled) {
          _settleCancelled(jobId, start);
          return;
        }
        final GeneratedStory story = _writer.writeStory(
          request: request,
          draft: draft,
          nowUtc: _clock().toUtc(),
        );
        _complete(jobId, story, start);
        return;
      } on GenerationException catch (error) {
        if (token.isCancelled) {
          _settleCancelled(jobId, start);
          return;
        }
        failure = error.toFailure();
        _log('job $jobId attempt=$attempt error=${error.code.wireCode}');
        if (error.code == GenerationFailureCode.invalidModelOutput &&
            attempt < attempts) {
          continue;
        }
        break;
      } catch (_) {
        if (token.isCancelled) {
          _settleCancelled(jobId, start);
          return;
        }
        // Details are dropped on purpose: they can quote model output.
        failure = const GenerationFailure(
          code: GenerationFailureCode.internalError,
          message: 'The bridge failed unexpectedly while generating.',
        );
        break;
      }
    }

    _fail(
      jobId,
      failure ??
          const GenerationFailure(
            code: GenerationFailureCode.internalError,
            message: 'The bridge failed unexpectedly while generating.',
          ),
      start,
    );
  }

  Future<OllamaGenerateResponse> _callOllama(
    StoryGenerationRequest request,
    CancellationToken token,
  ) async {
    final call = OllamaGenerateRequest(
      baseUrl: _config.ollamaBaseUrl,
      model: _config.ollamaModel,
      prompt: buildStoryPrompt(request),
      format: storyResponseSchema(request.pageCount),
      timeout: _config.generationTimeout,
    );
    final OllamaGenerateResponse response;
    try {
      response = await _client.generate(call, cancellation: token);
    } on GenerationException {
      rethrow;
    } on TimeoutException {
      throw GenerationException(
        GenerationFailureCode.ollamaTimeout,
        'Ollama did not finish within '
        '${_config.generationTimeout.inMinutes} minutes.',
      );
    } catch (_) {
      throw const GenerationException(
        GenerationFailureCode.ollamaUnavailable,
        'The local Ollama server could not be reached.',
      );
    }
    if (response.statusCode != 200) {
      throw GenerationException(
        GenerationFailureCode.ollamaUnavailable,
        'Ollama answered HTTP ${response.statusCode}.',
      );
    }
    return response;
  }

  void _transition(
    String jobId, {
    required GenerationJobStatus status,
    required String progress,
  }) {
    final current = _jobs[jobId];
    if (current == null || current.status.isTerminal) {
      return;
    }
    _jobs[jobId] = current.copyWith(
      status: status,
      progress: progress,
      updatedAtUtc: _clock().toUtc(),
    );
  }

  void _complete(String jobId, GeneratedStory story, DateTime start) {
    final current = _jobs[jobId]!;
    final finished = current.copyWith(
      status: GenerationJobStatus.completed,
      progress: 'Story ready.',
      updatedAtUtc: _clock().toUtc(),
      story: story,
    );
    _jobs[jobId] = finished;
    _log('job $jobId completed in ${_elapsedMs(start)} ms');
    _settle(finished);
  }

  void _fail(String jobId, GenerationFailure failure, DateTime start) {
    final current = _jobs[jobId]!;
    final finished = current.copyWith(
      status: GenerationJobStatus.failed,
      progress: 'Generation failed.',
      updatedAtUtc: _clock().toUtc(),
      failure: failure,
    );
    _jobs[jobId] = finished;
    _log(
      'job $jobId failed code=${failure.code.wireCode} '
      'after ${_elapsedMs(start)} ms',
    );
    _settle(finished);
  }

  void _settleCancelled(String jobId, DateTime start) {
    final current = _jobs[jobId]!;
    _log('job $jobId stopped after ${_elapsedMs(start)} ms');
    _settle(current);
  }

  void _settle(GenerationJob job) {
    _tokens.remove(job.id);
    final completer = _settled.remove(job.id);
    if (completer != null && !completer.isCompleted) {
      completer.complete(job);
    }
    _finishedOrder.add(job.id);
    while (_finishedOrder.length > maxRetainedFinishedJobs) {
      _jobs.remove(_finishedOrder.removeAt(0));
    }
  }

  int _elapsedMs(DateTime start) =>
      _clock().toUtc().difference(start).inMilliseconds;

  static void _ignoreLog(String message) {
    // Logging is opt-in; the bridge stays silent unless a sink is wired.
  }
}
