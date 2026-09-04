import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/hero_sheet.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/library/character_sheet_store.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';

/// Owns the per-child character sheet: derives it, caches it, hands it out.
///
/// One photo yields one drawn hero, and that hero appears in every story the
/// child ever gets. The sheet is the durable half of that promise; the other
/// half is the reference portrait's seed, which is derived from the same photo
/// hash and therefore lands on the same face.
///
/// **When the vision pass runs.** Two places, deliberately:
///
/// 1. **When the photo is uploaded or replaced**, as a detached best-effort
///    task started by `PUT /profiles/<id>/photo`. That is the natural moment —
///    the bytes are right there, and the model call is paid for while nobody is
///    waiting for a story. It is detached because an HTTP request has a
///    20-second budget and a vision call does not fit inside it, and it is
///    skipped outright when the GPU is already busy: a book being rendered must
///    not queue behind a nicety.
/// 2. **Lazily at generation time**, from the story queue, before it takes its
///    own turn on the card. This is the guarantee. Whatever step one missed —
///    the bridge was restarted, the GPU was busy, Ollama was down, the library
///    was restored from a backup — is derived here, once, and the story that
///    triggered it already has its sheet.
///
/// Every failure is answered with whatever was already stored, down to `null`.
/// A missing sheet is not an error: it means the outline pass invents the
/// appearance line exactly as it did before any of this existed.
///
/// **The card.** The pass is an Ollama tenant like the story queue is, and
/// takes its turn through the same [GpuGate]. The gate evicts it on the way out
/// — the vision model is unloaded before the card changes hands — so ComfyUI
/// can never start a render while a vision model is still resident in 4 GB.
///
/// Nothing here is ever logged beyond a content-free verdict: not the photo,
/// not the bytes, not one word of the sheet.
class HeroSheetService {
  /// Creates a service.
  ///
  /// [client] is the same Ollama seam the story queue uses, [gate] must be the
  /// shared one-GPU gate, and [log] receives content-free lines only.
  HeroSheetService({
    required this._config,
    required this._store,
    required this._photos,
    this._client = const IoOllamaStoryClient(),
    GpuGate? gate,
    DateTime Function()? clock,
    JobLogSink? log,
  }) : _gate = gate ?? GpuGate(),
       _clock = clock ?? DateTime.now,
       _log = log ?? _ignoreLog;

  final BridgeConfig _config;
  final CharacterSheetStore _store;
  final ProfilePhotoStore _photos;
  final OllamaStoryClient _client;
  final GpuGate _gate;
  final DateTime Function() _clock;
  final JobLogSink _log;

  /// This service's identity at the gate, and the thing the gate evicts.
  ///
  /// A tenant of its own rather than the story queue's, because it can be
  /// pointed at a different model: a PC whose writer is `qwen3.5:9b` and whose
  /// eyes are `gemma3:4b` must have the eyes unloaded, not the writer.
  late final _VisionTenant _tenant = _VisionTenant(
    config: _config,
    client: _client,
    log: _log,
  );

  Future<void> _background = Future<void>.value();

  /// Completes once every background refresh started so far has finished.
  ///
  /// Exists for tests and for an orderly shutdown; no request path waits on it.
  Future<void> get backgroundWork => _background;

  /// The stored sheet of [profileId] without contacting any model.
  HeroCharacterSheet? storedSheet(String profileId) =>
      _store.findSheet(profileId);

  /// Derives the sheet of [profileId] if it is missing or out of date.
  ///
  /// Waits for the card when it has to. Call this **before** taking a turn at
  /// the gate, never inside one: the gate serializes turns, and a caller that
  /// held one while asking for another would be waiting for itself.
  Future<HeroCharacterSheet?> ensureSheet(String profileId) =>
      _ensureSheet(profileId, waitForGpu: true);

  /// Starts a best-effort refresh of [profileId] and returns immediately.
  ///
  /// Used by the photo endpoint, which passes the bytes it has just stored as
  /// [photoBytes]. Handing them over rather than letting the refresh read the
  /// file again means the child's photo is read once, and — on Windows, where
  /// an open file cannot be deleted — that a parent who replaces or removes a
  /// photo immediately afterwards is never blocked by this.
  ///
  /// Nothing depends on the outcome: if it does not happen, [ensureSheet] does
  /// it before the next story.
  void refreshInBackground(String profileId, {Uint8List? photoBytes}) {
    final Future<void> previous = _background;
    _background = () async {
      // Serialized behind whatever is already running, so two quick uploads
      // cannot describe two photos onto one profile at the same time.
      await previous;
      try {
        await _ensureSheet(
          profileId,
          waitForGpu: false,
          photoBytes: photoBytes,
        );
      } catch (_) {
        // Best effort by definition, and the cause could name a file path.
      }
    }();
  }

  Future<HeroCharacterSheet?> _ensureSheet(
    String profileId, {
    required bool waitForGpu,
    Uint8List? photoBytes,
  }) async {
    final HeroCharacterSheet? stored = _store.findSheet(profileId);
    final Uint8List? bytes = photoBytes ?? await _readStoredPhoto(profileId);
    if (bytes == null) {
      // No photo, nothing to look at. An already-drawn hero is kept: the
      // character does not stop existing because a parent removed the photo,
      // and the family's earlier books still show them.
      return stored;
    }
    final String photoHash = sha256HexOfBytes(bytes);
    if (stored != null && stored.photoHash == photoHash) {
      // The cache hit that makes this cheap: the same photo never costs a
      // second model call, however many books the child gets.
      _log('hero sheet unchanged');
      return stored;
    }
    if (!waitForGpu && _gate.isBusy) {
      _log('hero sheet deferred');
      return stored;
    }

    final HeroSheetTraits? traits = await _gate.run(_tenant, () async {
      try {
        return await _describe(bytes);
      } catch (_) {
        // Every cause collapses into "no sheet this time": a transport error, a
        // model that cannot see, a model that answered in the wrong shape. None
        // is worth failing a photo upload or a story over, and the detail could
        // quote model output.
        return null;
      }
    });
    if (traits == null) {
      _log('hero sheet unavailable');
      return stored;
    }

    final DateTime now = _clock().toUtc();
    final HeroCharacterSheet sheet = buildHeroCharacterSheet(
      profileId: profileId,
      traits: traits,
      photoHash: photoHash,
      nowUtc: now,
      previous: stored,
    );
    try {
      _store.saveSheet(sheet);
    } catch (_) {
      // The sheet is still usable for this run even if it could not be
      // persisted; the next run simply derives it again.
      _log('hero sheet write failed');
      return sheet;
    }
    _log(stored == null ? 'hero sheet derived' : 'hero sheet refreshed');
    return sheet;
  }

  /// The bytes of [profileId]'s stored photo, or `null` when there is none.
  ///
  /// An unreadable file answers `null` too: the cause could name a path, and
  /// the outcome is the same either way — no sheet this time.
  Future<Uint8List?> _readStoredPhoto(String profileId) async {
    final ProfileReferencePhoto? photo = _photos.findPhoto(profileId);
    if (photo == null) {
      return null;
    }
    try {
      return await _photos.readPhotoBytes(photo);
    } catch (_) {
      return null;
    }
  }

  Future<HeroSheetTraits> _describe(Uint8List bytes) async {
    final response = await _client.generate(
      _config.vision.generateRequest(
        prompt: buildHeroSheetPrompt(),
        format: heroSheetResponseSchema(),
        images: <String>[base64Encode(bytes)],
      ),
      // Nothing cancels this call from outside: it is bounded by the target's
      // own two-minute budget, and a job that is cancelled while it runs simply
      // stops caring about the answer.
      cancellation: CancellationToken(),
    );
    if (response.statusCode != 200) {
      throw StateError('Ollama answered HTTP ${response.statusCode}.');
    }
    return parseHeroSheetTraits(readOllamaResponseText(response.bodyText));
  }

  static void _ignoreLog(String message) {
    // Logging is opt-in; the bridge stays silent unless a sink is wired.
  }
}

/// The vision model's claim on the GPU, as the gate sees it.
///
/// Its own tenant rather than the story queue's, so the gate always evicts the
/// model that was actually loaded. The two can be the same tag, in which case
/// this is one wasted unload of a model that is about to be loaded again — a
/// second of work against the certainty that a render never starts on a card
/// that still holds a language model.
class _VisionTenant implements GpuTenant {
  const _VisionTenant({
    required this._config,
    required this._client,
    required this._log,
  });

  final BridgeConfig _config;
  final OllamaStoryClient _client;
  final JobLogSink _log;

  @override
  String get name => 'ollama-vision';

  @override
  Future<void> evict() async {
    try {
      await _client.unload(_config.vision.unloadRequest());
      _log('vision model unloaded');
    } catch (_) {
      // Swallowed rather than rethrown so the log says which local service
      // failed; the gate's own net would only be able to say the tenant name.
      _log('vision unload failed');
    }
  }
}
