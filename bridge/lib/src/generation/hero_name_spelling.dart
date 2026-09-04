import 'dart:convert';

import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/language_purity.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';

/// Longest accepted spelling of one hero name in one language.
///
/// The same bound the wire puts on `heroName`, because a spelling *is* the
/// name: a value longer than the name it spells is a sentence, not a name.
const int maximumHeroNameSpellingLength = maximumHeroNameLength;

/// Largest number of words one spelling may be written in.
///
/// A given name is one or two words; four leaves room for a name that really
/// is written apart while still refusing "Malika (pronounced ma-LEE-ka)". The
/// prompt says "four words" in its own sentence rather than interpolating this,
/// so the instruction stays one readable line however this constant moves.
const int maximumHeroNameSpellingWords = 4;

/// JSON schema handed to Ollama for the name-spelling pass.
///
/// One short string per supported language and nothing nested, for the same
/// reason the character sheet's schema is flat: a small local model answers a
/// flat schema far more reliably than a shaped one.
Map<String, Object?> heroNameSpellingResponseSchema() {
  return <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      for (final language in StoryLanguage.values)
        language.code: <String, Object?>{'type': 'string'},
    },
    'required': <String>[
      for (final language in StoryLanguage.values) language.code,
    ],
  };
}

/// Builds the prompt of the name-spelling pass.
///
/// The whole prompt says one thing from several angles: this is the **same
/// name**, written the way each language writes it. That framing is the point
/// of the ticket — a model asked loosely translates "Malika" into an Arabic
/// word meaning queen, or invents a different name entirely, and the family
/// then reads a book about a child who is not theirs.
///
/// The result contains the child's name, so it is private content: it goes to
/// the local model and is never logged.
String buildHeroNameSpellingPrompt({
  required String heroName,
  StoryGenderContext? gender,
}) {
  final who = gender == null ? "child's" : "${gender.wireName}'s";
  return '''
You write one $who given name in four languages, for a family storybook.

The name, exactly as the parent typed it: $heroName

Answer with that same name written the way readers of each language write it:
- "ar": Arabic script.
- "en": Latin letters, English spelling.
- "sv": Latin letters, Swedish spelling.
- "so": Latin letters, Somali spelling.

Hard requirements:
1. It stays the same name. Write how it sounds in that language's letters
   and spelling. Never translate it into a word that means something,
   never replace it with a different name, and never add a surname, a
   nickname, a title or an honorific.
2. Each value is the name and nothing else: at most four words, with no
   quotation marks, no brackets, no pronunciation guide, no explanation.
3. "ar" must be written entirely in Arabic letters, with no Latin letters at
   all. "en", "sv" and "so" must be written entirely in Latin letters.
4. If the name is already written the way one of these languages writes it,
   repeat it unchanged for that language.

Answer with one JSON object matching the requested schema and nothing else.
''';
}

/// Validates one name-spelling answer against every structural rule.
///
/// Rules: valid JSON object, one non-empty short value per language, each
/// written in the script that language is read in. Any violation raises a
/// [GenerationException] with [GenerationFailureCode.invalidModelOutput]; the
/// caller turns that into "no suggestion this time" and the parent types the
/// spellings by hand, which is always allowed.
Map<StoryLanguage, String> parseHeroNameSpellings(String responseText) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseText);
  } on FormatException {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The name spellings were not valid JSON.',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The name spellings were not a JSON object.',
    );
  }
  return Map<StoryLanguage, String>.unmodifiable(<StoryLanguage, String>{
    for (final language in StoryLanguage.values)
      language: _requireSpelling(decoded[language.code], language),
  });
}

/// Accepts one language's spelling or refuses it by field name only.
///
/// The value itself never reaches the message: it is a child's name.
String _requireSpelling(Object? value, StoryLanguage language) {
  if (value is! String || value.trim().isEmpty) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The name spellings were missing ${language.code}.',
    );
  }
  final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (trimmed.length > maximumHeroNameSpellingLength) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The ${language.code} name spelling exceeded the accepted length.',
    );
  }
  if (trimmed.split(' ').length > maximumHeroNameSpellingWords) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The ${language.code} name spelling was a phrase, not a name.',
    );
  }
  // The whole point of the pass: an Arabic spelling written in Latin letters
  // is the transliteration this ticket exists to remove.
  if (!checkLanguagePurity(
    language: language,
    texts: <String>[trimmed],
    heroNameIsSpelled: true,
  ).isPure) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The ${language.code} name spelling was not written in that '
      "language's script.",
    );
  }
  return trimmed;
}
