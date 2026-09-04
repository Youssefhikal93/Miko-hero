import 'dart:convert';
import 'dart:io';

import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/generation/cancellation.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/generation_job.dart';
import 'package:iam_hero_bridge/src/generation/hero_sheet.dart';
import 'package:iam_hero_bridge/src/generation/ollama_client.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/generation/story_outline.dart';
import 'package:iam_hero_bridge/src/generation/story_prompt.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_job.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_workflow.dart';
import 'package:iam_hero_bridge/src/library/character_sheet_store.dart';
import 'package:test/test.dart';

import 'support/harness.dart';

/// A fake Ollama that answers the character-sheet pass with scripted traits.
///
/// The hair is what each test watches: it is the one value that comes from
/// looking at the photograph, so a changed hair colour is proof the vision pass
/// ran again rather than answering from the database. Answers past the end of
/// [hairAnswers] repeat the last one.
FakeOllamaStoryClient sheetOllama({
  List<String> hairAnswers = const <String>['short curly black hair'],
  String? story,
}) {
  var seen = 0;
  return FakeOllamaStoryClient((
    OllamaGenerateRequest request,
    CancellationToken cancellation,
  ) async {
    if (isVisionRequest(request)) {
      final index = seen++;
      return ollamaEnvelope(
        heroSheetPayload(
          hair:
              hairAnswers[index < hairAnswers.length
                  ? index
                  : hairAnswers.length - 1],
        ),
      );
    }
    if (isOutlineRequest(request)) {
      return ollamaEnvelope(outlinePayload(pageCount: 6));
    }
    return ollamaEnvelope(story ?? _storyPayload());
  });
}

String _storyPayload() {
  return jsonEncode(<String, Object?>{
    'title': 'Nour and the Sea Lanterns',
    'pages': List<Object?>.generate(
      6,
      (index) => <String, Object?>{
        'pageNumber': index + 1,
        'text': 'Page ${index + 1}: Nour lit one small lantern and smiled.',
        'illustrationScene': 'A child on a moonlit beach, page ${index + 1}.',
      },
    ),
  });
}

/// Uploads [bytes] as the reference photo of [profileId].
Future<void> putPhoto(
  TestServer testServer,
  String token,
  List<int> bytes, {
  String profileId = 'profile-1',
  String contentType = 'image/png',
}) async {
  final response = await callRaw(
    testServer.handler,
    'PUT',
    '/profiles/$profileId/photo',
    headers: <String, String>{
      ...authHeaders(token),
      HttpHeaders.contentTypeHeader: contentType,
    },
    body: bytes,
  );
  expect(response.statusCode, 200);
  await testServer.settleHeroSheets();
}

/// A second, byte-different PNG, so a replaced photo has a new fingerprint.
List<int> _otherPngBytes() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM'
    'IQAAAABJRU5ErkJggg==',
  );
}

void main() {
  group('the character sheet', () {
    test('is derived once from a photo and cached by its hash', () async {
      final printedCodes = <String>[];
      final client = sheetOllama();
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library, pageCount: 2);

      await putPhoto(testServer, token, onePixelPngBytes());
      expect(client.visionRequests, hasLength(1));

      final HeroCharacterSheet? sheet = testServer.heroSheet('profile-1');
      expect(sheet, isNotNull);
      expect(sheet!.hair, 'short curly black hair');
      expect(sheet.skinTone, 'warm brown');
      expect(sheet.eyeColor, 'dark brown');
      expect(sheet.outfit, pickHeroOutfit('profile-1'));
      expect(sheet.prop, pickHeroProp('profile-1'));

      // The same bytes again: nothing to look at that has not been looked at.
      await putPhoto(testServer, token, onePixelPngBytes());
      expect(
        client.visionRequests,
        hasLength(1),
        reason: 'an unchanged photo must never cost a second model call',
      );
      expect(testServer.heroSheet('profile-1')!.hair, sheet.hair);
    });

    test('is refreshed by a new photo, keeping the outfit and prop', () async {
      final printedCodes = <String>[];
      final client = sheetOllama(
        hairAnswers: <String>[
          'short curly black hair',
          'long straight brown hair',
        ],
      );
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library, pageCount: 2);

      await putPhoto(testServer, token, onePixelPngBytes());
      final HeroCharacterSheet first = testServer.heroSheet('profile-1')!;

      await putPhoto(testServer, token, _otherPngBytes());
      expect(
        client.visionRequests,
        hasLength(2),
        reason: 'a different photo is a different face and must be re-read',
      );

      final HeroCharacterSheet second = testServer.heroSheet('profile-1')!;
      expect(second.hair, 'long straight brown hair');
      expect(second.photoHash, isNot(first.photoHash));
      expect(
        second.outfit,
        first.outfit,
        reason: 'a hero whose coat changes with the camera is the bug',
      );
      expect(second.prop, first.prop);
    });

    test('carries no photograph and no real person into its line', () {
      final prompt = buildHeroSheetPrompt();
      expect(prompt, contains('DRAWN CARTOON CHARACTER'));
      expect(prompt, contains('Never mention a photo'));
      expect(prompt, contains('no clothing'));
      expect(prompt, contains('birthmarks'));

      final sheet = HeroCharacterSheet(
        profileId: 'profile-1',
        hair: 'short curly black hair',
        skinTone: 'warm brown',
        eyeColor: 'dark brown',
        outfit: 'wearing a red knitted cardigan over a white collared shirt',
        prop: 'carrying a small brass lantern',
        photoHash: 'hash-a',
        updatedAtUtc: DateTime.utc(2026, 9, 1),
      );
      expect(
        sheet.toPromptLine(),
        'short curly black hair, warm brown skin, dark brown eyes, '
        'wearing a red knitted cardigan over a white collared shirt, '
        'carrying a small brass lantern',
      );
      expect(
        sheet.toPromptLine().length,
        lessThanOrEqualTo(maximumHeroAppearanceLength),
        reason: 'the line is repeated into every page scene',
      );
    });

    test('refuses model output that is not three short English traits', () {
      for (final payload in <String>[
        'not json',
        jsonEncode(<String, Object?>{'hair': 'black'}),
        jsonEncode(<String, Object?>{
          'hair': '',
          'skinTone': 'warm brown',
          'eyeColor': 'dark brown',
        }),
        jsonEncode(<String, Object?>{
          'hair': 'شعر أسود قصير',
          'skinTone': 'warm brown',
          'eyeColor': 'dark brown',
        }),
        jsonEncode(<String, Object?>{
          'hair': 'a' * (maximumCharacterSheetFieldLength + 1),
          'skinTone': 'warm brown',
          'eyeColor': 'dark brown',
        }),
      ]) {
        expect(
          () => parseHeroSheetTraits(payload),
          throwsA(isA<GenerationException>()),
          reason: 'refused rather than written into every book: $payload',
        );
      }
    });

    test('picks one outfit and prop per child, from the curated lists', () {
      expect(heroOutfitWardrobe, contains(pickHeroOutfit('profile-1')));
      expect(heroPropWardrobe, contains(pickHeroProp('profile-1')));
      expect(pickHeroOutfit('profile-1'), pickHeroOutfit('profile-1'));
      expect(
        <String>{for (var i = 0; i < 40; i++) pickHeroOutfit('child-$i')},
        hasLength(greaterThan(1)),
        reason: 'a wardrobe that always picks one coat is not a wardrobe',
      );
    });
  });

  group('the outline pass', () {
    test('is told to copy a stored sheet instead of inventing one', () {
      const sheet =
          'short curly black hair, warm brown skin, dark brown eyes, '
          'wearing a red knitted cardigan, carrying a small brass lantern';
      final prompt = buildStoryOutlinePrompt(
        StoryGenerationRequest(
          profileId: 'profile-1',
          heroName: 'Nour',
          ageYears: 6,
          gender: StoryGenderContext.girl,
          language: StoryLanguage.english,
          theme: 'A lantern festival by the sea',
          moral: 'Sharing a small light makes it bigger',
          pageCount: 6,
          illustrationStyle: StoryIllustrationStyle.pictureBook,
        ),
        heroSheet: sheet,
      );
      expect(prompt, contains(sheet));
      expect(prompt, contains('Copy this line EXACTLY'));
      expect(
        prompt,
        isNot(contains('Invent it freely')),
        reason: 'the appearance is decided; inventing one is the old bug',
      );
    });

    test('keeps inventing an appearance line when there is no sheet', () {
      final prompt = buildStoryOutlinePrompt(
        StoryGenerationRequest(
          profileId: 'profile-1',
          heroName: 'Nour',
          ageYears: 6,
          gender: StoryGenderContext.girl,
          language: StoryLanguage.english,
          theme: 'A lantern festival by the sea',
          moral: 'Sharing a small light makes it bigger',
          pageCount: 6,
          illustrationStyle: StoryIllustrationStyle.pictureBook,
        ),
      );
      expect(prompt, contains('Invent it freely'));
      expect(prompt, isNot(contains('Copy this line EXACTLY')));
    });

    test('uses the sheet even when the model answers with its own line', () {
      const sheet = 'short curly black hair, red cardigan, brass lantern';
      final outline = parseStoryOutline(
        outlinePayload(pageCount: 6, heroAppearance: 'a completely other look'),
        expectedPageCount: 6,
        fixedHeroAppearance: sheet,
      );
      expect(outline.heroAppearance, sheet);
    });

    test('does not fail a plan whose appearance line it will not use', () {
      // Arabic script in `heroAppearance` costs a retry without a sheet. With
      // one, the field is not read at all, so it cannot cost anything.
      final payload = outlinePayload(
        pageCount: 6,
        heroAppearance: 'شعر أسود قصير ومموج، سترة صفراء',
      );
      expect(
        () => parseStoryOutline(payload, expectedPageCount: 6),
        throwsA(isA<GenerationException>()),
      );
      expect(
        parseStoryOutline(
          payload,
          expectedPageCount: 6,
          fixedHeroAppearance: 'short curly black hair, red boots',
        ).heroAppearance,
        'short curly black hair, red boots',
      );
    });
  });

  group('end to end', () {
    test('a generated story wears the stored sheet on every page', () async {
      final printedCodes = <String>[];
      final logLines = <String>[];
      final client = sheetOllama();
      final testServer = await createTestServer(
        ollamaClient: client,
        notifyCode: printedCodes.add,
        logEvent: logLines.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      seedStory(testServer.library, pageCount: 2);
      await putPhoto(testServer, token, onePixelPngBytes());

      final (status, queued) = await callJson(
        testServer.handler,
        'POST',
        '/stories/generate',
        headers: authHeaders(token),
        body: jsonEncode(<String, Object?>{
          'profileId': 'profile-1',
          'heroName': 'Nour',
          'ageYears': 6,
          'genderContext': 'girl',
          'languageCode': 'en',
          'theme': 'A lantern festival by the sea',
          'moral': 'Sharing a small light makes it bigger',
          'pageCount': 6,
          'illustrationStyle': 'pictureBook',
        }),
      );
      expect(status, 202, reason: 'body was $queued');
      final settled = await testServer.server.awaitStoryJob(
        queued['jobId']! as String,
      );
      expect(settled.status, GenerationJobStatus.completed);

      final HeroCharacterSheet sheet = testServer.heroSheet('profile-1')!;
      expect(
        client.visionRequests,
        hasLength(1),
        reason: 'the upload derived it; generation must reuse it',
      );
      expect(client.outlineRequests.single.prompt, contains(sheet.hair));

      final scenes = testServer.library.database
          .select(
            'SELECT p.scene_description AS scene FROM story_pages p '
            'JOIN stories s ON s.id = p.story_id '
            'WHERE s.title = ? ORDER BY p.page_index ASC',
            <Object?>['Nour and the Sea Lanterns'],
          )
          .map((row) => row['scene']! as String)
          .toList();
      expect(scenes, hasLength(6));
      for (final scene in scenes) {
        expect(
          scene,
          contains(sheet.toPromptLine()),
          reason: 'every page carries the same hero into the renderer',
        );
      }

      // The sheet describes one particular child. Not one word of it, and not
      // one word of the photo, may reach a log line.
      for (final line in logLines) {
        for (final fragment in <String>[
          sheet.hair,
          sheet.skinTone,
          sheet.eyeColor,
          sheet.outfit,
          sheet.prop,
          sheet.photoHash,
          'profile-1',
        ]) {
          expect(
            line,
            isNot(contains(fragment)),
            reason: 'logs carry verdicts, never content: "$line"',
          );
        }
      }
      expect(
        logLines.any((line) => line.contains('hero sheet')),
        isTrue,
        reason: 'the pass still reports that it happened',
      );
    });

    test('two stories of one child draw the same portrait', () async {
      final printedCodes = <String>[];
      final comfy = FakeComfyUiClient();
      final testServer = await createTestServer(
        comfyUiClient: comfy,
        notifyCode: printedCodes.add,
      );
      addTearDown(testServer.close);
      final token = await pairDevice(testServer, printedCodes);
      final first = seedStory(testServer.library, pageCount: 1);
      final second = seedStory(
        testServer.library,
        pageCount: 1,
        title: 'A Second Book',
      );
      await putPhoto(testServer, token, onePixelPngBytes());

      final seeds = <Object?>[];
      for (final storyId in <String>[first.id, second.id]) {
        final (status, queued) = await callJson(
          testServer.handler,
          'POST',
          '/stories/$storyId/illustrate',
          headers: authHeaders(token),
        );
        expect(status, 202, reason: 'body was $queued');
        final settled = await testServer.server.awaitIllustrationJob(
          queued['jobId']! as String,
        );
        expect(settled.status, IllustrationJobStatus.completed);
        // Each job submits its stylization pass, then its one page.
        final stylize = comfy.workflows[comfy.workflows.length - 2];
        final inputs =
            (stylize[referenceSamplerNodeId]!
                    as Map<String, Object?>)['inputs']!
                as Map<String, Object?>;
        seeds.add(inputs['seed']);
      }

      expect(
        seeds.first,
        seeds.last,
        reason: 'one photo, one drawn face — in every book',
      );
      expect(
        seeds.first,
        illustrationReferenceSeed(
          profileId: 'profile-1',
          photoHash: sha256HexOfBytes(onePixelPngBytes()),
        ),
      );

      // A new photo is the one thing that is meant to redraw the hero. A third
      // book, because the first two have every page already.
      await putPhoto(testServer, token, _otherPngBytes());
      final third = seedStory(
        testServer.library,
        pageCount: 1,
        title: 'A Third Book',
      );
      final (status, queued) = await callJson(
        testServer.handler,
        'POST',
        '/stories/${third.id}/illustrate',
        headers: authHeaders(token),
      );
      expect(status, 202, reason: 'body was $queued');
      await testServer.server.awaitIllustrationJob(queued['jobId']! as String);
      final stylize = comfy.workflows[comfy.workflows.length - 2];
      final inputs =
          (stylize[referenceSamplerNodeId]! as Map<String, Object?>)['inputs']!
              as Map<String, Object?>;
      expect(inputs['seed'], isNot(seeds.first));
    });
  });
}
