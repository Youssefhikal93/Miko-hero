import 'dart:async';
import 'dart:io';

import 'package:iam_hero_bridge/iam_hero_bridge.dart';

/// Entry point of the local Iam-hero bridge service.
///
/// Loads configuration (creating a default file on first run), initializes
/// the master library, binds the private HTTP server, and shuts down
/// gracefully on SIGINT/SIGTERM.
Future<void> main(List<String> args) async {
  const loader = BridgeConfigLoader();
  final BridgeConfigLoadResult loadResult;
  try {
    loadResult = await loader.load(args: args);
  } on FormatException catch (error) {
    stderr.writeln('Configuration error: ${error.message}');
    exitCode = 78;
    return;
  }
  if (loadResult.createdDefaults) {
    print(
      'Created default bridge configuration at '
      '${loadResult.configFile.path}',
    );
  } else {
    print('Using bridge configuration at ${loadResult.configFile.path}');
  }

  final config = loadResult.config;
  final library = MasterLibrary(rootPath: config.libraryPath);
  try {
    await library.initialize();
  } catch (_) {
    stderr.writeln(
      'Failed to initialize the master library at "${config.libraryPath}".',
    );
    exitCode = 74;
    return;
  }

  final server = AppServer(
    config: config,
    library: library,
    notifyCode: print,
    logEvent: print,
  );
  final HttpServer httpServer;
  try {
    httpServer = await server.start();
  } on SocketException catch (error) {
    stderr.writeln(
      'Failed to bind ${config.bindAddress}:${config.port} '
      '(${error.message}).',
    );
    library.close();
    exitCode = 74;
    return;
  }

  print(
    'Iam-hero bridge v$bridgeVersion listening on '
    '${httpServer.address.address}:${httpServer.port}',
  );

  final shutdown = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  subscriptions.add(ProcessSignal.sigint.watch().listen(shutdown.complete));
  if (!Platform.isWindows) {
    // Windows delivers the unsupported-signal failure as an asynchronous
    // stream error rather than a synchronous throw, so gate on the platform
    // instead of catching. SIGINT alone is sufficient there.
    subscriptions.add(ProcessSignal.sigterm.watch().listen(shutdown.complete));
  }

  await shutdown.future;
  for (final subscription in subscriptions) {
    await subscription.cancel();
  }
  print('Shutting down.');
  server.generationQueue.shutdown();
  await httpServer.close(force: true);
  library.close();
}
