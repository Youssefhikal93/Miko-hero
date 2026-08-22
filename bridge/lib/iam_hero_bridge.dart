/// Private, local-only PC bridge service for the "Iam - hero" storybook.
///
/// The bridge runs on the family PC next to Ollama and ComfyUI. It owns the
/// master library (SQLite + folders), pairs mobile companion devices with
/// short-lived pairing codes and 256-bit bearer tokens, and reports the
/// health of its local dependencies.
///
/// Security model in one line: loopback by default, bearer-token auth on
/// every non-health endpoint, and never expose this service to the internet.
library;

export 'src/common/paths.dart';
export 'src/config/bridge_config.dart';
export 'src/config/bridge_config_loader.dart';
export 'src/library/device_store.dart';
export 'src/library/master_library.dart';
export 'src/pairing/pairing_service.dart';
export 'src/probes/health_probes.dart';
export 'src/probes/probe_client.dart';
export 'src/server/app_server.dart';
export 'src/version.dart';
