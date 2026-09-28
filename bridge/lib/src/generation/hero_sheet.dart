import 'dart:convert';

import 'package:iam_hero_bridge/src/common/secrets.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/language_purity.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/library/character_sheet_store.dart';

/// The three traits the vision pass reads off a reference photo.
///
/// Deliberately three colours and nothing else. Everything a picture needs
/// beyond them — the clothes, the prop — comes from [heroOutfitWardrobe] and
/// [heroPropWardrobe], which never see the photo at all.
class HeroSheetTraits {
  /// Creates a validated trait triple.
  const HeroSheetTraits({
    required this.hair,
    required this.skinTone,
    required this.eyeColor,
  });

  /// Drawn hair, e.g. `short curly black hair`.
  final String hair;

  /// Drawn skin tone, e.g. `warm brown`.
  final String skinTone;

  /// Drawn eye colour, e.g. `dark brown`.
  final String eyeColor;
}

/// JSON schema handed to Ollama for the character-sheet pass.
///
/// Three short strings, nothing nested. The pass runs on whatever small
/// vision model the PC has, and a small model answers a flat schema far more
/// reliably than a shaped one.
Map<String, Object?> heroSheetResponseSchema() {
  return <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'hair': <String, Object?>{'type': 'string'},
      'skinTone': <String, Object?>{'type': 'string'},
      'eyeColor': <String, Object?>{'type': 'string'},
    },
    'required': <String>['hair', 'skinTone', 'eyeColor'],
  };
}

/// Builds the prompt of the character-sheet pass.
///
/// The whole prompt is one instruction repeated from several angles: you are
/// describing a **drawn cartoon character**, not a photograph and not a person.
/// That framing is not politeness. The output of this call is stored, then
/// pasted into every story's scene descriptions and into the picture model, so
/// a sentence that described the real child — an expression, a birthmark, the
/// clothes they happened to be wearing, a guess at who they are — would travel
/// into every book and out to every paired device. Three colours cannot do
/// that; a free-form description of a photo could.
///
/// It is also why clothing is refused here and chosen from a curated wardrobe
/// instead: asked about clothes, a vision model describes the jumper in the
/// picture, which is both an identifying detail and a costume that changes
/// every time a parent uploads a newer photo.
String buildHeroSheetPrompt() {
  return '''
You are helping to design a DRAWN CARTOON CHARACTER for a children's picture
book. The character will be drawn by an illustrator; nothing you write is
about a real person.

Use the attached picture only to choose three colours for the drawing, and
answer with three short English phrases:
- "hair": how the drawn character's hair looks, for example "short curly
  black hair" or "long straight light brown hair".
- "skinTone": one plain colour phrase for the drawn skin, for example
  "warm brown" or "light olive".
- "eyeColor": one plain colour phrase for the drawn eyes, for example
  "dark brown" or "grey-green".

Hard requirements:
1. Write about a drawn cartoon character only. Never mention a photo, a
   photograph, a picture, a camera, an image, or a real person, and never
   say what you can or cannot see.
2. Never describe identity or anything identifying: no name, no age, no
   gender, no expression or mood, no clothing, no background, no glasses,
   jewellery, scars, birthmarks or any other distinguishing mark, and no
   guess about who anyone is.
3. Write in English with Latin letters only. Each value is at most six
   words, lower case, with no full stop and no quotation marks.
4. If a colour is unclear, choose the nearest ordinary one. Never refuse,
   never apologise, and never explain.

Answer with one JSON object matching the requested schema and nothing else.
''';
}

/// Validates one character-sheet answer against every structural rule.
///
/// Rules: valid JSON object, three non-empty short values, each written in
/// Latin script because the line it becomes is read by the picture model. Any
/// violation raises a [GenerationException] with
/// [GenerationFailureCode.invalidModelOutput]; the caller treats that as "no
/// sheet this time" and keeps whatever was already stored.
HeroSheetTraits parseHeroSheetTraits(String responseText) {
  final Object? decoded;
  try {
    decoded = jsonDecode(responseText);
  } on FormatException {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The character sheet was not valid JSON.',
    );
  }
  if (decoded is! Map<String, Object?>) {
    throw const GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The character sheet was not a JSON object.',
    );
  }
  return HeroSheetTraits(
    hair: _requireTrait(decoded['hair'], field: 'hair'),
    skinTone: _requireTrait(decoded['skinTone'], field: 'skinTone'),
    eyeColor: _requireTrait(decoded['eyeColor'], field: 'eyeColor'),
  );
}

/// The curated outfits one recurring hero costume is chosen from.
///
/// A fixed wardrobe rather than a model's invention, for three reasons that
/// all point the same way. The vision model must not be asked about clothing
/// at all (see [buildHeroSheetPrompt]). A small local model asked to invent a
/// costume in the abstract produces something different every run, which is
/// exactly the drift this whole ticket exists to remove. And every entry here
/// was written once to be English, drawn, colour-forward and appropriate for a
/// picture book — properties a generated line has to be re-checked for on
/// every single call.
///
/// The choice is deterministic per profile, so one child keeps one coat for as
/// long as the profile exists, and two children in a family are very unlikely
/// to share one.
const List<String> heroOutfitWardrobe = <String>[
  'wearing a mustard-yellow raincoat over a striped shirt',
  'wearing a forest-green hooded jumper and denim dungarees',
  'wearing a red knitted cardigan over a white collared shirt',
  'wearing a teal windbreaker with the sleeves rolled up',
  'wearing a plum-purple tunic with big patch pockets',
  'wearing an orange smock over soft grey trousers',
  'wearing a sky-blue dungaree dress over a long-sleeved top',
  'wearing a rust-brown corduroy jacket and cream trousers',
];

/// The curated props one recurring hero keepsake is chosen from.
///
/// Same reasoning as [heroOutfitWardrobe]: one small object the illustrator can
/// put in the hero's hands on every page is worth more to a book's continuity
/// than a cleverer one that changes.
const List<String> heroPropWardrobe = <String>[
  'carrying a small brass lantern',
  'carrying a well-worn cloth satchel',
  'carrying a folded paper boat',
  'carrying a stubby wooden telescope',
  'carrying a speckled green notebook',
  'carrying a knitted rabbit with one floppy ear',
  'wearing a bright red woollen scarf',
  'wearing a battered straw sun hat',
];

/// The outfit [profileId]'s hero wears in every book.
String pickHeroOutfit(String profileId) =>
    _pick(heroOutfitWardrobe, 'outfit:$profileId');

/// The prop [profileId]'s hero carries in every book.
String pickHeroProp(String profileId) =>
    _pick(heroPropWardrobe, 'prop:$profileId');

/// Builds the sheet stored for [profileId] from freshly derived [traits].
///
/// [previous] is whatever was stored before. Its outfit and prop are kept —
/// that is the rule this function exists to enforce: a new photo repaints the
/// hair and the colouring, and leaves the hero dressed exactly as the family's
/// last book left them.
HeroCharacterSheet buildHeroCharacterSheet({
  required String profileId,
  required HeroSheetTraits traits,
  required String photoHash,
  required DateTime nowUtc,
  HeroCharacterSheet? previous,
}) {
  if (previous != null) {
    return previous.withDerivedTraits(
      hair: traits.hair,
      skinTone: traits.skinTone,
      eyeColor: traits.eyeColor,
      photoHash: photoHash,
      updatedAtUtc: nowUtc,
    );
  }
  return HeroCharacterSheet(
    profileId: profileId,
    hair: traits.hair,
    skinTone: traits.skinTone,
    eyeColor: traits.eyeColor,
    outfit: pickHeroOutfit(profileId),
    prop: pickHeroProp(profileId),
    photoHash: photoHash,
    updatedAtUtc: nowUtc,
  );
}

/// Deterministically chooses one entry of [options] for [namespace].
///
/// Hashed rather than taken modulo the raw id, so two profiles whose uuids
/// happen to be adjacent do not land on adjacent wardrobes, and so the outfit
/// and the prop of one profile are independent rolls.
String _pick(List<String> options, String namespace) {
  final digest = sha256Hex(namespace);
  final value = int.parse(digest.substring(0, 8), radix: 16);
  return options[value % options.length];
}

String _requireTrait(Object? value, {required String field}) {
  if (value is! String || value.trim().isEmpty) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The character sheet was missing $field.',
    );
  }
  final trimmed = value.trim().replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ');
  if (trimmed.length > maximumCharacterSheetFieldLength) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The character sheet exceeded the accepted length for $field.',
    );
  }
  // The line this becomes is read by the picture model, which reads Latin
  // letters. Any other script would be noise in every page's prompt.
  if (!checkLanguagePurity(
    language: StoryLanguage.english,
    texts: <String>[trimmed],
  ).isPure) {
    throw GenerationException(
      GenerationFailureCode.invalidModelOutput,
      'The character sheet field $field must be written in English.',
    );
  }
  return trimmed;
}
