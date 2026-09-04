import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/hero_name_spelling.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Suggests how one child's name is written in each story language.
///
/// One model call, one schema, four short strings. Nothing is stored: the
/// answer goes straight back to the profile editor, where the parent confirms
/// or corrects it before it becomes part of the child's profile on the device.
/// The bridge is deliberately not the owner of a child's name spellings — the
/// family is — so there is no row here and no cache.
///
/// **The card.** Like `HeroSheetService`, the pass is an Ollama tenant and
/// takes its turn through the shared [GpuGate], so it can never load the writer
/// while ComfyUI is mid-render. It is its own tenant object because the gate
/// compares tenants by identity; the model it loads is the *story* model, and
/// that is what its eviction unloads.
///
/// **The name never reaches a log line.** Every message this class emits is a
/// verdict — suggested, unavailable — and the one thing the call is about is a
/// child's given name.
class HeroNameSpellingService {
  /// Creates a service.
  ///
  /// [client] is the same Ollama seam the story queue uses, [gate] must be the
  /// shared one-GPU gate, and [log] receives content-free lines only.
  HeroNameSpellingService({
    required this._config,
    this._client = const IoOllamaStoryClient(),
    GpuGate? gate,
    JobLogSink? log,
  }) : _gate = gate ?? GpuGate(),
       _log = log ?? _ignoreLog;

  final BridgeConfig _config;
  final OllamaStoryClient _client;
  final GpuGate _gate;
  final JobLogSink _log;

  /// This service's identity at the gate, and the thing the gate evicts.
  late final _SpellingTenant _tenant = _SpellingTenant(
    config: _config,
    client: _client,
    log: _log,
  );

  /// Spells [heroName] in every story language, or throws trying.
  ///
  /// [gender] is optional context — some names are written differently for a
  /// girl and a boy — and is left out of the prompt entirely when absent.
  ///
  /// Throws a [GenerationException] when the local model is unreachable, too
  /// slow, or answered something that is not four names. There is no partial
  /// answer: the editor either fills all four boxes or leaves them to the
  /// parent.
  Future<Map<StoryLanguage, String>> suggest({
    required String heroName,
    StoryGenderContext? gender,
  }) async {
    final Map<StoryLanguage, String> spellings = await _gate.run(
      _tenant,
      () => _ask(heroName, gender),
    );
    _log('name spellings suggested');
    return spellings;
  }

  Future<Map<StoryLanguage, String>> _ask(
    String heroName,
    StoryGenderContext? gender,
  ) async {
    final OllamaGenerateResponse response;
    try {
      response = await _client.generate(
        _config.nameSpelling.generateRequest(
          prompt: buildHeroNameSpellingPrompt(
            heroName: heroName,
            gender: gender,
          ),
          format: heroNameSpellingResponseSchema(),
        ),
        // Nothing cancels this from outside: it is bounded by the target's own
        // fifteen-second budget, well inside the request that is waiting on it.
        cancellation: CancellationToken(),
      );
    } on GenerationException {
      rethrow;
    } catch (_) {
      // Every transport cause collapses into one verdict; the detail could
      // name a local address or quote a response body.
      _log('name spellings unavailable');
      throw const GenerationException(
        GenerationFailureCode.ollamaUnavailable,
        'The local Ollama server could not spell the name in time.',
      );
    }
    if (response.statusCode != 200) {
      _log('name spellings unavailable');
      throw GenerationException(
        GenerationFailureCode.ollamaUnavailable,
        'Ollama answered HTTP ${response.statusCode}.',
      );
    }
    return parseHeroNameSpellings(readOllamaResponseText(response.bodyText));
  }

  static void _ignoreLog(String message) {
    // Logging is opt-in; the bridge stays silent unless a sink is wired.
  }
}

/// The spelling pass's claim on the GPU, as the gate sees it.
///
/// Its own tenant object, because the gate tells tenants apart by identity and
/// this one is not the story queue. What it unloads is the story model, since
/// that is the model the pass loads.
class _SpellingTenant implements GpuTenant {
  const _SpellingTenant({
    required this._config,
    required this._client,
    required this._log,
  });

  final BridgeConfig _config;
  final OllamaStoryClient _client;
  final JobLogSink _log;

  @override
  String get name => 'ollama-spelling';

  @override
  Future<void> evict() async {
    try {
      await _client.unload(_config.ollama.unloadRequest());
      _log('spelling model unloaded');
    } catch (_) {
      // Swallowed rather than rethrown so the log says which local service
      // failed; the gate's own net would only be able to say the tenant name.
      _log('spelling unload failed');
    }
  }
}
