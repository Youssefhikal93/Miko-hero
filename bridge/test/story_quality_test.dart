import 'dart:convert';

import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/language_purity.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/generation/story_outline.dart';
import 'package:iam_hero_bridge/src/generation/story_prompt.dart';
import 'package:test/test.dart';

/// One request per language, so the prompt and purity rules can be exercised
/// without going through the HTTP handler.
StoryGenerationRequest request({
  StoryLanguage language = StoryLanguage.english,
  int ageYears = 6,
  int pageCount = 6,
  String favoriteTopics = '',
  String recurringWorld = '',
}) {
  return StoryGenerationRequest(
    profileId: 'profile-1',
    heroName: 'Nour',
    ageYears: ageYears,
    gender: StoryGenderContext.girl,
    language: language,
    theme: 'A lantern festival by the sea',
    moral: 'Sharing a small light makes it bigger',
    pageCount: pageCount,
    illustrationStyle: StoryIllustrationStyle.pictureBook,
    favoriteTopics: favoriteTopics,
    recurringWorld: recurringWorld,
  );
}

/// A valid outline, used where the outline itself is not what is under test.
StoryOutline outline({
  int pageCount = 6,
  String title = 'Nour and the Sea Lanterns',
  String heroAppearance = 'short curly black hair, red boots, brass lantern',
}) {
  return StoryOutline(
    title: title,
    heroAppearance: heroAppearance,
    beats: List<StoryOutlineBeat>.generate(
      pageCount,
      (index) => StoryOutlineBeat(
        pageNumber: index + 1,
        summary: 'Beat ${index + 1}.',
      ),
      growable: false,
    ),
  );
}

/// A draft whose pages carry [scene] as their scene description.
StoryDraft draft({int pageCount = 2, String scene = 'A moonlit beach'}) {
  return StoryDraft(
    title: 'Nour and the Sea Lanterns',
    pages: List<StoryDraftPage>.generate(
      pageCount,
      (index) => StoryDraftPage(
        pageNumber: index + 1,
        text: 'Page ${index + 1}.',
        illustrationScene: scene,
      ),
      growable: false,
    ),
  );
}

void main() {
  group('outline validation', () {
    String plan({
      int beats = 6,
      Object? title = 'Nour and the Sea Lanterns',
      Object? heroAppearance = 'red boots and a brass lantern',
      int Function(int index)? number,
      Object? Function(int index)? summary,
    }) {
      return jsonEncode(<String, Object?>{
        'title': title,
        'heroAppearance': heroAppearance,
        'beats': List<Object?>.generate(
          beats,
          (index) => <String, Object?>{
            'pageNumber': number == null ? index + 1 : number(index),
            'summary': summary == null ? 'Beat ${index + 1}.' : summary(index),
          },
        ),
      });
    }

    test('an outline with the right shape is accepted', () {
      final parsed = parseStoryOutline(plan(), expectedPageCount: 6);

      expect(parsed.title, 'Nour and the Sea Lanterns');
      expect(parsed.heroAppearance, 'red boots and a brass lantern');
      expect(parsed.beats, hasLength(6));
      expect(parsed.beats.first.pageNumber, 1);
      expect(parsed.beats.last.pageNumber, 6);
    });

    test('the hero appearance is collapsed onto one line', () {
      final parsed = parseStoryOutline(
        plan(heroAppearance: 'red boots\n  and a brass lantern\n'),
        expectedPageCount: 6,
      );

      expect(parsed.heroAppearance, 'red boots and a brass lantern');
    });

    test('the prompt block lists every beat in page order', () {
      final block = outline(pageCount: 3).toPromptBlock();

      expect(block, contains('Working title: Nour and the Sea Lanterns'));
      expect(block, contains('1. Beat 1.'));
      expect(block, contains('3. Beat 3.'));
      expect(block, isNot(contains('4.')));
    });

    final refused = <String, String>{
      'text instead of JSON': 'Here is a plan!',
      'a JSON array': '[]',
      'a missing title': plan(title: null),
      'a blank title': plan(title: '   '),
      'a missing hero appearance': plan(heroAppearance: null),
      'a blank hero appearance': plan(heroAppearance: ' '),
      'too few beats': plan(beats: 5),
      'too many beats': plan(beats: 7),
      'beats out of order': plan(number: (index) => 6 - index),
      'a duplicated beat number': plan(number: (index) => 1),
      'a missing summary': plan(summary: (index) => null),
      'a non-string summary': plan(summary: (index) => 3),
      'an oversized title': plan(title: 'a' * (maximumOutlineTitleLength + 1)),
      'an oversized appearance': plan(
        heroAppearance: 'a' * (maximumHeroAppearanceLength + 1),
      ),
      'an oversized beat': plan(
        summary: (index) => 'a' * (maximumOutlineBeatLength + 1),
      ),
    };
    refused.forEach((description, payload) {
      test('$description is refused as invalid model output', () {
        expect(
          () => parseStoryOutline(payload, expectedPageCount: 6),
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

    test('a missing beat list is refused', () {
      expect(
        () => parseStoryOutline(
          jsonEncode(<String, Object?>{
            'title': 'A title',
            'heroAppearance': 'red boots',
          }),
          expectedPageCount: 6,
        ),
        throwsA(isA<GenerationException>()),
      );
    });
  });

  group('language purity', () {
    const arabicPage = 'أشعل نور فانوسًا صغيرًا على الشاطئ، وابتسم للبحر.';
    const englishPage = 'Nour lit one small lantern and smiled at the sea.';
    const swedishPage = 'Nour tände en liten lykta och log mot havet på ön.';
    const somaliPage = 'Nuur wuxuu shiday nal yar oo badda ku dhoola cadeeyay.';

    test('each language accepts its own title and prose', () {
      final cases = <StoryLanguage, (String, String)>{
        StoryLanguage.arabic: ('نور وفوانيس البحر', arabicPage),
        StoryLanguage.english: ('Nour and the Sea Lanterns', englishPage),
        StoryLanguage.swedish: ('Nour och havets lyktor', swedishPage),
        StoryLanguage.somali: ('Nuur iyo nalalka badda', somaliPage),
      };
      cases.forEach((language, book) {
        final (title, page) = book;
        final verdict = checkLanguagePurity(
          language: language,
          texts: <String>[title, page],
        );
        expect(
          verdict.isPure,
          isTrue,
          reason: '${language.code} refused its own prose: ${verdict.failure}',
        );
      });
    });

    test('a title is checked alongside the pages', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>['Nour and the Sea Lanterns', arabicPage],
      );

      expect(verdict.isPure, isFalse);
      expect(verdict.latinLetters, greaterThan(0));
    });

    test('Arabic prose answered in English is refused', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>[englishPage],
      );

      expect(verdict.isPure, isFalse);
      expect(verdict.failure, contains('Arabic'));
    });

    test('transliterated Arabic is refused', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>['Ash-ala Nour fanoosan sagheeran ala ash-shati.'],
      );

      expect(verdict.isPure, isFalse);
    });

    test('a Latin sentence mixed into Arabic prose is refused', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>[
          arabicPage,
          'Then she walked home along the quiet harbour wall and slept well.',
        ],
      );

      expect(verdict.isPure, isFalse);
    });

    test('one borrowed Latin word inside Arabic prose is tolerated', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>[arabicPage, arabicPage, arabicPage, 'ok'],
      );

      expect(verdict.isPure, isTrue);
    });

    for (final language in <StoryLanguage>[
      StoryLanguage.english,
      StoryLanguage.swedish,
      StoryLanguage.somali,
    ]) {
      test('${language.code} refuses even a single Arabic word', () {
        final verdict = checkLanguagePurity(
          language: language,
          texts: <String>[
            'Nour lit one small lantern and smiled at the sea, the فانوس.',
          ],
        );

        expect(verdict.isPure, isFalse);
        expect(verdict.failure, contains('Arabic-script'));
      });
    }

    test('Swedish keeps its å, ä and ö', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.swedish,
        texts: const <String>['Ön där lyktan lyste, åter och åter, för alla.'],
      );

      expect(verdict.isPure, isTrue);
      expect(verdict.otherLetters, 0);
    });

    test('digits, punctuation and page numbers are not letters', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>['١٢٣ — 456 … ؟، «»', arabicPage],
      );

      expect(verdict.isPure, isTrue);
      expect(verdict.latinLetters, 0);
    });

    test('another script entirely is refused for every language', () {
      for (final language in StoryLanguage.values) {
        final verdict = checkLanguagePurity(
          language: language,
          texts: const <String>['Привет мир, это не подходящий язык.'],
        );
        expect(verdict.isPure, isFalse, reason: language.code);
        expect(verdict.otherLetters, greaterThan(0));
      }
    });

    test('an answer with no letters at all is refused', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.english,
        texts: const <String>['123 — 456', '...'],
      );

      expect(verdict.isPure, isFalse);
      expect(verdict.letters, 0);
    });
  });

  group('hero appearance propagation', () {
    test('the sheet is appended to every page', () {
      final applied = withHeroAppearance(
        draft(pageCount: 3),
        'red boots and a brass lantern',
      );

      expect(applied.pages, hasLength(3));
      for (final page in applied.pages) {
        expect(
          page.illustrationScene,
          'A moonlit beach — red boots and a brass lantern',
        );
      }
      expect(applied.title, 'Nour and the Sea Lanterns');
      expect(applied.pages.map((page) => page.text), <String>[
        'Page 1.',
        'Page 2.',
        'Page 3.',
      ]);
    });

    test('an empty sheet leaves the draft untouched', () {
      final applied = withHeroAppearance(draft(), '   ');

      expect(applied.pages.first.illustrationScene, 'A moonlit beach');
    });

    test('a scene that already names the hero is not repeated', () {
      final applied = withHeroAppearance(
        draft(scene: 'A beach — red boots and a brass lantern'),
        'red boots and a brass lantern',
      );

      expect(
        applied.pages.first.illustrationScene,
        'A beach — red boots and a brass lantern',
      );
    });

    test('the stored scene length cap is never exceeded', () {
      final long = 'x' * (maximumDraftSceneLength - 40);
      final applied = withHeroAppearance(
        draft(scene: long),
        'red boots and a brass lantern and a very long coat indeed',
      );

      final scene = applied.pages.first.illustrationScene;
      expect(scene.length, lessThanOrEqualTo(maximumDraftSceneLength));
      expect(scene, startsWith(long));
      expect(scene, contains('red boots'));
    });

    test('a scene with no room left keeps only the scene', () {
      final full = 'x' * (maximumDraftSceneLength - 5);
      final applied = withHeroAppearance(draft(scene: full), 'red boots');

      expect(applied.pages.first.illustrationScene, full);
    });
  });

  group('prompt content', () {
    test('the outline prompt asks for one beat per page and an arc', () {
      final prompt = buildStoryOutlinePrompt(request(pageCount: 8));

      expect(prompt, contains('EXACTLY 8 beats'));
      expect(prompt, contains('Page 1 opens warmly'));
      expect(prompt, contains('chose or did'));
      expect(prompt, contains('heroAppearance'));
      expect(
        prompt,
        contains('must never describe or refer to a photograph'),
        reason: 'the appearance sheet is invented, never taken from a photo',
      );
    });

    test('the page prompt embeds the approved plan verbatim', () {
      final prompt = buildStoryPagesPrompt(
        request(pageCount: 3),
        outline(pageCount: 3, title: 'The Harbour of Small Lights'),
      );

      expect(prompt, contains('The Harbour of Small Lights'));
      expect(prompt, contains('1. Beat 1.'));
      expect(prompt, contains('3. Beat 3.'));
      expect(prompt, contains('Page N tells beat N of the plan'));
    });

    test('the page prompt demands an earned ending and no stated moral', () {
      final prompt = buildStoryPagesPrompt(request(), outline());

      expect(prompt, contains('earned by her own choice or action'));
      expect(prompt, contains('Never state it'));
      expect(prompt, contains('never address the reader'));
    });

    test('the name is asked for naturally, not in every sentence', () {
      final prompt = buildStoryPagesPrompt(request(), outline());

      expect(prompt, contains('roughly once or twice per'));
      expect(prompt, contains('repeats the name in every sentence'));
    });

    test('Arabic adds the fusha rule to both passes', () {
      final arabic = request(language: StoryLanguage.arabic);

      for (final prompt in <String>[
        buildStoryOutlinePrompt(arabic),
        buildStoryPagesPrompt(arabic, outline()),
      ]) {
        expect(prompt, contains('Modern Standard Arabic'));
        expect(prompt, contains('فصحى مبسطة'));
        expect(prompt, contains('Do NOT mix in any spoken dialect'));
        expect(prompt, contains('Do NOT use any Latin'));
      }
    });

    test('every other language gets its own single-language rule', () {
      expect(
        buildStoryPagesPrompt(
          request(language: StoryLanguage.swedish),
          outline(),
        ),
        contains('Swedish spelling including å, ä'),
      );
      expect(
        buildStoryPagesPrompt(
          request(language: StoryLanguage.somali),
          outline(),
        ),
        contains('standard Somali orthography'),
      );
      expect(
        buildStoryPagesPrompt(
          request(language: StoryLanguage.english),
          outline(),
        ),
        contains('Write in English only'),
      );
    });

    test('the reading level follows the age', () {
      expect(
        buildStoryPagesPrompt(request(ageYears: 3), outline()),
        contains('five to eight words'),
      );
      expect(
        buildStoryPagesPrompt(request(ageYears: 6), outline()),
        contains('eight to twelve words'),
      );
      expect(
        buildStoryPagesPrompt(request(ageYears: 9), outline()),
        contains('twelve to sixteen words'),
      );
      expect(
        buildStoryPagesPrompt(request(ageYears: 13), outline()),
        contains('no babyish wording'),
      );
    });

    test('preferences appear in both passes only when they are set', () {
      final withPreferences = request(
        favoriteTopics: 'sea turtles',
        recurringWorld: 'the Lantern Harbour',
      );

      for (final prompt in <String>[
        buildStoryOutlinePrompt(withPreferences),
        buildStoryPagesPrompt(withPreferences, outline()),
      ]) {
        expect(prompt, contains('sea turtles'));
        expect(prompt, contains('the Lantern Harbour'));
      }
      final pages = buildStoryPagesPrompt(withPreferences, outline());
      expect(pages, contains('recurring world named above'));
      expect(pages, contains('things the child loves'));

      final bare = buildStoryPagesPrompt(request(), outline());
      expect(bare, isNot(contains('recurring world named above')));
      expect(bare, isNot(contains('things the child loves')));
    });

    test('the outline schema demands exactly the requested beat count', () {
      final schema = storyOutlineResponseSchema(10);
      final properties = schema['properties']! as Map<String, Object?>;
      final beats = properties['beats']! as Map<String, Object?>;

      expect(beats['minItems'], 10);
      expect(beats['maxItems'], 10);
      expect(schema['required'], <String>['title', 'heroAppearance', 'beats']);
    });
  });
}
