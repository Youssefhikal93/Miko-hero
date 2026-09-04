/// Private, local-only PC bridge service for the "Iam - hero" storybook.
///
/// The bridge runs on the family PC next to Ollama and ComfyUI. It owns the
/// master library (SQLite + folders), pairs mobile companion devices with
/// short-lived pairing codes and 256-bit bearer tokens, reports the health of
/// its local dependencies, synchronizes stories to paired devices, deletes
/// them everywhere, and writes encrypted backups of the whole library.
///
/// Security model in one line: loopback by default, bearer-token auth on
/// every non-health endpoint, and never expose this service to the internet.
///
/// This library exports only what an entry point needs to load a
/// configuration, open the library, and run the server. Tests and the rest of
/// the package import `src/` files directly.
library;

export 'src/config/bridge_config.dart';
export 'src/config/bridge_config_loader.dart';
export 'src/library/master_library.dart';
export 'src/server/app_server.dart';
export 'src/version.dart';
