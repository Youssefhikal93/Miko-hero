import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_client.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';

/// Supplies the web-safe HTTP boundary every bridge call travels through.
///
/// Overridden in tests so no socket is ever opened.
final bridgeHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Supplies the UTC clock used to stamp a completed pairing.
final bridgePairingClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// Builds a bridge client for one loaded connection snapshot.
///
/// Shared with every other feature that talks to the PC — generation and
/// library synchronization included — so all of them send the same stored
/// address and the same stored token, and none of them reaches into the
/// pairing record itself.
BridgeClient bridgeClientFor(
  AiConnectionState connection,
  http.Client httpClient,
) {
  return BridgeClient(
    httpClient: httpClient,
    baseUrl: connection.settings.baseUrl,
    deviceToken: connection.credential?.deviceToken,
  );
}

/// Exposes the parent's generator choice, bridge address, and paired state.
final aiConnectionControllerProvider =
    AsyncNotifierProvider<AiConnectionController, AiConnectionState>(
      AiConnectionController.new,
    );

/// The connection settings of this device together with its pairing record.
class AiConnectionState {
  /// Creates one immutable snapshot of the local AI connection.
  const AiConnectionState({required this.settings, required this.credential});

  /// Generator mode and bridge address chosen by the parent.
  final AiConnectionSettings settings;

  /// Stored pairing record, absent until this device is paired.
  ///
  /// Held exactly like the parent-PIN verifier in `ParentAccessState`: the
  /// secret stays inside the state object and no screen ever renders it.
  final BridgeCredential? credential;

  /// Whether this device holds a token the PC issued.
  bool get isPaired => credential != null;

  /// Name this device is listed under on the PC, absent while unpaired.
  String? get pairedDeviceName => credential?.deviceName;

  /// Whether new stories are requested from the PC instead of the sample.
  bool get usesLocalAi => settings.usesLocalAi;
}

/// Owns AI connection persistence and the parent-gated pairing ceremony.
class AiConnectionController extends AsyncNotifier<AiConnectionState> {
  @override
  /// Loads the stored selection and pairing record before any screen renders.
  Future<AiConnectionState> build() async {
    final repository = await ref.watch(localRepositoryProvider.future);
    return AiConnectionState(
      settings: await repository.readAiConnectionSettings(),
      credential: await repository.readBridgeCredential(),
    );
  }

  /// Switches between the offline demo and the PC, and persists the choice.
  Future<void> setMode(StoryGeneratorMode mode) async {
    final current = state.requireValue;
    await _saveSettings(current.settings.withMode(mode), current.credential);
  }

  /// Persists a validated bridge address for every later call.
  ///
  /// Rejects an address [parseBridgeBaseUrl] refuses, so an unusable value can
  /// never be stored and silently break generation later.
  Future<void> setBaseUrl(String baseUrl) async {
    final address = parseBridgeBaseUrl(baseUrl);
    if (address == null) throw ArgumentError.value(baseUrl, 'baseUrl');
    final current = state.requireValue;
    await _saveSettings(
      current.settings.withBaseUrl(address),
      current.credential,
    );
  }

  /// Asks the bridge for its own and its dependencies' health.
  Future<BridgeHealth> readHealth() {
    return _client().readHealth();
  }

  /// Starts a pairing ceremony; the 6-digit code appears only on the PC.
  Future<String> startPairing() {
    return _client().requestPairing();
  }

  /// Confirms a pairing with the code from the PC and stores the token.
  Future<void> confirmPairing({
    required String pairingId,
    required String code,
    required String deviceName,
  }) async {
    final name = deviceName.trim();
    final token = await _client().confirmPairing(
      pairingId: pairingId,
      code: code.trim(),
      deviceName: name,
    );
    final current = state.requireValue;
    await _saveSettings(
      current.settings,
      BridgeCredential(
        deviceToken: token,
        deviceName: name,
        pairedAtUtc: ref.read(bridgePairingClockProvider)().toUtc(),
      ),
    );
  }

  /// Lists the devices the PC currently trusts, this one marked by the PC.
  Future<List<BridgePairedDevice>> readPairedDevices() {
    return _client().listDevices();
  }

  /// Removes one other device's pairing on the PC.
  ///
  /// Nothing local changes: the record removed lives on the PC, and the PC
  /// refuses an attempt to remove this device, which [forgetDevice] does.
  Future<void> removePairedDevice(String deviceId) {
    return _client().revokeDevice(deviceId);
  }

  /// Deletes the stored token so this device stops using the PC.
  ///
  /// Local only: the PC keeps its own list of paired devices, which the
  /// parent manages there.
  Future<void> forgetDevice() async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.removeBridgeCredential();
    state = AsyncData(
      AiConnectionState(
        settings: state.requireValue.settings,
        credential: null,
      ),
    );
  }

  /// Builds a client for the address and token currently stored.
  BridgeClient _client() {
    return bridgeClientFor(
      state.requireValue,
      ref.read(bridgeHttpClientProvider),
    );
  }

  /// Persists settings and pairing together before publishing the snapshot.
  Future<void> _saveSettings(
    AiConnectionSettings settings,
    BridgeCredential? credential,
  ) async {
    final repository = await ref.read(localRepositoryProvider.future);
    await repository.saveAiConnectionSettings(settings);
    if (credential != null) {
      await repository.saveBridgeCredential(credential);
    }
    state = AsyncData(
      AiConnectionState(settings: settings, credential: credential),
    );
  }
}
