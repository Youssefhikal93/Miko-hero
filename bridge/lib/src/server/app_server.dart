import 'dart:io';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/library/device_store.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/pairing/pairing_service.dart';
import 'package:iam_hero_bridge/src/probes/health_probes.dart';
import 'package:iam_hero_bridge/src/probes/probe_client.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:iam_hero_bridge/src/server/auth_middleware.dart';
import 'package:iam_hero_bridge/src/server/devices_handler.dart';
import 'package:iam_hero_bridge/src/server/health_handler.dart';
import 'package:iam_hero_bridge/src/server/pairing_handlers.dart';
import 'package:iam_hero_bridge/src/server/request_limits.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

/// Assembles the complete HTTP pipeline and owns the listening socket.
///
/// Pipeline order (outermost first):
/// 1. error boundary — converts [ApiError] and unexpected failures into
///    typed JSON errors without ever logging request content,
/// 2. per-request timeout,
/// 3. request body size limit,
/// 4. routing: public endpoints (`/health`, `/pair/*`) bypass auth; every
///    other endpoint sits behind [requireDeviceAuth].
class AppServer {
  /// Creates a server for [config] over an initialized [library].
  ///
  /// [probeHttpClient], [uuid], [clock] and [notifyCode] are injection seams
  /// for tests; [notifyCode] receives the console line containing a freshly
  /// issued pairing code.
  AppServer({
    required this.config,
    required this.library,
    this._probeHttpClient = const IoProbeHttpClient(),
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
    void Function(String message)? notifyCode,
  }) : deviceStore = DeviceStore(library: library, uuid: uuid),
       pairingService = PairingService(uuid: uuid, clock: clock) {
    _healthHandler = HealthHandler(
      probes: <HealthProbe>[
        OllamaProbe(
          client: _probeHttpClient,
          baseUrl: config.ollamaBaseUrl,
          model: config.ollamaModel,
        ),
        ComfyUiProbe(client: _probeHttpClient, baseUrl: config.comfyUiBaseUrl),
        LibraryProbe(library: library),
      ],
    );
    _pairingHandlers = PairingHandlers(
      service: pairingService,
      deviceStore: deviceStore,
      notifyCode: notifyCode,
    );
    _devicesHandler = DevicesHandler(deviceStore: deviceStore);
  }

  /// Runtime configuration this server was built from.
  final BridgeConfig config;

  /// The initialized master library.
  final MasterLibrary library;

  /// Device registry shared by pairing confirmation and auth.
  final DeviceStore deviceStore;

  /// Pairing service shared by both pairing endpoints.
  final PairingService pairingService;

  final ProbeHttpClient _probeHttpClient;
  late final HealthHandler _healthHandler;
  late final PairingHandlers _pairingHandlers;
  late final DevicesHandler _devicesHandler;

  /// Builds the fully wired request handler without binding a socket.
  ///
  /// Tests bind this to an ephemeral port themselves; the production entry
  /// point uses [start].
  Handler buildHandler() {
    final Router publicApi = Router(notFoundHandler: _typedNotFound)
      ..get('/health', _healthHandler.call)
      ..post('/pair/request', _pairingHandlers.requestPairing)
      ..post('/pair/confirm', _pairingHandlers.confirmPairing);

    final Handler protectedApi = const Pipeline()
        .addMiddleware(requireDeviceAuth(deviceStore: deviceStore))
        .addHandler(
          (Router(
            notFoundHandler: _typedNotFound,
          )..get('/devices', _devicesHandler.listDevices)).call,
        );

    final Handler api = Cascade(
      statusCodes: <int>[404],
    ).add(publicApi.call).add(protectedApi).handler;

    return const Pipeline()
        .addMiddleware(_errorBoundary)
        .addMiddleware(requestTimeout())
        .addMiddleware(requestBodyLimit())
        .addHandler(api);
  }

  /// Binds the HTTP server on `config.bindAddress:config.port`.
  ///
  /// Returns the running [HttpServer]; stop it via [HttpServer.close].
  Future<HttpServer> start() {
    return shelf_io.serve(
      buildHandler(),
      config.bindAddress,
      config.port,
      poweredByHeader: null,
    );
  }

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
