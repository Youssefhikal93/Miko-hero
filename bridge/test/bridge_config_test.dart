import 'dart:io';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/config/bridge_config_loader.dart';
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
}
