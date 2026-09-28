import 'package:test/test.dart';

import '../tool/likeness_check.dart';

void main() {
  test('parses the required likeness-check arguments and defaults', () {
    final arguments = parseLikenessCheckArguments(<String>[
      '--photo',
      'child.png',
      '--config-from',
      'bridge_config.json',
      '--out',
      'comparison',
    ]);

    expect(arguments.photoPath, 'child.png');
    expect(arguments.configFromPath, 'bridge_config.json');
    expect(arguments.outputPath, 'comparison');
    expect(arguments.language, 'en');
    expect(arguments.heroName, 'Sami');
    expect(arguments.gender, 'boy');
    expect(arguments.pageCount, 6);
    expect(arguments.port, 8799);
  });

  test(
    'refuses missing, repeated, and unsupported likeness-check arguments',
    () {
      expect(
        () => parseLikenessCheckArguments(<String>['--photo', 'child.png']),
        throwsFormatException,
      );
      expect(
        () => parseLikenessCheckArguments(<String>[
          '--photo',
          'child.png',
          '--photo',
          'other.png',
          '--config-from',
          'bridge_config.json',
          '--out',
          'comparison',
        ]),
        throwsFormatException,
      );
      expect(
        () => parseLikenessCheckArguments(<String>[
          '--photo',
          'child.png',
          '--config-from',
          'bridge_config.json',
          '--out',
          'comparison',
          '--pages',
          '7',
        ]),
        throwsFormatException,
      );
    },
  );

  test('rewrites only the isolated Bridge configuration fields', () {
    final source = <String, Object?>{
      'bindAddress': '192.168.1.20',
      'port': 8765,
      'libraryPath': 'D:/IamHero-Library',
      'ollamaBaseUrl': 'http://127.0.0.1:11434',
      'comfyUiBaseUrl': 'http://127.0.0.1:8188',
      'ollamaModel': 'qwen3.5:9b',
      'visionModel': 'gemma3:4b',
      'generationTimeoutSeconds': 900,
      'maxGenerationAttempts': 3,
      'illustrationTimeoutSeconds': 300,
      'allowedWebOrigins': <Object?>['https://family.example'],
      'illustration': <String, Object?>{
        'checkpoint': 'dreamshaper_8.safetensors',
        'ipAdapterWeight': 0.7,
        'referenceDenoise': 0.58,
        'loras': <Object?>[
          <String, Object?>{'name': 'storybook.safetensors', 'strength': 0.8},
        ],
      },
    };

    final rewritten = rewriteLikenessCheckConfig(
      source,
      libraryPath: 'D:/checks/likeness/library',
      port: 8799,
    );

    expect(rewritten['bindAddress'], '127.0.0.1');
    expect(rewritten['port'], 8799);
    expect(rewritten['libraryPath'], 'D:/checks/likeness/library');
    expect(rewritten['allowedWebOrigins'], isEmpty);
    expect(rewritten['ollamaModel'], source['ollamaModel']);
    expect(rewritten['visionModel'], source['visionModel']);
    expect(
      rewritten['generationTimeoutSeconds'],
      source['generationTimeoutSeconds'],
    );
    expect(rewritten['illustration'], source['illustration']);
  });
}
