import 'dart:convert';

import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/language_purity.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Longest accepted outline title.
const int maximumOutlineTitleLength = 200;

/// Longest accepted hero appearance sheet.
///
/// One line is the whole point: it is repeated into every page's scene
/// description, so a paragraph here would crowd out the scene itself.
const int maximumHeroAppearanceLength = 300;

/// Longest accepted summary of one page's beat.
const int maximumOutlineBeatLength = 400;

/// Longest accepted lesson moment.
///
/// One sentence is the whole point: it is repeated into the page prompt as the
/// situation the middle of the book is built around, so a paragraph here would
/// re-plan the story instead of anchoring it.
const int maximumLessonMomentLength = 400;

/// One page's beat in the plan the first pass produces.
class StoryOutlineBeat {
  /// Creates a validated beat.
  const StoryOutlineBeat({required this.pageNumber, required this.summary});

  /// One-based page number; always equal to the beat's position.
  final int pageNumber;

  /// One sentence saying what happens on that page.
  final String summary;
}

/// The plan of one story, produced by the first generation pass.
///
/// An outline only ever exists when every rule passed, exactly like a story
/// draft: the page-writing pass is never handed a half-built plan.
class StoryOutline {
  /// Creates a validated outline.
  const StoryOutline({
    required this.title,
    required this.heroAppearance,
    required this.lessonMoment,
    required this.turnPage,
    required this.beats,
  });

  /// Working title in the requested story language.
  final String title;

  /// The concrete situation where the hero faces the parent's lesson.
  ///
  /// One sentence in the story's own language — not the moral restated, but
  /// the moment it is tested. This is the spine: the page pass is told the
  /// middle of the book *is* this situation, which is what stops the lesson
  /// evaporating into a line nobody wrote a scene for.
  final String lessonMoment;

  /// One-based page where the hero chooses the lesson.
  ///
  /// Always in the middle of the book — never page 1, never the last page —
  /// so the hero has room to do the opposite first and room to live with the
  /// choice afterwards.
  final int turnPage;

  /// One-line description of how the hero looks, invented by the model.
  ///
  /// Appended to every page's scene description so the illustrator draws the
  /// same child in the same clothes on every page. Never derived from a real
  /// photo: the model is told to invent it.
  final String heroAppearance;

  /// Ordered beats, exactly as many as there are pages.
  final List<StoryOutlineBeat> beats;

  /// Renders the outline as the compact plan block the second pass receives.
  ///
  /// Plain text rather than JSON: the second pass has to read it, and a small
  /// model follows a numbered list far more reliably than a nested object.
  String toPromptBlock() {
    final lines = <String>[
      'Working title: $title',
      'Hero appearance (keep identical on every page): $heroAppearance',
      'Lesson moment (what the middle of the book is about): $lessonMoment',
      'Turn page (where the hero chooses the lesson): $turnPage',
      'Page beats:',
      for (final beat in beats) '${beat.pageNumber}. ${beat.summary}',
    ];
    return lines.join('\n');
  }
}

/// JSON schema handed to Ollama for the outline pass.
///
/// Deliberately tiny. The first call has to be cheap and easy to get right,
/// because everything the second call writes hangs off it.
Map<String, Object?> storyOutlineResponseSchema(int pageCount) {
  return <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'title': <String, Object?>{'type': 'string'},
      'heroAppearance': <String, Object?>{'type': 'string'},
      'lessonMoment': <String, Object?>{'type': 'string'},
      'turnPage': <String, Object?>{'type': 'integer'},
      'beats': <String, Object?>{
        'type': 'array',
        'minItems': pageCount,
        'maxItems': pageCount,
        'items': <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'pageNumber': <String, Object?>{'type': 'integer'},
            'summary': <String, Object?>{'type': 'string'},
          },
          'required': <String>['pageNumber', 'summary'],
        },
      },
    },
    'required': <String>[
      'title',
      'heroAppearance',
      'lessonMoment',
      'turnPage',
      'beats',
    ],
  };
}

/// Validates one outline answer against every structural rule.
///
/// Rules: valid JSON object, non-empty title, non-empty one-line hero
/// appearance written in Latin script, a non-empty lesson moment, a turn page
/// inside the middle of the book, exactly [expectedPageCount] beats, beat
/// numbers running 1..N in order, and a non-empty summary on every beat. Any violation raises a
/// [GenerationException] with [GenerationFailureCode.invalidModelOutput], so a
/// bad plan costs a retry instead of producing a bad book.
///
/// The lesson moment's *language* is not checked here: it belongs to the story
/// language, which this function is deliberately not told about, so the queue
/// runs it through the same purity check as the title and the beats.
StoryOutline parseStoryOutline(
  String responseText, {
  required int expectedPageCount,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseText);
  } on FormatException {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline was not valid JSON.',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline was not a JSON object.',
    );
  }
  final title = _requireOutlineText(
    decoded['title'],
    field: 'the outline title',
    maxLength: maximumOutlineTitleLength,
  );
  final heroAppearance = _requireOutlineText(
    decoded['heroAppearance'],
    field: 'the hero appearance line',
    maxLength: maximumHeroAppearanceLength,
  );
  // The appearance line is consumed only by the image model, which reads
  // Latin letters. Written in the story's own script — which happens for
  // Arabic books — it becomes noise in every page's scene and the pictures
  // lose the mood the text describes. Refusing it here costs one retry.
  final appearanceScript = checkLanguagePurity(
    language: StoryLanguage.english,
    texts: <String>[heroAppearance],
  );
  if (!appearanceScript.isPure) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The hero appearance line must be written in English.',
    );
  }
  final lessonMoment = _requireOutlineText(
    decoded['lessonMoment'],
    field: 'the lesson moment',
    maxLength: maximumLessonMomentLength,
  );
  final turnPage = _requireTurnPage(
    decoded['turnPage'],
    expectedPageCount: expectedPageCount,
  );
  final Object? rawBeats = decoded['beats'];
  if (rawBeats is! List) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline had no page beats.',
    );
  }
  if (rawBeats.length != expectedPageCount) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline had ${rawBeats.length} beats instead of '
      '$expectedPageCount.',
    );
  }
  final beats = <StoryOutlineBeat>[];
  for (var index = 0; index < rawBeats.length; index++) {
    final Object? rawBeat = rawBeats[index];
    if (rawBeat is! Map<String, Object?>) {
      throw GenerationException(
        GenerationFailureCode.invalidModelOutput,
        'Outline beat ${index + 1} was not a JSON object.',
      );
    }
    final Object? rawNumber = rawBeat['pageNumber'];
    if (rawNumber is! int || rawNumber != index + 1) {
      throw GenerationException(
        GenerationFailureCode.invalidModelOutput,
        'Outline beats must run 1 to $expectedPageCount in order.',
      );
    }
    beats.add(
      StoryOutlineBeat(
        pageNumber: rawNumber,
        summary: _requireOutlineText(
          rawBeat['summary'],
          field: 'the summary of outline beat ${index + 1}',
          maxLength: maximumOutlineBeatLength,
        ),
      ),
    );
  }
  return StoryOutline(
    title: title,
    heroAppearance: _oneLine(heroAppearance),
    lessonMoment: _oneLine(lessonMoment),
    turnPage: turnPage,
    beats: List<StoryOutlineBeat>.unmodifiable(beats),
  );
}

/// Collapses line breaks so the appearance sheet stays a single line.
String _oneLine(String value) {
  return value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
}

/// Validates the turn page and returns it.
///
/// "The middle" is defined as strictly between the first and the last page:
/// `1 < turnPage < expectedPageCount`. Page 1 is the warm ordinary opening, so
/// a turn there leaves no room for the hero to do the opposite first; the last
/// page is the resolution, so a turn there is the moral announced at the end —
/// exactly the failure this plan exists to prevent. Everything in between is
/// accepted: a six-page book turns on 2, 3, 4 or 5.
int _requireTurnPage(Object? value, {required int expectedPageCount}) {
  if (value is! int) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline was missing the turn page.',
    );
  }
  if (value <= 1 || value >= expectedPageCount) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The turn page must be in the middle of the book: after page 1 and '
      'before page $expectedPageCount.',
    );
  }
  return value;
}

String _requireOutlineText(
  Object? value, {
  required String field,
  required int maxLength,
}) {
  if (value is! String || value.trim().isEmpty) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline was missing $field.',
    );
  }
  final trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The model outline exceeded the accepted length for $field.',
    );
  }
  return trimmed;
}
