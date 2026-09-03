import 'dart:async';
import 'dart:typed_data';

import 'package:iam_hero_bridge/src/common/atomic_files.dart';
import 'package:iam_hero_bridge/src/common/base_url.dart';
import 'package:iam_hero_bridge/src/common/image_bytes.dart';
import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_errors.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_workflow.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:iam_hero_bridge/src/library/story_deleter.dart';

/// How often the bridge asks ComfyUI whether a render has finished.
///
/// One second is far below the time a 512x512 render takes and far above
/// anything that would busy-poll the local server.
const Duration illustrationPollInterval = Duration(seconds: 1);

/// Longest any single control call to ComfyUI may take.
///
/// Submitting a workflow and reading history are metadata calls: if they
/// have not answered in half a minute, the server is not merely busy.
const Duration illustrationControlTimeout = Duration(seconds: 30);

/// Renders one page image end to end: workflow in, stored PNG out.
///
/// Everything that can go wrong here is converted into a typed
/// [IllustrationException], because the queue above must never have to
/// inspect a transport error — and because a raw error could quote the
/// scene text or a file path, both of which are private content.
class IllustrationRenderer {
  /// Creates a renderer over the ComfyUI seam and the master library.
  IllustrationRenderer({
    required this._config,
    required this._library,
    required this._client,
    required this._repository,
    required this._photoStore,
    DateTime Function()? clock,
    Duration? pollInterval,
  }) : _clock = clock ?? DateTime.now,
       _pollInterval = pollInterval ?? illustrationPollInterval;

  final BridgeConfig _config;
  final MasterLibrary _library;
  final ComfyUiClient _client;
  final IllustrationRepository _repository;
  final ProfilePhotoStore _photoStore;
  final DateTime Function() _clock;
  final Duration _pollInterval;

  /// Endpoint used for short metadata calls.
  ComfyUiEndpoint get _control => ComfyUiEndpoint(
    baseUrl: BaseUrl.parse(_config.comfyUiBaseUrl),
    timeout: _config.illustrationTimeout < illustrationControlTimeout
        ? _config.illustrationTimeout
        : illustrationControlTimeout,
  );

  /// Endpoint used for the two calls that move bytes.
  ComfyUiEndpoint get _transfer => ComfyUiEndpoint(
    baseUrl: BaseUrl.parse(_config.comfyUiBaseUrl),
    timeout: _config.illustrationTimeout,
  );

  /// Whether the local ComfyUI answers at all.
  Future<bool> isComfyUiReachable() => _client.isReachable(_control);

  /// Whether the configured face-detail pass can actually run here.
  ///
  /// Answers `true` when the pass is off — there is nothing to check — and
  /// otherwise asks ComfyUI whether it knows both Impact-Pack nodes the pass
  /// needs. The job engine calls this once, before the first render, so a
  /// missing extension fails the job with one typed error rather than
  /// failing every page or leaving the parent with half a book.
  Future<bool> isFaceDetailAvailable() async {
    if (!_config.illustration.faceDetail.enabled) {
      return true;
    }
    for (final classType in const <String>[
      illustrationFaceDetailerClassType,
      illustrationFaceDetectorClassType,
    ]) {
      if (!await _client.supportsNodeType(_control, classType)) {
        return false;
      }
    }
    return true;
  }

  /// Uploads the reference photo of [profileId], if there is one.
  ///
  /// Returns the name ComfyUI stored it under, or `null` when the child has
  /// no photo — in which case every page renders as plain text-to-image and
  /// the hero simply will not resemble anyone in particular. A failed upload
  /// is also reported as `null` rather than failing the job: a book without
  /// face likeness beats no book at all.
  Future<String?> uploadReferencePhoto(String profileId) async {
    final ProfileReferencePhoto? photo = _photoStore.findPhoto(profileId);
    if (photo == null) {
      return null;
    }
    try {
      final Uint8List bytes = await _photoStore.readPhotoBytes(photo);
      return await _client.uploadReferenceImage(
        _transfer,
        fileName: photo.fileName,
        contentType: photo.format.contentType,
        bytes: bytes,
      );
    } on Exception catch (_) {
      // The cause is dropped on purpose: it can carry the file path.
      return null;
    }
  }

  /// Renders [target] and stores the resulting PNG.
  ///
  /// On success the file exists at the row's relative path and the row is
  /// flipped to `completed` in the same call. Throws an
  /// [IllustrationException] for every failure mode; the row is left for the
  /// caller to mark `failed`, so page bookkeeping stays in one place.
  Future<void> renderPage({
    required IllustrationTarget target,
    required String storyId,
    required StoryIllustrationStyle style,
    required StoryGenderContext? gender,
    String? referenceImageName,
  }) async {
    final deadline = _clock().toUtc().add(_config.illustrationTimeout);
    final workflow = buildIllustrationWorkflow(
      illustrationId: target.illustrationId,
      sceneDescription: target.sceneDescription,
      style: style,
      gender: gender,
      referenceImageName: referenceImageName,
      settings: _config.illustration,
    );

    final String promptId = await _submit(workflow);
    final ComfyUiImageReference image = await _awaitRender(promptId, deadline);
    final Uint8List bytes = await _downloadImage(image);
    await _storeImage(target: target, storyId: storyId, bytes: bytes);
  }

  /// Redraws the uploaded photo [photoImageName] as a storybook portrait and
  /// returns the name ComfyUI stored the result under.
  ///
  /// This is stage one of a book: one extra render per job that turns the
  /// child's photograph into a drawn reference, which stage two then feeds to
  /// the face adapter for every page. It costs a page's worth of time and it
  /// buys the difference between a book of distorted photorealistic faces and
  /// a book of illustrations.
  ///
  /// Returns `null` when the pass could not be completed, for any reason —
  /// same philosophy as [uploadReferencePhoto], and the caller must then
  /// render the pages with **no** reference at all rather than falling back to
  /// the raw photo: photo-as-reference is the output this whole pass exists to
  /// avoid. The cause is dropped on purpose, as it can carry a file path.
  ///
  /// The portrait is derived from the child's photo and is private content: it
  /// stays inside ComfyUI, is never written into the library, and neither it
  /// nor its name is ever logged.
  Future<String?> renderStylizedReference({
    required String storyId,
    required String photoImageName,
    required StoryIllustrationStyle style,
    required StoryGenderContext? gender,
  }) async {
    // The stylization pass gets the same wall-clock budget as a page: it is
    // the same checkpoint, the same size and the same step count.
    final deadline = _clock().toUtc().add(_config.illustrationTimeout);
    try {
      final promptId = await _submit(
        buildReferenceStylizeWorkflow(
          storyId: storyId,
          photoImageName: photoImageName,
          style: style,
          gender: gender,
          settings: _config.illustration,
        ),
      );
      final ComfyUiImageReference image = await _awaitRender(
        promptId,
        deadline,
      );
      final Uint8List bytes = await _downloadImage(image);
      return await _client.uploadReferenceImage(
        _transfer,
        fileName: referencePortraitFileName(storyId),
        contentType: 'image/png',
        bytes: bytes,
      );
    } on Exception catch (_) {
      return null;
    }
  }

  Future<String> _submit(Map<String, Object?> workflow) async {
    try {
      return await _client.submitWorkflow(
        _control,
        workflow: workflow,
        clientId: comfyUiClientId,
      );
    } on ComfyUiCallException catch (error) {
      throw IllustrationException(
        IllustrationFailureCode.comfyUiFailed,
        error.message,
      );
    } on TimeoutException {
      throw const IllustrationException(
        IllustrationFailureCode.comfyUiTimeout,
        'ComfyUI did not accept the render in time.',
      );
    } on Exception catch (_) {
      throw const IllustrationException(
        IllustrationFailureCode.comfyUiUnavailable,
        'The local ComfyUI server could not be reached.',
      );
    }
  }

  Future<ComfyUiImageReference> _awaitRender(
    String promptId,
    DateTime deadline,
  ) async {
    while (true) {
      final ComfyUiHistoryEntry entry;
      try {
        entry = await _client.readHistory(_control, promptId: promptId);
      } on ComfyUiCallException catch (error) {
        throw IllustrationException(
          IllustrationFailureCode.comfyUiFailed,
          error.message,
        );
      } on Exception catch (_) {
        throw const IllustrationException(
          IllustrationFailureCode.comfyUiUnavailable,
          'The local ComfyUI server stopped answering mid-render.',
        );
      }
      if (entry.failed) {
        throw const IllustrationException(
          IllustrationFailureCode.comfyUiFailed,
          'ComfyUI reported the render as failed.',
        );
      }
      if (entry.completed) {
        if (entry.images.isEmpty) {
          throw const IllustrationException(
            IllustrationFailureCode.invalidImageOutput,
            'ComfyUI finished the render without saving an image.',
          );
        }
        return entry.images.first;
      }
      if (!_clock().toUtc().isBefore(deadline)) {
        // Free the card before giving up: an abandoned render would keep
        // the checkpoint resident and starve the next page of VRAM.
        await _interruptQuietly();
        throw IllustrationException(
          IllustrationFailureCode.comfyUiTimeout,
          'ComfyUI did not finish the page within '
          '${_config.illustrationTimeoutSeconds} seconds.',
        );
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<Uint8List> _downloadImage(ComfyUiImageReference image) async {
    final Uint8List bytes;
    try {
      bytes = await _client.fetchImage(_transfer, image: image);
    } on ComfyUiCallException catch (error) {
      throw IllustrationException(
        IllustrationFailureCode.invalidImageOutput,
        error.message,
      );
    } on TimeoutException {
      throw const IllustrationException(
        IllustrationFailureCode.comfyUiTimeout,
        'Downloading the rendered page from ComfyUI timed out.',
      );
    } on Exception catch (_) {
      throw const IllustrationException(
        IllustrationFailureCode.comfyUiUnavailable,
        'The rendered page could not be downloaded from ComfyUI.',
      );
    }
    if (bytes.isEmpty || !looksLikePng(bytes)) {
      throw const IllustrationException(
        IllustrationFailureCode.invalidImageOutput,
        'ComfyUI returned something that is not a PNG image.',
      );
    }
    return bytes;
  }

  Future<void> _storeImage({
    required IllustrationTarget target,
    required String storyId,
    required Uint8List bytes,
  }) async {
    if (!isIllustrationRelativePath(target.relativePath)) {
      throw const IllustrationException(
        IllustrationFailureCode.imageWriteFailed,
        'The illustration row points outside the illustrations folder.',
      );
    }
    try {
      await writeFileAtomic(
        joinPath(
          _library.rootPath,
          toPlatformRelativePath(target.relativePath),
        ),
        bytes,
      );
    } on Exception catch (_) {
      // The path is private content and never reaches the message.
      throw const IllustrationException(
        IllustrationFailureCode.imageWriteFailed,
        'The rendered page could not be written into the library.',
      );
    }
    try {
      _repository.markStatus(
        illustrationId: target.illustrationId,
        storyId: storyId,
        status: completedIllustrationStatus,
        nowUtc: _clock().toUtc(),
      );
    } on Exception catch (_) {
      throw const IllustrationException(
        IllustrationFailureCode.libraryWriteFailed,
        'The illustration row could not be updated after the render.',
      );
    }
  }

  Future<void> _interruptQuietly() async {
    try {
      await _client.interrupt(_control);
    } on Exception catch (_) {
      // Best effort only: the page has already failed either way.
    }
  }
}

/// Client id the bridge identifies itself with on every ComfyUI submission.
///
/// ComfyUI uses it to route progress events; the bridge polls instead, so a
/// single stable value is enough and avoids leaking anything about the
/// family or the machine.
const String comfyUiClientId = 'iam-hero-bridge';
