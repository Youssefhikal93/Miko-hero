import 'dart:convert';

import 'package:iam_hero_bridge/src/config/bridge_config.dart';
import 'package:iam_hero_bridge/src/config/illustration_settings.dart';
import 'package:iam_hero_bridge/src/illustration/comfyui_client.dart';
import 'package:test/test.dart';

/// Parses one `illustration` section, as a config file would carry it.
IllustrationSettings _parse(Map<String, Object?> section) {
  return IllustrationSettings.fromJson(section);
}

/// Asserts that [section] is refused and that the message names [field].
void _expectRefused(Map<String, Object?> section, String field) {
  expect(
    () => _parse(section),
    throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains(field),
      ),
    ),
    reason: 'a wrong "$field" must be named in the error',
  );
}

void main() {
  group('defaults', () {
    test('a config without the section renders exactly what it did', () {
      final config = BridgeConfig.fromJson(<String, Object?>{});
      final settings = config.illustration;

      expect(settings.checkpoint, 'v1-5-pruned-emaonly-fp16.safetensors');
      expect(settings.imageSize, 512);
      expect(settings.samplerSteps, 24);
      expect(settings.cfgScale, 7.0);
      expect(settings.ipAdapterWeight, 0.65);
      expect(settings.referenceDenoise, 0.62);
      expect(settings.loras, isEmpty);
      expect(settings.upscale.enabled, isFalse);
      expect(settings.faceDetail.enabled, isFalse);
      expect(
        settings.outputImageSize,
        512,
        reason: 'nothing enlarges a page until the parent asks for it',
      );
    });

    test('an empty section is the same as no section at all', () {
      expect(
        jsonEncode(_parse(<String, Object?>{}).toJson()),
        jsonEncode(IllustrationSettings.defaults.toJson()),
      );
      expect(
        jsonEncode(BridgeConfig.fromJson(<String, Object?>{}).toJson()),
        jsonEncode(
          BridgeConfig.fromJson(<String, Object?>{
            'illustration': <String, Object?>{},
          }).toJson(),
        ),
      );
    });

    test('every field is optional on its own', () {
      final settings = _parse(<String, Object?>{
        'checkpoint': 'dreamshaper_8.safetensors',
      });
      expect(settings.checkpoint, 'dreamshaper_8.safetensors');
      expect(settings.imageSize, IllustrationSettings.defaultImageSize);
      expect(settings.samplerSteps, IllustrationSettings.defaultSamplerSteps);
    });

    test('a written config round-trips through its own parser', () {
      final original = _parse(<String, Object?>{
        'checkpoint': 'dreamshaper_8.safetensors',
        'imageSize': 576,
        'samplerSteps': 30,
        'cfgScale': 6.5,
        'ipAdapterWeight': 0.7,
        'referenceDenoise': 0.58,
        'loras': <Object?>[
          <String, Object?>{'name': 'kids-book.safetensors', 'strength': 0.8},
        ],
        'upscale': <String, Object?>{
          'enabled': true,
          'model': 'RealESRGAN_x4plus_anime_6B.pth',
          'targetSize': 1024,
        },
        'faceDetail': <String, Object?>{
          'enabled': true,
          'detector': 'bbox/face_yolov8m.pt',
          'denoise': 0.4,
        },
      });
      final again = _parse(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, Object?>,
      );
      expect(jsonEncode(again.toJson()), jsonEncode(original.toJson()));
      expect(again.loras.single.name, 'kids-book.safetensors');
      expect(again.upscale.targetSize, 1024);
      expect(again.faceDetail.denoise, 0.4);
      expect(again.outputImageSize, 1024);
    });
  });

  group('ranges', () {
    test('imageSize accepts only the three trained sizes', () {
      for (final size in supportedIllustrationImageSizes) {
        expect(_parse(<String, Object?>{'imageSize': size}).imageSize, size);
      }
      for (final size in <Object?>[511, 768, 1024, '512', 512.0]) {
        _expectRefused(<String, Object?>{'imageSize': size}, 'imageSize');
      }
    });

    test('samplerSteps stays between 1 and 60', () {
      expect(_parse(<String, Object?>{'samplerSteps': 1}).samplerSteps, 1);
      expect(_parse(<String, Object?>{'samplerSteps': 60}).samplerSteps, 60);
      for (final steps in <Object?>[0, -1, 61, 24.5, 'many']) {
        _expectRefused(<String, Object?>{
          'samplerSteps': steps,
        }, 'samplerSteps');
      }
    });

    test('cfgScale stays between 1 and 15 and accepts whole numbers', () {
      expect(_parse(<String, Object?>{'cfgScale': 1}).cfgScale, 1.0);
      expect(_parse(<String, Object?>{'cfgScale': 15}).cfgScale, 15.0);
      expect(_parse(<String, Object?>{'cfgScale': 7.5}).cfgScale, 7.5);
      for (final cfg in <Object?>[0.9, 15.1, '7', true]) {
        _expectRefused(<String, Object?>{'cfgScale': cfg}, 'cfgScale');
      }
    });

    test('the face adapter weight is bounded', () {
      expect(
        _parse(<String, Object?>{'ipAdapterWeight': 0.55}).ipAdapterWeight,
        0.55,
      );
      for (final weight in <Object?>[-0.1, 1.6, 'strong']) {
        _expectRefused(<String, Object?>{
          'ipAdapterWeight': weight,
        }, 'ipAdapterWeight');
      }
    });

    test('a reference denoise of zero is refused, not accepted as off', () {
      expect(
        _parse(<String, Object?>{'referenceDenoise': 1.0}).referenceDenoise,
        1.0,
      );
      for (final denoise in <Object?>[0, 0.0, -0.2, 1.01]) {
        _expectRefused(<String, Object?>{
          'referenceDenoise': denoise,
        }, 'referenceDenoise');
      }
    });

    test('LoRA strength stays between 0 and 1.5', () {
      final settings = _parse(<String, Object?>{
        'loras': <Object?>[
          <String, Object?>{'name': 'a.safetensors', 'strength': 0},
          <String, Object?>{'name': 'b.safetensors', 'strength': 1.5},
        ],
      });
      expect(settings.loras.map((lora) => lora.strength), <double>[0.0, 1.5]);

      for (final strength in <Object?>[-0.1, 1.6, '0.8']) {
        _expectRefused(<String, Object?>{
          'loras': <Object?>[
            <String, Object?>{'name': 'a.safetensors', 'strength': strength},
          ],
        }, 'strength');
      }
    });

    test('upscale targetSize stays between 512 and 2048', () {
      for (final size in <int>[512, 1024, 2048]) {
        expect(
          _parse(<String, Object?>{
            'upscale': <String, Object?>{'enabled': true, 'targetSize': size},
          }).upscale.targetSize,
          size,
        );
      }
      for (final size in <Object?>[511, 2049, 1024.0, '1024']) {
        _expectRefused(<String, Object?>{
          'upscale': <String, Object?>{'targetSize': size},
        }, 'targetSize');
      }
    });

    test('a face-detail denoise of zero is refused', () {
      expect(
        _parse(<String, Object?>{
          'faceDetail': <String, Object?>{'denoise': 0.45},
        }).faceDetail.denoise,
        0.45,
      );
      for (final denoise in <Object?>[0, 1.5, 'soft']) {
        _expectRefused(<String, Object?>{
          'faceDetail': <String, Object?>{'denoise': denoise},
        }, 'denoise');
      }
    });
  });

  group('shapes', () {
    test('an unknown key inside the section is refused, not ignored', () {
      _expectRefused(<String, Object?>{
        'checkpiont': 'x.safetensors',
      }, 'illustration');
      _expectRefused(<String, Object?>{'imagesize': 512}, 'imagesize');
      _expectRefused(<String, Object?>{
        'upscale': <String, Object?>{'enable': true},
      }, 'illustration.upscale');
      _expectRefused(<String, Object?>{
        'faceDetail': <String, Object?>{'detecter': 'bbox/face.pt'},
      }, 'illustration.faceDetail');
      _expectRefused(<String, Object?>{
        'loras': <Object?>[
          <String, Object?>{'name': 'a.safetensors', 'strenght': 0.8},
        ],
      }, 'illustration.loras[0]');
    });

    test('a typo is not silently rendered with the old settings', () {
      // The whole point of the strict section: a parent who misspells a key
      // must be told, not handed the previous book again.
      expect(
        () => BridgeConfig.fromJson(<String, Object?>{
          'illustration': <String, Object?>{'lora': <Object?>[]},
        }),
        throwsFormatException,
      );
    });

    test('the section and its blocks must be objects', () {
      expect(
        () => BridgeConfig.fromJson(<String, Object?>{'illustration': 'on'}),
        throwsFormatException,
      );
      _expectRefused(<String, Object?>{
        'upscale': true,
      }, 'illustration.upscale');
      _expectRefused(<String, Object?>{
        'faceDetail': <Object?>[],
      }, 'illustration.faceDetail');
      _expectRefused(<String, Object?>{'loras': <String, Object?>{}}, 'loras');
    });

    test('a LoRA entry needs a name and a strength', () {
      _expectRefused(<String, Object?>{
        'loras': <Object?>[
          <String, Object?>{'strength': 0.8},
        ],
      }, 'name');
      _expectRefused(<String, Object?>{
        'loras': <Object?>[
          <String, Object?>{'name': 'a.safetensors'},
        ],
      }, 'strength');
      _expectRefused(<String, Object?>{
        'loras': <Object?>[
          <String, Object?>{'name': '  ', 'strength': 0.8},
        ],
      }, 'name');
      _expectRefused(<String, Object?>{
        'loras': <Object?>['a.safetensors'],
      }, 'illustration.loras[0]');
    });

    test('a chain longer than its reserved node band is refused', () {
      final tooMany = <Object?>[
        for (var index = 0; index <= maximumIllustrationLoraCount; index++)
          <String, Object?>{'name': 'lora-$index.safetensors', 'strength': 0.5},
      ];
      _expectRefused(<String, Object?>{'loras': tooMany}, 'loras');
      expect(
        _parse(<String, Object?>{
          'loras': tooMany.sublist(0, maximumIllustrationLoraCount),
        }).loras,
        hasLength(maximumIllustrationLoraCount),
      );
    });

    test('empty strings are refused rather than trimmed to nothing', () {
      for (final field in <String>['checkpoint']) {
        _expectRefused(<String, Object?>{field: '   '}, field);
      }
      _expectRefused(<String, Object?>{
        'upscale': <String, Object?>{'model': ''},
      }, 'model');
      _expectRefused(<String, Object?>{
        'faceDetail': <String, Object?>{'detector': ''},
      }, 'detector');
    });

    test('enabled must be a boolean', () {
      _expectRefused(<String, Object?>{
        'upscale': <String, Object?>{'enabled': 'yes'},
      }, 'illustration.upscale.enabled');
      _expectRefused(<String, Object?>{
        'faceDetail': <String, Object?>{'enabled': 1},
      }, 'illustration.faceDetail.enabled');
    });
  });

  group('the image download cap', () {
    test('the documented maximum actually fits inside the cap', () {
      expect(
        worstCaseSquarePngBytes(IllustrationUpscaleSettings.maximumTargetSize),
        lessThanOrEqualTo(maxComfyUiImageBytes),
        reason: 'no accepted configuration may produce an undownloadable page',
      );
      expect(
        maximumDownloadableIllustrationSize,
        greaterThanOrEqualTo(IllustrationUpscaleSettings.maximumTargetSize),
      );
      expect(largestSquarePngEdgeWithin(0), 0);
      expect(
        worstCaseSquarePngBytes(largestSquarePngEdgeWithin(1024 * 1024)),
        lessThanOrEqualTo(1024 * 1024),
      );
      expect(
        worstCaseSquarePngBytes(largestSquarePngEdgeWithin(1024 * 1024) + 1),
        greaterThan(1024 * 1024),
        reason: 'the answer must be the largest edge, not a safe small one',
      );
    });

    test('a size the bridge could not download is refused at load time', () {
      // A cap small enough to make an otherwise legal 1024 page impossible:
      // the parent learns at startup instead of after a book of failures.
      expect(
        () => IllustrationSettings.fromJson(<String, Object?>{
          'upscale': <String, Object?>{'enabled': true, 'targetSize': 1024},
        }, maxDownloadBytes: 512 * 1024),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('1024x1024'), contains('KB limit')),
          ),
        ),
      );
      // With the pass off, the same tiny cap still carries a 512 page.
      expect(
        IllustrationSettings.fromJson(<String, Object?>{
          'upscale': <String, Object?>{'enabled': false, 'targetSize': 2048},
        }, maxDownloadBytes: 1024 * 1024).outputImageSize,
        512,
        reason: 'an idle upscale pass cannot make a page too big to fetch',
      );
    });
  });
}
