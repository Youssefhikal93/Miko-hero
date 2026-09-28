import 'package:iam_hero_bridge/src/common/json_reader.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/server/api_errors.dart';
import 'package:test/test.dart';

/// A reader over [json] using the configuration-file vocabulary.
JsonReader _config(Map<String, Object?> json) =>
    JsonReader.root(json, failures: bridgeConfigFailures);

/// Asserts that [read] is refused with a message naming [path] and nothing
/// else that was written in the file.
void _expectRefused(void Function() read, String path, {String? because}) {
  expect(
    read,
    throwsA(
      isA<FormatException>().having(
        (error) => error.message,
        'message',
        contains('"$path"'),
      ),
    ),
    reason: because ?? 'the message must name $path',
  );
}

void main() {
  group('absence', () {
    test('an optional field that is not there falls back', () {
      final reader = _config(<String, Object?>{});
      expect(reader.optionalString('checkpoint'), isNull);
      expect(
        reader.optionalInt('port', minimum: 1, maximum: 9, fallback: 4),
        4,
      );
      expect(
        reader.optionalDouble('cfg', minimum: 1, maximum: 9, fallback: 7),
        7.0,
      );
      expect(reader.optionalBool('enabled', fallback: false), isFalse);
      expect(reader.optionalText('notes', maxLength: 8), '');
      expect(reader.section('upscale'), isNull);
      expect(reader.optionalList('loras', expected: 'a list'), isNull);
      expect(reader.optionalBaseUrl('ollamaBaseUrl'), isNull);
      expect(
        reader.choice<int>('size', allowed: <int>[512], fallback: 512),
        512,
      );
    });

    test('a required field that is not there is refused by name', () {
      _expectRefused(
        () => _config(<String, Object?>{}).requireString('checkpoint'),
        'checkpoint',
      );
      _expectRefused(
        () => _config(
          <String, Object?>{},
        ).requireInt('port', minimum: 1, maximum: 9),
        'port',
      );
    });

    test('a present but blank string is refused, not read as absent', () {
      _expectRefused(
        () => _config(<String, Object?>{
          'checkpoint': '   ',
        }).optionalString('checkpoint'),
        'checkpoint',
      );
    });

    test('optional free text treats blank and absent as the same', () {
      expect(
        _config(<String, Object?>{
          'notes': '  ',
        }).optionalText('notes', maxLength: 8),
        '',
        reason: 'nothing filled in is not a mistake to report',
      );
    });
  });

  group('types and bounds', () {
    test('an integer outside its range is refused with the range named', () {
      final reader = _config(<String, Object?>{'port': 70000});
      expect(
        () => reader.optionalInt(
          'port',
          minimum: 1,
          maximum: 65535,
          fallback: 8765,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('"port"'), contains('between 1 and 65535')),
          ),
        ),
      );
    });

    test('a number is not read out of a string, but an int widens', () {
      expect(
        _config(<String, Object?>{
          'cfg': 7,
        }).optionalDouble('cfg', minimum: 1, maximum: 15, fallback: 7),
        7.0,
        reason: '7 and 7.0 are the same number in a configuration file',
      );
      _expectRefused(
        () => _config(<String, Object?>{
          'cfg': '7',
        }).optionalDouble('cfg', minimum: 1, maximum: 15, fallback: 7),
        'cfg',
      );
    });

    test('an exclusive lower bound refuses the bound itself', () {
      final reader = _config(<String, Object?>{'denoise': 0});
      expect(
        () => reader.optionalDouble(
          'denoise',
          minimum: 0,
          maximum: 1,
          fallback: 0.5,
          minimumIsExclusive: true,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('above'),
          ),
        ),
      );
    });

    test('a choice checks the type before the membership', () {
      final allowed = <int>[512, 576, 640];
      expect(
        _config(<String, Object?>{
          'size': 576,
        }).choice<int>('size', allowed: allowed, fallback: 512),
        576,
      );
      _expectRefused(
        () => _config(<String, Object?>{
          'size': 512.0,
        }).choice<int>('size', allowed: allowed, fallback: 512),
        'size',
        because: 'in Dart 512.0 == 512, so the type has to be checked first',
      );
    });

    test('a length limit names the limit but never the value', () {
      final reader = _config(<String, Object?>{'heroName': 'Nour the Brave'});
      expect(
        () => reader.requireString('heroName', maxLength: 4),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('4 character limit'),
              isNot(contains('Nour the Brave')),
            ),
          ),
        ),
      );
    });

    test('a base URL is normalized and a non-URL refused', () {
      expect(
        _config(<String, Object?>{
          'ollamaBaseUrl': 'http://127.0.0.1:11434/',
        }).optionalBaseUrl('ollamaBaseUrl')?.text,
        'http://127.0.0.1:11434',
      );
      _expectRefused(
        () => _config(<String, Object?>{
          'ollamaBaseUrl': 'ollama.local:11434',
        }).optionalBaseUrl('ollamaBaseUrl'),
        'ollamaBaseUrl',
      );
    });

    test('a named choice keeps the wording its schema uses', () {
      final reader = _config(<String, Object?>{'gender': 'grown-up'});
      expect(
        () => reader.namedChoice<StoryGenderContext>(
          'gender',
          resolve: StoryGenderContext.fromWireName,
          expected: '"girl" or "boy"',
          maxLength: 20,
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('must be "girl" or "boy"'),
          ),
        ),
      );
    });
  });

  group('unknown keys', () {
    test('a key nobody reads is refused and named', () {
      expect(
        () => _config(<String, Object?>{
          'checkpiont': 'x.safetensors',
        }).rejectUnknownKeys(const <String>{'checkpoint'}),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('checkpiont'), contains('checkpoint')),
          ),
        ),
      );
    });

    test('the keys the schema does read pass', () {
      expect(
        () => _config(<String, Object?>{
          'checkpoint': 'x.safetensors',
        }).rejectUnknownKeys(const <String>{'checkpoint', 'imageSize'}),
        returnsNormally,
      );
    });
  });

  group('the dotted path', () {
    test('a nested field is reported under its whole path', () {
      final reader = _config(<String, Object?>{
        'illustration': <String, Object?>{
          'upscale': <String, Object?>{'targetSize': 4},
        },
      });
      final section = reader.section('illustration')!.section('upscale')!;
      expect(section.path, 'illustration.upscale');
      _expectRefused(
        () => section.optionalInt(
          'targetSize',
          minimum: 512,
          maximum: 2048,
          fallback: 1024,
        ),
        'illustration.upscale.targetSize',
      );
    });

    test('a list element is reported under its index', () {
      final reader = _config(<String, Object?>{
        'loras': <Object?>['not-an-object'],
      });
      final entries = reader.optionalList('loras', expected: 'a list')!;
      _expectRefused(
        () => reader.elementAt(entries.first, field: 'loras', index: 0),
        'loras[0]',
      );
    });

    test('a section that is not an object is refused as that section', () {
      _expectRefused(
        () => _config(<String, Object?>{'upscale': true}).section('upscale'),
        'upscale',
      );
    });
  });

  group('one reader, four schemas', () {
    test('an HTTP body raises a typed 400 instead of a FormatException', () {
      final reader = JsonReader.root(<String, Object?>{
        'illustrationStyle': 'crayon',
      }, failures: apiFieldFailures);
      expect(
        () => reader.optionalNamedChoice<StoryIllustrationStyle>(
          'illustrationStyle',
          resolve: StoryIllustrationStyle.fromWireName,
          expected: 'one of pictureBook, watercolor, colorful3d',
        ),
        throwsA(
          isA<ApiError>()
              .having((error) => error.status, 'status', 400)
              .having((error) => error.code, 'code', ApiErrorCode.invalidField)
              .having(
                (error) => error.message,
                'message',
                contains('illustrationStyle'),
              ),
        ),
      );
    });

    test('a generation body raises the story request validation type', () {
      final reader = JsonReader.root(<String, Object?>{
        'ageYears': 99,
      }, failures: storyRequestFailures);
      expect(
        () => reader.requireInt('ageYears', minimum: 1, maximum: 17),
        throwsA(
          isA<StoryRequestValidationException>()
              .having((error) => error.field, 'field', 'ageYears')
              .having(
                (error) => error.message,
                'message',
                contains('Field "ageYears"'),
              ),
        ),
      );
    });
  });
}
