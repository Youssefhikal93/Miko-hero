import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/generation/local_ai_story_generator.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
import 'package:miko_hero/core/storage/local_repository.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_bridge_http_client.dart';

late InMemoryBridgeCredentialStorage _credentialStorage;

/// Verifies the parent-gated AI connection commands over real local storage.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    _credentialStorage = InMemoryBridgeCredentialStorage();
  });

  test(
    'a device starts on the offline demo and the loopback address',
    () async {
      final container = _container(_pairingBridge());

      final connection = await container.read(
        aiConnectionControllerProvider.future,
      );

      expect(connection.settings.mode, StoryGeneratorMode.demo);
      expect(connection.settings.baseUrl.toString(), 'http://127.0.0.1:8765');
      expect(connection.isPaired, isFalse);
      expect(container.read(storyGeneratorProvider), isA<DemoStoryGenerator>());
    },
  );

  test('the generator mode persists and switches the generator', () async {
    final container = _container(_pairingBridge());
    await container.read(aiConnectionControllerProvider.future);

    await container
        .read(aiConnectionControllerProvider.notifier)
        .setMode(StoryGeneratorMode.localAi);

    expect(
      container.read(storyGeneratorProvider),
      isA<LocalAiStoryGenerator>(),
    );
    final restarted = _container(_pairingBridge());
    final reloaded = await restarted.read(
      aiConnectionControllerProvider.future,
    );
    expect(reloaded.settings.mode, StoryGeneratorMode.localAi);
    expect(
      restarted.read(storyGeneratorProvider),
      isA<LocalAiStoryGenerator>(),
    );

    await restarted
        .read(aiConnectionControllerProvider.notifier)
        .setMode(StoryGeneratorMode.demo);
    expect(restarted.read(storyGeneratorProvider), isA<DemoStoryGenerator>());
  });

  test('pairing stores the token and reports the paired device', () async {
    final container = _container(_pairingBridge());
    await container.read(aiConnectionControllerProvider.future);
    final controller = container.read(aiConnectionControllerProvider.notifier);

    final pairingId = await controller.startPairing();
    await controller.confirmPairing(
      pairingId: pairingId,
      code: '123456',
      deviceName: 'Family tablet',
    );

    final connection = container
        .read(aiConnectionControllerProvider)
        .requireValue;
    expect(connection.isPaired, isTrue);
    expect(connection.pairedDeviceName, 'Family tablet');
    expect(connection.credential.toString(), isNot(contains('issued-token')));
    final repository = await LocalRepository.open(
      bridgeCredentialStorage: _credentialStorage,
    );
    final stored = await repository.readBridgeCredential();
    expect(stored?.deviceToken, 'issued-token');
  });

  test('a wrong code leaves this device unpaired', () async {
    final container = _container(
      FakeBridgeHttpClient((request) async {
        return switch (request.url.path) {
          '/pair/request' => bridgeJsonResponse(<String, Object>{
            'pairingId': 'pairing-1',
          }),
          _ => bridgeErrorResponse('invalid_pairing_code', 403),
        };
      }),
    );
    await container.read(aiConnectionControllerProvider.future);
    final controller = container.read(aiConnectionControllerProvider.notifier);
    final pairingId = await controller.startPairing();

    await expectLater(
      controller.confirmPairing(
        pairingId: pairingId,
        code: '000000',
        deviceName: 'Family tablet',
      ),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.invalidPairingCode,
        ),
      ),
    );
    expect(
      container.read(aiConnectionControllerProvider).requireValue.isPaired,
      isFalse,
    );
    final repository = await LocalRepository.open(
      bridgeCredentialStorage: _credentialStorage,
    );
    expect(await repository.readBridgeCredential(), isNull);
  });

  test('forgetting the device removes only the stored token', () async {
    final container = _container(_pairingBridge());
    await container.read(aiConnectionControllerProvider.future);
    final controller = container.read(aiConnectionControllerProvider.notifier);
    await controller.setMode(StoryGeneratorMode.localAi);
    await controller.confirmPairing(
      pairingId: await controller.startPairing(),
      code: '123456',
      deviceName: 'Family tablet',
    );

    await controller.forgetDevice();

    final connection = container
        .read(aiConnectionControllerProvider)
        .requireValue;
    expect(connection.isPaired, isFalse);
    expect(connection.settings.mode, StoryGeneratorMode.localAi);
    final repository = await LocalRepository.open(
      bridgeCredentialStorage: _credentialStorage,
    );
    expect(await repository.readBridgeCredential(), isNull);
  });

  test('the device list is read with this device marked by the PC', () async {
    final container = _container(
      _pairedBridge((request) async {
        return bridgeJsonResponse(<String, Object?>{
          'devices': <Map<String, Object?>>[
            bridgeDevicePayload(
              id: 'device-a',
              name: 'Family tablet',
              lastSeenAtUtc: '2026-09-01T18:30:00.000Z',
              isCaller: true,
            ),
            // No lastSeenAtUtc at all: a bridge older than the column, and a
            // device that paired but never called, both send exactly this.
            <String, Object?>{
              'id': 'device-b',
              'name': "Dad's phone",
              'createdAtUtc': '2026-08-25T10:00:00.000Z',
            },
          ],
        });
      }),
    );
    final controller = await _pairedController(container);

    final devices = await controller.readPairedDevices();

    expect(devices, hasLength(2));
    expect(devices.first.name, 'Family tablet');
    expect(devices.first.isCaller, isTrue);
    expect(devices.first.lastSeenAtUtc, DateTime.utc(2026, 9, 1, 18, 30));
    expect(devices.first.pairedAtUtc.isUtc, isTrue);
    expect(devices.last.isCaller, isFalse, reason: 'absent means not caller');
    expect(devices.last.lastSeenAtUtc, isNull);
  });

  test('a device list this build cannot read is a typed failure', () async {
    final container = _container(
      _pairedBridge((request) async {
        return bridgeJsonResponse(<String, Object?>{
          'devices': <Map<String, Object?>>[
            <String, Object?>{'id': 'device-a'},
          ],
        });
      }),
    );
    final controller = await _pairedController(container);

    await expectLater(
      controller.readPairedDevices(),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.invalidResponse,
        ),
      ),
    );
  });

  test('the PC refusing a self-removal is a typed failure', () async {
    final container = _container(
      _pairedBridge((request) async {
        return bridgeErrorResponse('cannot_remove_self', 409);
      }),
    );
    final controller = await _pairedController(container);

    await expectLater(
      controller.removePairedDevice('device-a'),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.cannotRemoveThisDevice,
        ),
      ),
    );
  });

  test('removing a device the PC forgot is a typed failure', () async {
    final container = _container(
      _pairedBridge((request) async {
        return bridgeErrorResponse('device_not_found', 404);
      }),
    );
    final controller = await _pairedController(container);

    await expectLater(
      controller.removePairedDevice('device-gone'),
      throwsA(
        isA<BridgeException>().having(
          (error) => error.failure,
          'failure',
          BridgeFailure.deviceNotFound,
        ),
      ),
    );
  });

  test('an unusable address is refused and the stored one is kept', () async {
    final container = _container(_pairingBridge());
    await container.read(aiConnectionControllerProvider.future);
    final controller = container.read(aiConnectionControllerProvider.notifier);

    await expectLater(
      controller.setBaseUrl('not-an-address'),
      throwsArgumentError,
    );
    await controller.setBaseUrl('http://192.168.1.20:8765');

    expect(
      container
          .read(aiConnectionControllerProvider)
          .requireValue
          .settings
          .baseUrl
          .toString(),
      'http://192.168.1.20:8765',
    );
  });

  test('the connection test reports the three PC dependencies', () async {
    final container = _container(
      FakeBridgeHttpClient((request) async {
        return bridgeJsonResponse(<String, Object>{
          'version': '0.1.0',
          'uptimeSeconds': 3.0,
          'statuses': <String, Object>{
            'ollama': <String, Object>{'available': true, 'detail': 'Ready.'},
            'comfyui': <String, Object>{'available': false, 'detail': 'Down.'},
            'library': <String, Object>{'available': true, 'detail': 'Open.'},
          },
        });
      }),
    );
    await container.read(aiConnectionControllerProvider.future);

    final health = await container
        .read(aiConnectionControllerProvider.notifier)
        .readHealth();

    expect(health.isOllamaAvailable, isTrue);
    expect(health.isComfyUiAvailable, isFalse);
    expect(health.isLibraryAvailable, isTrue);
  });
}

/// Opens a container whose only replaced boundary is the HTTP client.
ProviderContainer _container(FakeBridgeHttpClient httpClient) {
  final container = ProviderContainer(
    overrides: [
      bridgeHttpClientProvider.overrideWithValue(httpClient),
      bridgeCredentialStorageProvider.overrideWithValue(_credentialStorage),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Answers the two pairing endpoints, then defers everything else to [handler].
///
/// The device list and device removal both need a token, so a suite exercising
/// them has to pair first exactly as a parent does.
FakeBridgeHttpClient _pairedBridge(
  Future<http.Response> Function(http.Request request) handler,
) {
  return FakeBridgeHttpClient((request) async {
    return switch (request.url.path) {
      '/pair/request' => bridgeJsonResponse(<String, Object>{
        'pairingId': 'pairing-1',
      }),
      '/pair/confirm' => bridgeJsonResponse(<String, Object>{
        'deviceToken': 'issued-token',
      }),
      _ => handler(request),
    };
  });
}

/// Loads the controller and pairs this device with the scripted PC.
Future<AiConnectionController> _pairedController(
  ProviderContainer container,
) async {
  await container.read(aiConnectionControllerProvider.future);
  final controller = container.read(aiConnectionControllerProvider.notifier);
  await controller.confirmPairing(
    pairingId: await controller.startPairing(),
    code: '123456',
    deviceName: 'Family tablet',
  );
  return controller;
}

/// Answers the two pairing endpoints the way a running bridge does.
FakeBridgeHttpClient _pairingBridge() {
  return FakeBridgeHttpClient((request) async {
    return switch (request.url.path) {
      '/pair/request' => bridgeJsonResponse(<String, Object>{
        'pairingId': 'pairing-1',
      }),
      '/pair/confirm' => bridgeJsonResponse(<String, Object>{
        'deviceToken': 'issued-token',
      }),
      _ => bridgeErrorResponse('job_not_found', 404),
    };
  });
}
