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
library;

export 'src/backup/backup_envelope.dart';
export 'src/backup/backup_errors.dart';
export 'src/backup/library_backup_payload.dart';
export 'src/backup/library_backup_service.dart';
export 'src/common/gpu_gate.dart';
export 'src/common/image_bytes.dart';
export 'src/common/paths.dart';
export 'src/config/bridge_config.dart';
export 'src/config/bridge_config_loader.dart';
export 'src/config/illustration_settings.dart';
export 'src/generation/cancellation.dart';
export 'src/generation/generated_story.dart';
export 'src/generation/generation_errors.dart';
export 'src/generation/generation_job.dart';
export 'src/generation/ollama_client.dart';
export 'src/generation/story_draft.dart';
export 'src/generation/story_generation_queue.dart';
export 'src/generation/story_generation_request.dart';
export 'src/generation/story_library_writer.dart';
export 'src/generation/story_prompt.dart';
export 'src/illustration/comfyui_client.dart';
export 'src/illustration/illustration_errors.dart';
export 'src/illustration/illustration_job.dart';
export 'src/illustration/illustration_queue.dart';
export 'src/illustration/illustration_renderer.dart';
export 'src/illustration/illustration_repository.dart';
export 'src/illustration/illustration_workflow.dart';
export 'src/library/device_store.dart';
export 'src/library/master_library.dart';
export 'src/library/profile_photo_store.dart';
export 'src/library/story_deleter.dart';
export 'src/pairing/pairing_service.dart';
export 'src/probes/health_probes.dart';
export 'src/probes/probe_client.dart';
export 'src/server/app_server.dart';
export 'src/sync/illustration_file_reader.dart';
export 'src/sync/sync_manifest.dart';
export 'src/sync/sync_reader.dart';
export 'src/sync/sync_state_store.dart';
export 'src/version.dart';
