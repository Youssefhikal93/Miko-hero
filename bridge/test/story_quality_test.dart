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
  String heroNameSpelling = '',
  String favoriteTopics = '',
  String recurringWorld = '',
}) {
  return StoryGenerationRequest(
    profileId: 'profile-1',
    heroName: 'Nour',
    heroNameSpelling: heroNameSpelling,
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
  String lessonMoment = 'Nour is asked to share her only lit lantern.',
  int turnPage = 3,
}) {
  return StoryOutline(
    title: title,
    heroAppearance: heroAppearance,
    lessonMoment: lessonMoment,
    turnPage: turnPage,
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
      Object? lessonMoment = 'Nour is asked to share her only lit lantern.',
      Object? turnPage = 3,
      int Function(int index)? number,
      Object? Function(int index)? summary,
    }) {
      return jsonEncode(<String, Object?>{
        'title': title,
        'heroAppearance': heroAppearance,
        'lessonMoment': lessonMoment,
        'turnPage': turnPage,
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
      expect(
        parsed.lessonMoment,
        'Nour is asked to share her only lit lantern.',
      );
      expect(parsed.turnPage, 3);
      expect(parsed.beats, hasLength(6));
      expect(parsed.beats.first.pageNumber, 1);
      expect(parsed.beats.last.pageNumber, 6);
    });

    test('every page between the first and the last can be the turn', () {
      for (final turnPage in <int>[2, 3, 4, 5]) {
        final parsed = parseStoryOutline(
          plan(turnPage: turnPage),
          expectedPageCount: 6,
        );

        expect(parsed.turnPage, turnPage);
      }
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

    test('the prompt block carries the lesson moment and the turn page', () {
      final block = outline(
        pageCount: 6,
        lessonMoment: 'Nour is asked to wait when she wants to run ahead.',
        turnPage: 4,
      ).toPromptBlock();

      expect(
        block,
        contains(
          'Lesson moment (what the middle of the book is about): Nour is '
          'asked to wait when she wants to run ahead.',
        ),
      );
      expect(
        block,
        contains('Turn page (where the hero chooses the lesson): 4'),
      );
    });

    final refused = <String, String>{
      'text instead of JSON': 'Here is a plan!',
      'a JSON array': '[]',
      'a missing title': plan(title: null),
      'a blank title': plan(title: '   '),
      'a missing hero appearance': plan(heroAppearance: null),
      'a blank hero appearance': plan(heroAppearance: ' '),
      'a missing lesson moment': plan(lessonMoment: null),
      'a blank lesson moment': plan(lessonMoment: '   '),
      'a non-string lesson moment': plan(lessonMoment: 7),
      'an oversized lesson moment': plan(
        lessonMoment: 'a' * (maximumLessonMomentLength + 1),
      ),
      'a missing turn page': plan(turnPage: null),
      'a non-integer turn page': plan(turnPage: 'three'),
      'a turn page on page one': plan(turnPage: 1),
      'a turn page before the book starts': plan(turnPage: 0),
      'a turn page on the last page': plan(turnPage: 6),
      'a turn page past the last page': plan(turnPage: 7),
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
      'an appearance written in Arabic': plan(
        heroAppearance: 'شعر أسود قصير ومموج، سترة صفراء زاهية، حذاء أحمر صغير',
      ),
      'an appearance half in Arabic': plan(
        heroAppearance: 'short black hair, سترة صفراء زاهية, red shoes',
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

    test('a confirmed spelling ends that tolerance for Arabic', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>[arabicPage, arabicPage, arabicPage, 'Nour'],
        heroNameIsSpelled: true,
      );

      expect(verdict.isPure, isFalse);
      expect(verdict.failure, contains('4 letters of another script'));
      expect(
        verdict.failure,
        contains("carried the hero's name spelled in Arabic"),
      );
    });

    test('the tightened check still accepts a page that is all Arabic', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.arabic,
        texts: const <String>['مليكة وفوانيس البحر', arabicPage, '١٢٣ — ؟،'],
        heroNameIsSpelled: true,
      );

      expect(verdict.isPure, isTrue);
      expect(verdict.latinLetters, 0);
    });

    test('a confirmed spelling tightens the Latin languages too', () {
      final verdict = checkLanguagePurity(
        language: StoryLanguage.swedish,
        texts: const <String>[swedishPage, swedishPage, 'Привет'],
        heroNameIsSpelled: true,
      );

      expect(verdict.isPure, isFalse);
      expect(verdict.otherLetters, greaterThan(0));
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

    test('the appearance line is demanded in English for every language', () {
      for (final language in StoryLanguage.values) {
        final prompt = buildStoryOutlinePrompt(request(language: language));
        expect(
          prompt,
          contains('even when the story itself is not in English'),
          reason: 'the image model reads Latin letters only (${language.code})',
        );
      }
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

    test(
      'the outline prompt gives the hero a want and makes the middle cost',
      () {
        final prompt = buildStoryOutlinePrompt(request());

        expect(prompt, contains('wants'), reason: 'page 1 names a small want');
        expect(
          prompt,
          contains('costs'),
          reason: 'the middle has to cost the hero a try or a choice',
        );
        expect(
          prompt,
          contains('what Nour feels or decides'),
          reason:
              'every beat carries the hero\'s inner movement, not just events',
        );
      },
    );

    test('the page prompt demands vivid pages: senses, dialogue, feeling', () {
      final prompt = buildStoryPagesPrompt(request(), outline());

      expect(
        prompt,
        contains('$minimumSentencesPerPage to $maximumSentencesPerPage'),
      );
      expect(minimumSentencesPerPage, greaterThanOrEqualTo(3));
      expect(maximumSentencesPerPage, greaterThanOrEqualTo(5));
      expect(prompt, contains('sees, hears, smells'));
      expect(prompt, contains('spoken dialogue'));
      expect(prompt, contains('quotation marks'));
      expect(
        prompt,
        contains('not just naming it'),
        reason: 'feelings are shown through the body, not labelled',
      );
      expect(prompt, contains('the flat sentence'));
    });

    test('the page prompt demands an earned ending and no lecture', () {
      final prompt = buildStoryPagesPrompt(request(), outline());

      expect(prompt, contains('earned by her own choice or action'));
      expect(prompt, contains('Never lecture the'));
      expect(prompt, contains('never address the reader'));
    });

    test('one character may speak the lesson, the reader is never told', () {
      final prompt = buildStoryPagesPrompt(request(), outline());

      expect(
        prompt,
        contains('may say the lesson out loud once'),
        reason: 'a parent or a friend is allowed one spoken line',
      );
      expect(
        prompt,
        contains('never address the reader'),
        reason: 'the relaxed dialogue rule must not relax this one',
      );
    });

    test('the outline prompt makes the middle challenge be the lesson', () {
      final prompt = buildStoryOutlinePrompt(request(pageCount: 8));

      expect(prompt, contains('The middle challenge IS the lesson'));
      expect(prompt, contains('"lessonMoment" is ONE sentence'));
      expect(
        prompt,
        contains('in the middle of the book: after page 1 and before page 8'),
        reason: 'the turn page range is stated in pages, not in the abstract',
      );
    });

    test('the page prompt names the turn page and what it must show', () {
      final prompt = buildStoryPagesPrompt(
        request(),
        outline(
          lessonMoment: 'Nour is asked to wait for her father.',
          turnPage: 5,
        ),
      );

      expect(prompt, contains('Nour is asked to wait for her father.'));
      expect(prompt, contains('Page 5 is the turn: on that page'));
      expect(prompt, contains('chooses the lesson in what Nour actually does'));
      expect(prompt, contains('how making it feels in the'));
    });

    test('both passes write the confirmed spelling and forbid another', () {
      final arabic = request(
        language: StoryLanguage.arabic,
        heroNameSpelling: 'مليكة',
      );

      // A plan with no Latin name in it either, so the assertion below is
      // about the prompt builder rather than about the fixture.
      final plan = outline(
        title: 'فوانيس البحر',
        lessonMoment: 'She is asked to share her only lit lantern.',
      );
      for (final prompt in <String>[
        buildStoryOutlinePrompt(arabic),
        buildStoryPagesPrompt(arabic, plan),
      ]) {
        expect(
          prompt,
          contains('- Name: مليكة'),
          reason: 'the story is written about the name the family confirmed',
        );
        expect(
          prompt,
          contains(
            'Write the hero\'s name EXACTLY as "مليكة", letter for letter, '
            'every single\n  time it appears.',
          ),
          reason: 'the one line that forbids any other spelling of the name',
        );
        expect(prompt, contains('never\n  transliterate it'));
        expect(
          prompt,
          isNot(contains('Nour')),
          reason: 'the Latin spelling has no business in an Arabic book',
        );
      }
    });

    test('without a spelling the prompts say the entered name, as before', () {
      for (final prompt in <String>[
        buildStoryOutlinePrompt(request()),
        buildStoryPagesPrompt(request(), outline()),
      ]) {
        expect(prompt, contains('- Name: Nour'));
        expect(prompt, contains('Write the hero\'s name EXACTLY as "Nour"'));
      }
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
      expect(schema['required'], <String>[
        'title',
        'heroAppearance',
        'lessonMoment',
        'turnPage',
        'beats',
      ]);
      expect(properties['lessonMoment'], <String, Object?>{'type': 'string'});
      expect(properties['turnPage'], <String, Object?>{'type': 'integer'});
    });
  });
}
