import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Minimum number of sentences demanded per page.
const int minimumSentencesPerPage = 2;

/// Maximum number of sentences demanded per page.
const int maximumSentencesPerPage = 4;

/// Builds the JSON schema handed to Ollama in the `format` field.
///
/// Structured output alone is not trusted — the answer is validated again by
/// [parseStoryDraft] — but the schema removes most of the model's freedom to
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

/// Builds the generation prompt for [request].
///
/// The result contains the child's name and the parent's idea, so it is
/// private content: it is sent to the local model and never logged.
String buildStoryPrompt(StoryGenerationRequest request) {
  final language = request.language.englishName;
  final gender = request.gender.wireName;
  final pronoun = request.gender.subjectPronoun;
  final possessive = request.gender.pronoun;
  final pageCount = request.pageCount;
  final name = request.heroName;

  return '''
You are a warm, careful children's storybook author writing one complete
picture-book story for a single family.

The hero:
- Name: $name
- The hero is a $gender; refer to $name with "$pronoun" and "$possessive"
  wording that is natural in $language.
- Age of the child who will read it: ${request.ageYears} years old.

The story:
- Setting or adventure idea: ${request.theme}
- Lesson the story must teach through what $name does: ${request.moral}

Hard requirements:
1. Write the title and ALL page text ONLY in $language. Do not write any
   story text in any other language, and do not translate or transliterate.
2. Produce EXACTLY $pageCount pages, numbered 1 to $pageCount in order,
   with no missing or repeated numbers.
3. Every page has $minimumSentencesPerPage to $maximumSentencesPerPage
   complete sentences of flowing prose — no headings, lists or page labels
   inside the text.
4. $name is the hero on every page and the story reads as one continuous
   arc: a beginning, a small problem, $possessive own choice that solves it,
   and a calm hopeful ending on the last page.
5. Keep everything gentle and appropriate for a ${request.ageYears}-year-old:
   no violence, death, horror, romance, brands or scary imagery.
6. Show the lesson through actions and feelings; never end with a stated
   moral or an address to the reader.
7. Give every page an "illustrationScene" written ONLY in English, one or
   two sentences describing what a picture on that page shows: who is in it,
   what they are doing, the place, the light and the mood. Style direction to
   mention: ${request.illustrationStyle.englishDirection}. Never put story
   text, letters, words or speech bubbles into the scene description.
8. Give a short title in $language, at most eight words.

Answer with one JSON object matching the requested schema and nothing else.
''';
}
