import 'dart:async';

import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/language_purity.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/generation/story_library_writer.dart';
import 'package:iam_hero_bridge/src/generation/story_outline.dart';
import 'package:iam_hero_bridge/src/generation/story_prompt.dart';
import 'package:uuid/uuid.dart';

/// Runs story generation jobs strictly one at a time.
///
/// The line itself — admission, positions, cancellation, retention, the
/// single worker — is [JobQueue]. What is particular to writing a story
/// lives here: the whole-job GPU turn, the shared attempt budget across both
/// model passes, and the Ollama tenant the gate evicts once the turn is over.
class StoryGenerationQueue
    extends JobQueue<GenerationJob, StoryGenerationRequest> {
  /// Creates a queue.
  ///
  /// [client] is the Ollama seam replaced by tests, [writer] performs the
  /// transactional library write, [gate] is the shared one-GPU lock (pass
  /// the same instance as the illustration queue), and [log] receives
  /// content-free progress lines.
  StoryGenerationQueue({
    required this._config,
    required this._writer,
    this._client = const IoOllamaStoryClient(),
    this._uuid = const Uuid(),
    GpuGate? gate,
    super.clock,
    super.log,
  }) : _gate = gate ?? GpuGate(),
       super(jobLabel: 'job', unknownJobMessage: 'Unknown generation job.');

  /// Runtime configuration: Ollama URL, model, timeout and attempt budget.
  final BridgeConfig _config;

  /// Transactional writer used once a draft passes validation.
  final StoryLibraryWriter _writer;

  /// The mocked-in-tests Ollama boundary.
  final OllamaStoryClient _client;

  /// Shared lock over the machine's single GPU.
  ///
  /// Held for the whole run of a job, so an illustration job queued while a
  /// story is being written waits for the story instead of fighting it for
  /// the same 4 GB of VRAM.
  final GpuGate _gate;

  /// This queue's identity at the gate, and the thing the gate evicts.
  late final _OllamaTenant _tenant = _OllamaTenant(
    config: _config,
    client: _client,
    log: logLine,
  );

  final Uuid _uuid;

  /// Accepts [request] on behalf of [deviceId] and returns the queued job.
  ///
  /// The worker is started on a later microtask, so the returned snapshot is
  /// always `queued` and its queue position is stable for the response.
  GenerationJob enqueue({
    required String deviceId,
    required StoryGenerationRequest request,
  }) {
    final now = nowUtc();
    return admit(
      GenerationJob(
        id: _uuid.v4(),
        deviceId: deviceId,
        request: request,
        status: GenerationJobStatus.queued,
        createdAtUtc: now,
        updatedAtUtc: now,
        progress: 'Waiting for the local model.',
      ),
      request,
    );
  }

  @override
  GenerationJob markCancelled(GenerationJob current) {
    return current.copyWith(
      status: GenerationJobStatus.cancelled,
      updatedAtUtc: nowUtc(),
      progress: 'Cancelled.',
    );
  }

  /// Takes one whole turn on the GPU for the job, then reports it settled.
  ///
  /// A story is one indivisible turn on the card: splitting the two passes
  /// would let a ten-page render slip between the plan and the pages and
  /// leave the model half-loaded across it. Unloading the model is not this
  /// queue's business: the gate evicts [_tenant] on the way out, so the card
  /// is clear before anything else is allowed to start. The job is reported
  /// settled as soon as the worker has stopped touching the library, which is
  /// what [whenSettled] promises — the unload happens behind it, still inside
  /// the turn.
  @override
  Future<void> runJob(
    GenerationJob job,
    StoryGenerationRequest plan,
    CancellationToken token,
  ) async {
    await _gate.run(_tenant, () async {
      try {
        await _runJobOnGpu(job.id, plan, token);
      } finally {
        settleIfTerminal(job.id);
      }
    });
  }

  /// Runs one job's attempts, both passes, inside the held GPU lease.
  ///
  /// Every attempt is one whole story: the outline pass runs only until an
  /// outline has been accepted, and from then on each retry re-sends that same
  /// approved outline. Both passes therefore share one attempt counter — a job
  /// with the default `maxGenerationAttempts` of 3 makes at most four model
  /// calls (one outline plus three page passes), and an outline the model keeps
  /// getting wrong costs the same three attempts and never reaches pass two.
  Future<void> _runJobOnGpu(
    String jobId,
    StoryGenerationRequest request,
    CancellationToken token,
  ) async {
    final start = nowUtc();
    final attempts = _config.maxGenerationAttempts;
    GenerationFailure? failure;
    StoryOutline? outline;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      if (token.isCancelled) {
        _logCancelled(jobId, start);
        return;
      }
      try {
        if (outline == null) {
          _transition(
            jobId,
            status: GenerationJobStatus.generating,
            progress: 'Planning the story (attempt $attempt of $attempts).',
          );
          logJob(jobId, 'outlining attempt=$attempt/$attempts');
          final planned = await _callOllama(
            token,
            prompt: buildStoryOutlinePrompt(request),
            format: storyOutlineResponseSchema(request.pageCount),
          );
          if (token.isCancelled) {
            _logCancelled(jobId, start);
            return;
          }
          final parsed = parseStoryOutline(
            readOllamaResponseText(planned.bodyText),
            expectedPageCount: request.pageCount,
          );
          _requirePureLanguage(request, <String>[
            parsed.title,
            for (final beat in parsed.beats) beat.summary,
          ]);
          outline = parsed;
        }
        _transition(
          jobId,
          status: GenerationJobStatus.generating,
          progress: 'Writing the story (attempt $attempt of $attempts).',
        );
        logJob(jobId, 'generating attempt=$attempt/$attempts');
        final response = await _callOllama(
          token,
          prompt: buildStoryPagesPrompt(request, outline),
          format: storyResponseSchema(request.pageCount),
        );
        if (token.isCancelled) {
          _logCancelled(jobId, start);
          return;
        }
        _transition(
          jobId,
          status: GenerationJobStatus.validating,
          progress: 'Checking the story.',
        );
        final parsedDraft = parseStoryDraft(
          readOllamaResponseText(response.bodyText),
          expectedPageCount: request.pageCount,
        );
        _requirePureLanguage(request, <String>[
          parsedDraft.title,
          for (final page in parsedDraft.pages) page.text,
        ]);
        final draft = withHeroAppearance(parsedDraft, outline.heroAppearance);
        if (token.isCancelled) {
          _logCancelled(jobId, start);
          return;
        }
        final GeneratedStory story = _writer.writeStory(
          request: request,
          draft: draft,
          nowUtc: nowUtc(),
        );
        _complete(jobId, story, start);
        return;
      } on GenerationException catch (error) {
        if (token.isCancelled) {
          _logCancelled(jobId, start);
          return;
        }
        failure = error.toFailure();
        logJob(jobId, 'attempt=$attempt error=${error.code.wireCode}');
        if (error.code == GenerationFailureCode.invalidModelOutput &&
            attempt < attempts) {
          continue;
        }
        break;
      } catch (_) {
        if (token.isCancelled) {
          _logCancelled(jobId, start);
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

  /// Refuses a model answer that is not written in the requested script.
  ///
  /// Defense in depth behind the prompt, and deliberately reported as invalid
  /// model output so it consumes a retry exactly like a wrong page count. The
  /// message carries counts only, never a word of the story.
  void _requirePureLanguage(
    StoryGenerationRequest request,
    Iterable<String> texts,
  ) {
    final verdict = checkLanguagePurity(
      language: request.language,
      texts: texts,
    );
    final String? failure = verdict.failure;
    if (failure != null) {
      throw GenerationException(
        GenerationFailureCode.invalidModelOutput,
        failure,
      );
    }
  }

  Future<OllamaGenerateResponse> _callOllama(
    CancellationToken token, {
    required String prompt,
    required Map<String, Object?> format,
  }) async {
    final call = _config.ollama.generateRequest(prompt: prompt, format: format);
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
    updateJob(
      jobId,
      (current) => current.copyWith(
        status: status,
        progress: progress,
        updatedAtUtc: nowUtc(),
      ),
    );
  }

  void _complete(String jobId, GeneratedStory story, DateTime start) {
    storeJob(
      requireJob(jobId).copyWith(
        status: GenerationJobStatus.completed,
        progress: 'Story ready.',
        updatedAtUtc: nowUtc(),
        story: story,
      ),
    );
    logJob(jobId, 'completed in ${elapsedMs(start)} ms');
  }

  void _fail(String jobId, GenerationFailure failure, DateTime start) {
    storeJob(
      requireJob(jobId).copyWith(
        status: GenerationJobStatus.failed,
        progress: 'Generation failed.',
        updatedAtUtc: nowUtc(),
        failure: failure,
      ),
    );
    logJob(
      jobId,
      'failed code=${failure.code.wireCode} after ${elapsedMs(start)} ms',
    );
  }

  /// Logs a job that stopped on the parent's request.
  ///
  /// The snapshot is already `cancelled` — [JobQueue.cancel] wrote it — so
  /// there is nothing left to record but how long the worker ran.
  void _logCancelled(String jobId, DateTime start) {
    logJob(jobId, 'stopped after ${elapsedMs(start)} ms');
  }
}

/// The language model's claim on the GPU, as the gate sees it.
///
/// Ollama keeps a model resident for its keep-alive window after the last
/// token, so "the story is written" and "the card is free" are not the same
/// moment. Eviction is the explicit unload that closes that gap; without it
/// the renderer would find a card that is nominally idle and actually full.
///
/// The job id is deliberately absent from these lines: by the time the gate
/// evicts, the turn is over and the unload belongs to the queue, not to any
/// one story. The request itself comes ready-made from the configuration; the
/// gate's eviction budget bounds the whole call on top of the request's own
/// timeout.
class _OllamaTenant implements GpuTenant {
  const _OllamaTenant({
    required this._config,
    required this._client,
    required this._log,
  });

  final BridgeConfig _config;
  final OllamaStoryClient _client;
  final JobLogSink _log;

  @override
  String get name => 'ollama';

  @override
  Future<void> evict() async {
    try {
      await _client.unload(_config.ollama.unloadRequest());
      _log('Ollama model unloaded');
    } catch (_) {
      // Swallowed rather than rethrown so the log says which local service
      // failed; the gate's own net would only be able to say "ollama".
      _log('Ollama unload failed');
    }
  }
}
