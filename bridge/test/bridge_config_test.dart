import 'dart:io';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/config/bridge_config_loader.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

void main() {
  group('unknown keys', () {
    test('a misspelled setting is refused by name, not silently ignored', () {
      // Before this, a parent who typed `ollamaModle` ran every story on the
      // default model with nothing anywhere saying so.
      expect(
        () => BridgeConfig.fromJson(<String, Object?>{
          'ollamaModle': 'qwen3.5:9b',
        }),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('ollamaModle'), contains('ollamaModel')),
          ),
        ),
      );
    });

    test('every documented key is accepted together', () {
      final config = BridgeConfig.fromJson(<String, Object?>{
        for (final key in BridgeConfig.knownKeys)
          key: BridgeConfig.defaults(workingDirectory: '.').toJson()[key],
      });
      expect(config.ollamaModel, BridgeConfig.defaultOllamaModel);
      expect(config.port, BridgeConfig.defaultPort);
    });

    test('a written config round-trips through its own parser', () {
      final written = BridgeConfig.defaults(workingDirectory: '.').toJson();
      expect(
        () => BridgeConfig.fromJson(written),
        returnsNormally,
        reason: 'the file the loader writes on first run must load again',
      );
    });

    test('the loader names the refused key before the server starts', () async {
      final root = await createTempRoot();
      final configFile = File(
        '${root.path}${Platform.pathSeparator}typo_bridge_config.json',
      );
      await configFile.writeAsString('{"comfyUiBaseUrls":"http://x:8188"}');

      await expectLater(
        const BridgeConfigLoader().load(
          args: <String>['--config', configFile.path],
          workingDirectory: root,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('comfyUiBaseUrls'),
          ),
        ),
      );
    });
  });

  group('base URLs', () {
    test('a trailing slash is the same base URL as none', () {
      expect(
        BridgeConfig.fromJson(<String, Object?>{
          'ollamaBaseUrl': 'http://127.0.0.1:11434/',
          'comfyUiBaseUrl': 'http://127.0.0.1:8188///',
        }).ollamaBaseUrl,
        'http://127.0.0.1:11434',
      );
      expect(
        BridgeConfig.fromJson(<String, Object?>{
          'comfyUiBaseUrl': 'http://127.0.0.1:8188///',
        }).comfyUiBaseUrl,
        'http://127.0.0.1:8188',
        reason: 'more than one slash used to survive and double up in a path',
      );
    });

    test('anything that is not an http(s) URL is refused by field', () {
      for (final value in <String>[
        'ollama.local:11434',
        'ftp://127.0.0.1:11434',
        'http://',
      ]) {
        expect(
          () =>
              BridgeConfig.fromJson(<String, Object?>{'ollamaBaseUrl': value}),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('ollamaBaseUrl'),
            ),
          ),
          reason: value,
        );
      }
    });
  });

  group('the endpoints the configuration hands out', () {
    test('the default control endpoint is capped at the control timeout', () {
      final config = BridgeConfig.fromJson(<String, Object?>{});
      expect(config.comfyUi.transfer.timeout, config.illustrationTimeout);
      expect(
        config.comfyUi.control.timeout,
        comfyUiControlTimeout,
        reason:
            'submitting a workflow and reading history are metadata calls; '
            'they must not inherit the whole five-minute page budget',
      );
    });

    test('the shortest illustrationTimeoutSeconds a file may hold still '
        'leaves the control cap in force', () {
      final config = BridgeConfig.fromJson(<String, Object?>{
        'illustrationTimeoutSeconds':
            BridgeConfig.minimumIllustrationTimeoutSeconds,
      });
      expect(config.comfyUi.transfer.timeout, const Duration(seconds: 60));
      expect(config.comfyUi.control.timeout, comfyUiControlTimeout);
    });

    test('a short illustrationTimeoutSeconds also shortens the control '
        'endpoint', () {
      // Below the file's own floor of 60 s, so this is reached by building a
      // configuration directly — which is what a test that renders with a
      // deliberately tiny budget does. The policy still has to hold: a
      // control call may never outlive the page it belongs to.
      final config = BridgeConfig(
        bindAddress: BridgeConfig.defaultBindAddress,
        port: BridgeConfig.defaultPort,
        libraryPath: BridgeConfig.defaultLibraryPath('.'),
        ollamaBaseUrl: BridgeConfig.defaultOllamaBaseUrl,
        comfyUiBaseUrl: BridgeConfig.defaultComfyUiBaseUrl,
        ollamaModel: BridgeConfig.defaultOllamaModel,
        generationTimeoutSeconds: BridgeConfig.defaultGenerationTimeoutSeconds,
        maxGenerationAttempts: BridgeConfig.defaultMaxGenerationAttempts,
        illustrationTimeoutSeconds: 5,
      );
      expect(config.comfyUi.transfer.timeout, const Duration(seconds: 5));
      expect(config.comfyUi.control.timeout, const Duration(seconds: 5));
    });

    test('both ComfyUI endpoints resolve against the configured base', () {
      final config = BridgeConfig.fromJson(<String, Object?>{
        'comfyUiBaseUrl': 'http://192.168.1.20:8188/',
      });
      expect(
        config.comfyUi.control.resolve('/prompt').toString(),
        'http://192.168.1.20:8188/prompt',
      );
      expect(
        config.comfyUi.transfer.baseUrl,
        config.comfyUi.control.baseUrl,
        reason: 'one base URL, two budgets',
      );
    });

    test('the Ollama requests are built from the configuration alone', () {
      final config = BridgeConfig.fromJson(<String, Object?>{
        'ollamaBaseUrl': 'http://127.0.0.1:11434/',
        'ollamaModel': 'qwen3.5:9b',
        'generationTimeoutSeconds': 120,
      });

      final generate = config.ollama.generateRequest(
        prompt: 'Write a story.',
        format: <String, Object?>{'type': 'object'},
      );
      expect(
        generate.endpoint.toString(),
        'http://127.0.0.1:11434/api/generate',
      );
      expect(generate.model, 'qwen3.5:9b');
      expect(generate.timeout, const Duration(seconds: 120));
      expect(generate.toJson()['stream'], isFalse);

      final unload = config.ollama.unloadRequest();
      expect(unload.endpoint, generate.endpoint);
      expect(unload.model, 'qwen3.5:9b');
      expect(
        unload.timeout,
        ollamaUnloadTimeout,
        reason:
            'the story is already written or already failed; only the GPU '
            'lease is waiting on this',
      );
      expect(unload.toJson()['keep_alive'], 0);
    });
  });
}
