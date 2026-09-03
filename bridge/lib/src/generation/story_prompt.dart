import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/generation/story_outline.dart';

/// Minimum number of sentences demanded per page.
///
/// Raised from two on 2026-09-03: two-sentence pages read as captions, not a
/// story (the owner's verdict on the first `qwen3.5:9b` books, issue #25).
const int minimumSentencesPerPage = 3;

/// Maximum number of sentences demanded per page.
const int maximumSentencesPerPage = 5;

/// Builds the JSON schema handed to Ollama in the `format` field.
///
/// Structured output alone is not trusted — the answer is validated again by
/// `parseStoryDraft` — but the schema removes most of the model's freedom to
/// answer with prose, markdown fences or a different shape.
Map<String, Object?> storyResponseSchema(int pageCount) {
  return <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'title': <String, Object?>{'type': 'string'},
      'pages': <String, Object?>{
        'type': 'array',
        'minItems': pageCount,
        'maxItems': pageCount,
        'items': <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'pageNumber': <String, Object?>{'type': 'integer'},
            'text': <String, Object?>{'type': 'string'},
            'illustrationScene': <String, Object?>{'type': 'string'},
          },
          'required': <String>['pageNumber', 'text', 'illustrationScene'],
        },
      },
    },
    'required': <String>['title', 'pages'],
  };
}

/// Builds the outline prompt for [request] — the first of the two passes.
///
/// The result contains the child's name and the parent's idea, so it is
/// private content: it is sent to the local model and never logged.
String buildStoryOutlinePrompt(StoryGenerationRequest request) {
  final language = request.language.englishName;
  final pageCount = request.pageCount;
  final name = request.heroName;

  return '''
You are a warm, careful children's storybook author. Before writing anything,
you plan the story: exactly one beat per page, so the finished book has a real
beginning, middle and end instead of $pageCount unrelated scenes.

The hero:
${_heroBlock(request)}

The story:
${_storyIdeaBlock(request)}

Plan the arc across the $pageCount pages like this:
- Page 1 opens warmly in an ordinary, safe moment, shows who $name is, and
  names one small thing $name wants or hopes for today. That want is the
  thread the whole book pulls on.
- The middle challenge IS the lesson, not a separate adventure sitting next
  to it. $name first does the opposite of the lesson, it costs $name
  something real — a try that fails, a friend hurt, a thing lost — and then
  on the turn page $name chooses the lesson instead.
- The final page resolves it because of something $name chose or did — never
  because an adult, a rescue or luck fixed it — and the ending answers the
  want from page 1, even if not in the way $name expected.
- The lesson is visible in what happens, not announced. Do not plan a page
  whose beat is "the moral is explained".

Hard requirements:
1. Write "title" and every "summary" ONLY in $language.
   ${_languageRule(request)}
2. Produce EXACTLY $pageCount beats, numbered 1 to $pageCount in order.
3. Each "summary" is one or two short sentences: what happens on that page,
   and what $name feels or decides because of it. A beat that only lists an
   event is not enough; the reader has to be able to feel the page turn.
4. "heroAppearance" is ONE short English line describing how $name looks in
   the pictures: hair, clothing colours, and one small prop that recurs — for
   example "short curly black hair, mustard-yellow raincoat, red boots,
   carries a small brass lantern". It is read only by the picture model, so
   it must be in English with Latin letters only,
   even when the story itself is not in English; any other script is rejected.
   Invent it freely; it must be a drawn character description and
   must never describe or refer to a photograph, a real person, or any real
   identifying feature.
5. "lessonMoment" is ONE sentence in $language naming the concrete situation
   where $name faces the lesson: what happens, who is there, and what $name
   has to decide. Name the situation, do not restate the lesson, and do not
   summarise the whole book.
6. "turnPage" is the page number where $name chooses the lesson. It must fall
   in the middle of the book: after page 1 and before page $pageCount. Before
   it $name is still doing the opposite; after it the story lives with the
   choice.
7. Keep everything gentle and appropriate for a ${request.ageYears}-year-old:
   no violence, death, horror, romance, brands or scary imagery.

Answer with one JSON object matching the requested schema and nothing else.
''';
}

/// Builds the page-writing prompt for [request] from an approved [outline].
///
/// The outline is embedded verbatim, which is what makes a retry reproduce the
/// same story instead of drifting into a different one. Private content: sent
/// to the local model and never logged.
String buildStoryPagesPrompt(
  StoryGenerationRequest request,
  StoryOutline outline,
) {
  final language = request.language.englishName;
  final possessive = request.gender.pronoun;
  final pageCount = request.pageCount;
  final name = request.heroName;

  return '''
You are a warm, careful children's storybook author writing one complete
picture-book story for a single family. The plan below is already approved.
Write the finished pages from it — do not invent a different story.

The hero:
${_heroBlock(request)}

The story:
${_storyIdeaBlock(request)}

The approved plan:
${outline.toPromptBlock()}

Hard requirements:
1. Write the title and ALL page text ONLY in $language. Do not write any
   story text in any other language, and do not translate or transliterate.
   ${_languageRule(request)}
2. Produce EXACTLY $pageCount pages, numbered 1 to $pageCount in order,
   with no missing or repeated numbers. Page N tells beat N of the plan.
3. Every page has $minimumSentencesPerPage to $maximumSentencesPerPage
   complete sentences of flowing prose — no headings, lists or page labels
   inside the text.
3a. Make every page vivid and specific, never a caption. On each page put at
    least one concrete detail a child can sense — what $name
    sees, hears, smells or touches, how the air or the ground feels —
    chosen for this place and this moment, not a stock phrase.
3b. Let people speak. Most pages carry at least one short line of
    spoken dialogue in quotation marks — $name, a friend, a parent — in a
    real voice that sounds like a child or a family member, never a lesson
    in disguise. Dialogue counts toward the sentence range.
3c. Show what $name feels through the body and through action — a held
    breath, a hand squeezed tighter, a jump, a small step back — and
    not just naming it. "$name was brave" is the flat sentence to avoid;
    show the brave thing instead.
4. ${_readingLevelRule(request)}
5. Use the name $name where it reads naturally — roughly once or twice per
   page. Everywhere else use pronouns and ordinary wording; a page that
   repeats the name in every sentence sounds like a form, not a story.
6. The book reads as one continuous arc: the warm opening, the challenge or
   discovery growing through the middle pages, and a last page where the
   ending is earned by $possessive own choice or action.
6a. Page ${outline.turnPage} is the turn: on that page $name faces the plan's
    lesson moment and chooses the lesson in what $name actually does. Show
    the choice being made — the action itself, and how making it feels in the
    body. Before that page $name is still doing the opposite; after it the
    story lives with what $name chose.
7. Show the lesson through what happens and how it feels. Never lecture the
   reader and never address the reader — no "and so we learn", no "remember,
   children", no closing lesson sentence, no narrator explaining the point.
   One character — a parent, a friend — may say the lesson out loud once, in
   ordinary dialogue that sounds like that person talking to $name. Once in
   the whole book, never more, and never on the last page.
${_preferenceRules(request)}
8. Keep everything gentle and appropriate for a ${request.ageYears}-year-old:
   no violence, death, horror, romance, brands or scary imagery.
9. Give every page an "illustrationScene" written ONLY in English, one or
   two sentences describing what a picture on that page shows: who is in it,
   what they are doing, the place, the light and the mood. Draw the hero
   exactly as the plan's hero appearance says, on every page. Style direction
   to mention: ${request.illustrationStyle.englishDirection}. Never put story
   text, letters, words or speech bubbles into the scene description.
10. Give a short title in $language, at most eight words. The plan's working
    title is a suggestion; a better one in $language is welcome.

Answer with one JSON object matching the requested schema and nothing else.
''';
}

/// The hero description shared by both passes.
String _heroBlock(StoryGenerationRequest request) {
  final name = request.heroName;
  final language = request.language.englishName;
  return '''
- Name: $name
- The hero is a ${request.gender.wireName}; refer to $name with
  "${request.gender.subjectPronoun}" and "${request.gender.pronoun}" wording
  that is natural in $language.
- Age of the child who will read it: ${request.ageYears} years old.''';
}

/// The parent's idea, lesson and saved preferences, shared by both passes.
String _storyIdeaBlock(StoryGenerationRequest request) {
  final name = request.heroName;
  final lines = <String>[
    '- Setting or adventure idea: ${request.theme}',
    '- Lesson the story must teach through what $name does: ${request.moral}',
  ];
  if (request.recurringWorld.isNotEmpty) {
    lines.add(
      '- This family\'s recurring story world, which this story takes place '
      'in or visits: ${request.recurringWorld}',
    );
  }
  if (request.favoriteTopics.isNotEmpty) {
    lines.add(
      '- Things $name loves, to weave in naturally where they fit: '
      '${request.favoriteTopics}',
    );
  }
  return lines.join('\n');
}

/// Extra page-writing rules for the saved preferences that are present.
String _preferenceRules(StoryGenerationRequest request) {
  final rules = <String>[];
  if (request.recurringWorld.isNotEmpty) {
    rules.add(
      '7a. The story happens in the family\'s recurring world named above. '
      'Name it and let its details show, so it feels like the same place as '
      'the child\'s other books.',
    );
  }
  if (request.favoriteTopics.isNotEmpty) {
    rules.add(
      '7b. Let the things the child loves appear where the plot has room for '
      'them. Weave them in; do not list them and do not force one into every '
      'page.',
    );
  }
  return rules.isEmpty ? '' : '${rules.join('\n')}\n';
}

/// The single-language rule, sharpened for Arabic.
///
/// Arabic is called out because it is where a small model fails loudest: it
/// slips into a dialect, drops in English words, or writes Arabic in Latin
/// letters. The same "one language only" rule is stated for the others.
String _languageRule(StoryGenerationRequest request) {
  return switch (request.language) {
    StoryLanguage.arabic =>
      'Write in simple Modern Standard Arabic (فصحى مبسطة) suitable for '
          'children: grammatically correct fully-inflected sentences, short and '
          'clear. Do NOT mix in any spoken dialect (no Egyptian, Levantine, '
          'Gulf, Maghrebi or other colloquial forms). Do NOT use any Latin '
          'letters or Latin-script words anywhere in the title or the pages, '
          'and do not transliterate. Every letter of the story text must be '
          'Arabic script. Diacritics are optional; use them only where a word '
          'would otherwise be ambiguous for a child.',
    StoryLanguage.english =>
      'Write in English only. Do not use words, names or letters from any '
          'other language or script anywhere in the title or the pages.',
    StoryLanguage.swedish =>
      'Write in Swedish only, with correct Swedish spelling including å, ä '
          'and ö. Do not slip into English and do not use letters from any '
          'other script anywhere in the title or the pages.',
    StoryLanguage.somali =>
      'Write in Somali only, using standard Somali orthography. Do not slip '
          'into English or Arabic, and do not use letters from any other '
          'script anywhere in the title or the pages.',
  };
}

/// The vocabulary and sentence-length rule for the reader's age.
///
/// The age already travels with every request, so the reading level is not a
/// guess: a five-year-old and a twelve-year-old get genuinely different prose.
String _readingLevelRule(StoryGenerationRequest request) {
  final age = request.ageYears;
  if (age <= 4) {
    return 'Write for a $age-year-old being read to: very short sentences of '
        'about five to eight words, only everyday words a toddler hears at '
        'home, lots of sound and repetition, and no subordinate clauses.';
  }
  if (age <= 7) {
    return 'Write for a $age-year-old: short sentences of about eight to '
        'twelve words, concrete everyday vocabulary, at most one simple '
        'clause joined with "and" or "but", and feelings named plainly.';
  }
  if (age <= 10) {
    return 'Write for a $age-year-old: sentences of about twelve to sixteen '
        'words with some variety in rhythm, a few richer words explained by '
        'their context, and simple description as well as action.';
  }
  return 'Write for a $age-year-old: full, varied sentences up to about '
      'twenty words, a wider vocabulary, some inner thought as well as '
      'action, and no babyish wording — but keep it warm and never grim.';
}
