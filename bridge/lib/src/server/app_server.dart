import 'dart:io';

import 'package:iam_hero_bridge/src/backup/library_backup_service.dart';
import 'package:iam_hero_bridge/src/common/gpu_gate.dart';
import 'package:iam_hero_bridge/src/common/job_queue.dart';
import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/hero_name_spelling_service.dart';
import 'package:iam_hero_bridge/src/generation/hero_sheet_service.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_queue.dart';
import 'package:iam_hero_bridge/src/generation/story_library_writer.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_job.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_queue.dart';
import 'package:iam_hero_bridge/src/library/character_sheet_store.dart';
import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/library/library_catalog.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/profile_deleter.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:iam_hero_bridge/src/library/story_deleter.dart';
import 'package:iam_hero_bridge/src/pairing/pairing_service.dart';
import 'package:iam_hero_bridge/src/probes/health_probes.dart';
import 'package:iam_hero_bridge/src/probes/probe_client.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:iam_hero_bridge/src/server/backup_handlers.dart';
import 'package:iam_hero_bridge/src/server/bridge_routes.dart';
import 'package:iam_hero_bridge/src/server/cors_middleware.dart';
import 'package:iam_hero_bridge/src/server/devices_handler.dart';
import 'package:iam_hero_bridge/src/server/generation_handlers.dart';
import 'package:iam_hero_bridge/src/server/health_handler.dart';
import 'package:iam_hero_bridge/src/server/hero_sheet_handlers.dart';
import 'package:iam_hero_bridge/src/server/illustration_handlers.dart';
import 'package:iam_hero_bridge/src/server/management_handlers.dart';
import 'package:iam_hero_bridge/src/server/name_spelling_handlers.dart';
import 'package:iam_hero_bridge/src/server/pairing_handlers.dart';
import 'package:iam_hero_bridge/src/server/profile_photo_handlers.dart';
import 'package:iam_hero_bridge/src/server/request_limits.dart';
import 'package:iam_hero_bridge/src/server/sync_handlers.dart';
import 'package:iam_hero_bridge/src/sync/illustration_file_reader.dart';
import 'package:iam_hero_bridge/src/sync/sync_reader.dart';
import 'package:iam_hero_bridge/src/sync/sync_state_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

/// Assembles the complete HTTP pipeline and owns the listening socket.
///
/// Pipeline order (outermost first):
/// 1. error boundary — converts [ApiError] and unexpected failures into
///    typed JSON errors without ever logging request content,
/// 2. CORS consent for browser pages (loopback origins plus the configured
///    `allowedWebOrigins`),
/// 3. per-request timeout,
/// 4. request body size limit,
/// 5. routing: public endpoints (`/health`, `/pair/*`) bypass auth; every
///    other endpoint sits behind [requireDeviceAuth] — story generation,
///    illustration rendering, reference photos, synchronization, the owner's
///    management listings and deletions, and master-library backup included.
///
/// The two generation queues share one [GpuGate], created here, because the
/// machine has one GPU: a story and an illustration must never render at the
/// same moment, and whatever one of them loaded onto the card has to be gone
/// before the other starts.
class AppServer {
  /// Creates a server for [config] over an initialized [library].
  ///
  /// [probeHttpClient], [ollamaClient], [comfyUiClient], [uuid], [clock],
  /// [notifyCode] and [illustrationPollInterval] are injection seams for
  /// tests; [notifyCode] receives the console line containing a freshly
  /// issued pairing code, and [logEvent] receives content-free generation
  /// and rendering progress lines.
  AppServer({
    required this.config,
    required this.library,
    this._probeHttpClient = const IoProbeHttpClient(),
    OllamaStoryClient ollamaClient = const IoOllamaStoryClient(),
    ComfyUiClient comfyUiClient = const IoComfyUiClient(),
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
    void Function(String message)? notifyCode,
    JobLogSink? logEvent,
    Duration? illustrationPollInterval,
  }) : deviceStore = DeviceStore(library: library, uuid: uuid),
       pairingService = PairingService(uuid: uuid, clock: clock) {
    // The gate, not the queues, clears the card between them, so it gets the
    // same content-free sink: an eviction that failed is a fact about the
    // machine that only this line will ever report.
    final gpuGate = GpuGate(log: logEvent);
    // One service, shared by the photo endpoint and the story queue: the first
    // derives a child's drawn character sheet as soon as a photo lands, the
    // second falls back to deriving it before a story if that never happened.
    // Both go through the same gate as the queues, as a third Ollama tenant.
    _heroSheets = HeroSheetService(
      config: config,
      store: CharacterSheetStore(library: library),
      photos: ProfilePhotoStore(library: library),
      client: ollamaClient,
      gate: gpuGate,
      clock: clock,
      log: logEvent,
    );
    _generationQueue = StoryGenerationQueue(
      config: config,
      writer: StoryLibraryWriter(library: library, uuid: uuid),
      client: ollamaClient,
      uuid: uuid,
      heroSheets: _heroSheets,
      gate: gpuGate,
      clock: clock,
      log: logEvent,
    );
    _illustrationQueue = IllustrationQueue(
      config: config,
      library: library,
      client: comfyUiClient,
      gate: gpuGate,
      uuid: uuid,
      clock: clock,
      log: logEvent,
      pollInterval: illustrationPollInterval,
    );
    _healthHandler = HealthHandler(
      probes: <HealthProbe>[
        OllamaProbe(client: _probeHttpClient, target: config.ollama),
        ComfyUiProbe(client: _probeHttpClient, target: config.comfyUi),
        LibraryProbe(library: library),
      ],
    );
    _pairingHandlers = PairingHandlers(
      service: pairingService,
      deviceStore: deviceStore,
      notifyCode: notifyCode,
    );
    _devicesHandler = DevicesHandler(deviceStore: deviceStore);
    _generationHandlers = GenerationHandlers(queue: _generationQueue);
    _illustrationHandlers = IllustrationHandlers(queue: _illustrationQueue);
    final photoStore = ProfilePhotoStore(library: library);
    final syncReader = SyncReader(library: library);
    _profilePhotoHandlers = ProfilePhotoHandlers(
      store: photoStore,
      heroSheets: _heroSheets,
    );
    // The same photo store again, so "does this profile exist" has one answer
    // for the photo endpoints and for the sheet endpoints beside them.
    _heroSheetHandlers = HeroSheetHandlers(
      sheets: _heroSheets,
      profiles: photoStore,
    );
    _syncHandlers = SyncHandlers(
      reader: syncReader,
      stateStore: SyncStateStore(library: library),
      deleter: StoryDeleter(library: library, uuid: uuid),
      illustrationFiles: IllustrationFileReader(library: library),
    );
    // The management endpoints share the photo store and the sync reader
    // rather than building their own: whether a child has a photo, and what
    // one story looks like, must not have two answers.
    _managementHandlers = ManagementHandlers(
      catalog: LibraryCatalog(library: library, photos: photoStore),
      deleter: ProfileDeleter(library: library, photos: photoStore, uuid: uuid),
      stories: syncReader,
    );
    _backupHandlers = BackupHandlers(
      service: LibraryBackupService(library: library),
    );
    // The fourth Ollama tenant at the same gate: spelling one child's name in
    // the four story languages, answered inside the request because a parent
    // is waiting in the profile editor for it.
    _nameSpellingHandlers = NameSpellingHandlers(
      service: HeroNameSpellingService(
        config: config,
        client: ollamaClient,
        gate: gpuGate,
        log: logEvent,
      ),
    );
  }

  /// Runtime configuration this server was built from.
  final BridgeConfig config;

  /// The initialized master library.
  final MasterLibrary library;

  /// Device registry shared by pairing confirmation and auth.
  final DeviceStore deviceStore;

  /// Pairing service shared by both pairing endpoints.
  final PairingService pairingService;

  /// Single-worker story generation queue behind the `/stories` endpoints.
  late final StoryGenerationQueue _generationQueue;

  /// Single-worker illustration queue behind the `/illustrations` endpoints.
  ///
  /// Shares its [GpuGate] with [_generationQueue], so the two never render at
  /// the same time.
  late final IllustrationQueue _illustrationQueue;

  /// Derives and caches each child's drawn character sheet.
  ///
  /// Shares the [GpuGate] with both queues: describing a photo loads a model
  /// onto the same 4 GB card, and the gate unloads it again before anything
  /// else takes a turn.
  late final HeroSheetService _heroSheets;

  /// The bound socket once [start] has returned; null before that and after
  /// [close].
  HttpServer? _httpServer;

  final ProbeHttpClient _probeHttpClient;
  late final HealthHandler _healthHandler;
  late final PairingHandlers _pairingHandlers;
  late final DevicesHandler _devicesHandler;
  late final GenerationHandlers _generationHandlers;
  late final IllustrationHandlers _illustrationHandlers;
  late final ProfilePhotoHandlers _profilePhotoHandlers;
  late final HeroSheetHandlers _heroSheetHandlers;
  late final ManagementHandlers _managementHandlers;
  late final SyncHandlers _syncHandlers;
  late final BackupHandlers _backupHandlers;
  late final NameSpellingHandlers _nameSpellingHandlers;

  /// The handler wired to each route of [bridgeRoutes], keyed by
  /// [BridgeRoute.key].
  ///
  /// Handlers differ in arity — a route with a `<param>` segment receives it
  /// as an extra positional argument — which is why these are `Function`
  /// rather than `Handler`; `shelf_router` takes the same type.
  Map<String, Function> _handlersByRoute() {
    return <String, Function>{
      'GET /health': _healthHandler.call,
      'POST /pair/request': _pairingHandlers.requestPairing,
      'POST /pair/confirm': _pairingHandlers.confirmPairing,
      'GET /devices': _devicesHandler.listDevices,
      'DELETE /devices/<deviceId>': _devicesHandler.removeDevice,
      'GET /profiles': _managementHandlers.listProfiles,
      'DELETE /profiles/<profileId>': _managementHandlers.deleteProfile,
      'GET /stories': _managementHandlers.listStories,
      'GET /stories/<storyId>': _managementHandlers.readStory,
      'POST /stories/generate': _generationHandlers.createJob,
      'GET /stories/jobs/<jobId>': _generationHandlers.readJob,
      'POST /stories/jobs/<jobId>/cancel': _generationHandlers.cancelJob,
      'POST /stories/<storyId>/illustrate': _illustrationHandlers.createJob,
      'GET /illustrations/jobs/<jobId>': _illustrationHandlers.readJob,
      'POST /illustrations/jobs/<jobId>/cancel':
          _illustrationHandlers.cancelJob,
      'PUT /profiles/<profileId>/photo': _profilePhotoHandlers.putPhoto,
      'DELETE /profiles/<profileId>/photo': _profilePhotoHandlers.deletePhoto,
      'GET /profiles/<profileId>/hero-sheet': _heroSheetHandlers.readSheet,
      'PUT /profiles/<profileId>/hero-sheet': _heroSheetHandlers.saveWardrobe,
      'POST /profiles/<profileId>/hero-sheet/rederive':
          _heroSheetHandlers.rederiveSheet,
      'POST /stories/<storyId>/delete': _syncHandlers.deleteStory,
      'GET /sync/manifest': _syncHandlers.readManifest,
      'GET /sync/stories/<storyId>': _syncHandlers.downloadStory,
      'GET /sync/illustrations/<illustrationId>':
          _syncHandlers.downloadIllustration,
      'POST /sync/complete': _syncHandlers.completeSync,
      'POST /library/backup': _backupHandlers.createBackup,
      'POST /library/restore': _backupHandlers.restoreBackup,
      'POST /profiles/spellings/suggest':
          _nameSpellingHandlers.suggestSpellings,
    };
  }

  /// Builds the fully wired request handler without binding a socket.
  ///
  /// Both routers are built from [bridgeRoutes], so that list is the only
  /// description of which endpoints exist and which of them are public.
  ///
  /// Tests bind this to an ephemeral port themselves; the production entry
  /// point uses [start].
  Handler buildHandler() {
    final Map<String, Function> handlers = _handlersByRoute();
    final Router publicApi = Router(notFoundHandler: _typedNotFound);
    final Router protectedRouter = Router(notFoundHandler: _typedNotFound);
    for (final BridgeRoute route in bridgeRoutes) {
      final Function? handler = handlers[route.key];
      if (handler == null) {
        throw StateError('No handler is wired for ${route.key}.');
      }
      final Router router = route.requiresAuth ? protectedRouter : publicApi;
      router.add(route.method, route.path, handler);
    }

    final Handler protectedApi = const Pipeline()
        .addMiddleware(requireDeviceAuth(deviceStore: deviceStore))
        .addHandler(protectedRouter.call);

    final Handler api = Cascade(
      statusCodes: <int>[404],
    ).add(publicApi.call).add(protectedApi).handler;

    return const Pipeline()
        .addMiddleware(_errorBoundary)
        .addMiddleware(
          corsMiddleware(extraAllowedOrigins: config.allowedWebOrigins),
        )
        .addMiddleware(requestTimeout())
        .addMiddleware(requestBodyLimit())
        .addHandler(api);
  }

  /// Binds the HTTP server on `config.bindAddress:config.port`.
  ///
  /// Returns the running [HttpServer] so the caller can print where it
  /// listens; stop everything through [close], not [HttpServer.close].
  Future<HttpServer> start() async {
    final HttpServer httpServer = await shelf_io.serve(
      buildHandler(),
      config.bindAddress,
      config.port,
      poweredByHeader: null,
    );
    _httpServer = httpServer;
    return httpServer;
  }

  /// Stops the server completely: abandons every unfinished story or
  /// illustration job, closes the socket if [start] bound one, and closes the
  /// master library.
  ///
  /// Safe to call whether or not [start] ran, and safe to call twice.
  Future<void> close() async {
    _generationQueue.shutdown();
    _illustrationQueue.shutdown();
    final HttpServer? httpServer = _httpServer;
    _httpServer = null;
    if (httpServer != null) {
      await httpServer.close(force: true);
    }
    library.close();
  }

  /// Completes when the story job [jobId] reaches a terminal state.
  ///
  /// The one door tests need into the story queue; production callers poll
  /// the `/stories/jobs/<jobId>` endpoint instead.
  Future<GenerationJob> awaitStoryJob(String jobId) {
    return _generationQueue.whenSettled(jobId);
  }

  /// Completes when the illustration job [jobId] reaches a terminal state.
  ///
  /// The one door tests need into the illustration queue; production callers
  /// poll the `/illustrations/jobs/<jobId>` endpoint instead.
  Future<IllustrationJob> awaitIllustrationJob(String jobId) {
    return _illustrationQueue.whenSettled(jobId);
  }

  /// Completes when every background character-sheet refresh has finished.
  ///
  /// The one door tests need into the sheet service, which a photo upload
  /// deliberately leaves running behind the response; nothing in production
  /// waits on it.
  Future<void> awaitHeroSheetWork() => _heroSheets.backgroundWork;

  /// The stored character sheet of [profileId], or `null`.
  ///
  /// Read-only, and for tests. The three `/profiles/<id>/hero-sheet` endpoints
  /// answer with the same row; this is the door that skips the HTTP layer.
  HeroCharacterSheet? heroSheet(String profileId) =>
      _heroSheets.storedSheet(profileId);

  Response _typedNotFound(Request request) {
    return jsonError(404, ApiErrorCode.notFound, 'Unknown endpoint.');
  }
}

/// Outermost middleware: typed errors in, typed JSON out, always.
///
/// Unexpected errors collapse into a generic `internal_error`; details are
/// deliberately dropped instead of logged because they could contain
/// private request content.
Handler _errorBoundary(Handler innerHandler) {
  return (Request request) async {
    try {
      return await innerHandler(request);
    } on ApiError catch (error) {
      return apiErrorResponse(error);
    } on Exception catch (_) {
      return jsonError(
        500,
        ApiErrorCode.internalError,
        'Unexpected bridge failure.',
      );
    } on Error catch (_) {
      return jsonError(
        500,
        ApiErrorCode.internalError,
        'Unexpected bridge failure.',
      );
    }
  };
}
