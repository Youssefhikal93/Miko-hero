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
    required this.beats,
  });

  /// Working title in the requested story language.
  final String title;

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
    'required': <String>['title', 'heroAppearance', 'beats'],
  };
}

/// Validates one outline answer against every structural rule.
///
/// Rules: valid JSON object, non-empty title, non-empty one-line hero
/// appearance written in Latin script, exactly [expectedPageCount] beats, beat
/// numbers running 1..N in order, and a non-empty summary on every beat. Any violation raises a
/// [GenerationException] with [GenerationFailureCode.invalidModelOutput], so a
/// bad plan costs a retry instead of producing a bad book.
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
    beats: List<StoryOutlineBeat>.unmodifiable(beats),
  );
}

/// Collapses line breaks so the appearance sheet stays a single line.
String _oneLine(String value) {
  return value.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
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
