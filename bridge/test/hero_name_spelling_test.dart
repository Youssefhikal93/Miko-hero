import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/hero_name_spelling.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// One `POST /profiles/spellings/suggest` body.
Map<String, Object?> suggestBody({
  Object? heroName = 'Malika',
  Object? gender = 'girl',
}) {
  return <String, Object?>{'heroName': ?heroName, 'gender': ?gender};
}

void main() {
  group('the spelling schema and prompt', () {
    test('asks for one string per story language, all of them required', () {
      final schema = heroNameSpellingResponseSchema();
      final properties = schema['properties']! as Map<String, Object?>;

      expect(properties.keys, <String>['ar', 'en', 'sv', 'so']);
      expect(properties['ar'], <String, Object?>{'type': 'string'});
      expect(schema['required'], <String>['ar', 'en', 'sv', 'so']);
    });

    test('carries the name and forbids turning it into another name', () {
      final prompt = buildHeroNameSpellingPrompt(
        heroName: 'Malika',
        gender: StoryGenderContext.girl,
      );

      expect(prompt, contains('Malika'));
      expect(prompt, contains("girl's given name"));
      expect(prompt, contains('It stays the same name.'));
      expect(prompt, contains('never replace it with a different name'));
      expect(prompt, contains('"ar" must be written entirely in Arabic'));
    });

    test('says nothing about a girl or a boy when nobody said', () {
      final prompt = buildHeroNameSpellingPrompt(heroName: 'Malika');

      expect(prompt, contains("child's given name"));
      expect(prompt, isNot(contains('girl')));
      expect(prompt, isNot(contains('boy')));
    });
  });

  group('spelling validation', () {
    test('four names in the right scripts are accepted', () {
      final parsed = parseHeroNameSpellings(nameSpellingsPayload());

      expect(parsed[StoryLanguage.arabic], 'مليكة');
      expect(parsed[StoryLanguage.english], 'Malika');
      expect(parsed[StoryLanguage.swedish], 'Malika');
      expect(parsed[StoryLanguage.somali], 'Maliika');
    });

    test('a spelling written across two lines is collapsed onto one', () {
      final parsed = parseHeroNameSpellings(
        nameSpellingsPayload(english: ' Malika \n  Nour '),
      );

      expect(parsed[StoryLanguage.english], 'Malika Nour');
    });

    final refused = <String, String>{
      'text instead of JSON': 'Here you go!',
      'a JSON array': '[]',
      'a missing Arabic spelling': jsonEncode(<String, Object?>{
        'en': 'Malika',
        'sv': 'Malika',
        'so': 'Maliika',
      }),
      'a blank Somali spelling': nameSpellingsPayload(somali: '   '),
      'an Arabic spelling in Latin letters': nameSpellingsPayload(
        arabic: 'Malika',
      ),
      'an English spelling in Arabic letters': nameSpellingsPayload(
        english: 'مليكة',
      ),
      'a Swedish spelling in another script entirely': nameSpellingsPayload(
        swedish: 'Малика',
      ),
      'an oversized spelling': nameSpellingsPayload(
        english: 'a' * (maximumHeroNameSpellingLength + 1),
      ),
      'a pronunciation guide instead of a name': nameSpellingsPayload(
        english: 'Malika pronounced ma LEE ka',
      ),
    };
    refused.forEach((description, payload) {
      test('$description is refused as invalid model output', () {
        expect(
          () => parseHeroNameSpellings(payload),
          throwsA(
            isA<GenerationException>().having(
              (error) => error.code,
              'code',
              GenerationFailureCode.invalidModelOutput,
            ),
          ),
        );
      });
    });
  });

  group('POST /profiles/spellings/suggest', () {
    test(
      'answers one spelling per language from a single model call',
      () async {
        final printedCodes = <String>[];
        final ollama = FakeOllamaStoryClient.writing(
          story: jsonEncode(<String, Object?>{
            'title': 'x',
            'pages': <Object?>[],
          }),
        );
        final testServer = await createTestServer(
          ollamaClient: ollama,
          notifyCode: printedCodes.add,
        );
        addTearDown(testServer.close);
        final token = await pairDevice(testServer, printedCodes);

        final (status, body) = await callJson(
          testServer.handler,
          'POST',
          '/profiles/spellings/suggest',
          headers: authHeaders(token),
          body: jsonEncode(suggestBody()),
        );

        expect(status, 200, reason: 'body was $body');
        expect(body['spellings'], <String, Object?>{
          'ar': 'مليكة',
          'en': 'Malika',
          'sv': 'Malika',
          'so': 'Maliika',
        });
        expect(ollama.spellingRequests, hasLength(1));
        expect(ollama.spellingRequests.single.model, 'gemma3:4b');
        expect(ollama.spellingRequests.single.prompt, contains('Malika'));
        expect(
          ollama.spellingRequests.single.timeout,
          ollamaNameSpellingCallTimeout,
        );
      },
    );

    test('unloads the story model once the card changes hands', () async {
      final printedCodes = <String>[];
      final ollama = FakeOllamaStoryClient.writing(
        story: jsonEncode(<String, Object?>{
          'title': 'x',
          'pages': <Object?>[],
        }),
      );
      final testServer = await createTestServer(
        ollamaClient: ollama,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      await callJson(
        testServer.handler,
        'POST',
        '/profiles/spellings/suggest',
        headers: authHeaders(token),
        body: jsonEncode(suggestBody(gender: null)),
      );

      expect(ollama.unloadRequests, hasLength(1));
      expect(ollama.unloadRequests.single.model, 'gemma3:4b');
    });

    test('a model that cannot answer is a typed 503, not a crash', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(
        ollamaClient: FakeOllamaStoryClient.failing(
          const SocketException('No Ollama in this test.'),
        ),
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final (status, body) = await callJson(
        testServer.handler,
        'POST',
        '/profiles/spellings/suggest',
        headers: authHeaders(token),
        body: jsonEncode(suggestBody()),
      );

      expect(status, 503);
      expect(errorCode(body), 'ollama_unavailable');
    });

    test('an answer that is not four names is refused whole', () async {
      final printedCodes = <String>[];
      final testServer = await createTestServer(
        ollamaClient: FakeOllamaStoryClient((
          OllamaGenerateRequest request,
          CancellationToken cancellation,
        ) async {
          return ollamaEnvelope(nameSpellingsPayload(arabic: 'Malika'));
        }),
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      final (status, body) = await callJson(
        testServer.handler,
        'POST',
        '/profiles/spellings/suggest',
        headers: authHeaders(token),
        body: jsonEncode(suggestBody()),
      );

      expect(status, 503);
      expect(errorCode(body), 'ollama_unavailable');
    });

    final badBodies = <String, Map<String, Object?>>{
      'a missing name': suggestBody(heroName: null),
      'a blank name': suggestBody(heroName: '   '),
      'a name that is not a string': suggestBody(heroName: 7),
      'an oversized name': suggestBody(
        heroName: 'a' * (maximumHeroNameLength + 1),
      ),
      'an unsupported gender': suggestBody(gender: 'unspecified'),
    };
    badBodies.forEach((description, body) {
      test('$description is refused before any model call', () async {
        final printedCodes = <String>[];
        final ollama = FakeOllamaStoryClient.writing(
          story: jsonEncode(<String, Object?>{
            'title': 'x',
            'pages': <Object?>[],
          }),
        );
        final testServer = await createTestServer(
          ollamaClient: ollama,
          notifyCode: printedCodes.add,
        );
        addTearDown(testServer.close);
        final token = await pairDevice(testServer, printedCodes);

        final (status, answer) = await callJson(
          testServer.handler,
          'POST',
          '/profiles/spellings/suggest',
          headers: authHeaders(token),
          body: jsonEncode(body),
        );

        expect(status, 400, reason: 'body was $answer');
        expect(errorCode(answer), 'invalid_field');
        expect(ollama.requests, isEmpty);
      });
    });

    test('an unauthenticated call reaches no model at all', () async {
      final ollama = FakeOllamaStoryClient.writing(
        story: jsonEncode(<String, Object?>{
          'title': 'x',
          'pages': <Object?>[],
        }),
      );
      final testServer = await createTestServer(ollamaClient: ollama);
      addTearDown(testServer.close);

      final (status, body) = await callJson(
        testServer.handler,
        'POST',
        '/profiles/spellings/suggest',
        body: jsonEncode(suggestBody()),
      );

      expect(status, 401);
      expect(errorCode(body), 'unauthorized');
      expect(ollama.requests, isEmpty);
    });

    test('the log never carries the name it was asked about', () async {
      final printedCodes = <String>[];
      final lines = <String>[];
      final testServer = await createTestServer(
        ollamaClient: FakeOllamaStoryClient.writing(
          story: jsonEncode(<String, Object?>{
            'title': 'x',
            'pages': <Object?>[],
          }),
        ),
        notifyCode: printedCodes.add,
        logEvent: lines.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);

      await callJson(
        testServer.handler,
        'POST',
        '/profiles/spellings/suggest',
        headers: authHeaders(token),
        body: jsonEncode(suggestBody()),
      );

      expect(lines, contains('name spellings suggested'));
      for (final line in lines) {
        expect(line, isNot(contains('Malika')));
        expect(line, isNot(contains('مليكة')));
      }
    });
  });
}
