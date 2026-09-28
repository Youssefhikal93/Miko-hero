import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';

/// Longest accepted value of one character-sheet field.
///
/// Every field is a short English phrase, and all five are joined into the one
/// appearance line that is repeated into every page's scene description. Short
/// is not a style preference here: a paragraph of costume crowds the scene out
/// of its own prompt.
const int maximumCharacterSheetFieldLength = 80;

/// How one child's drawn hero looks, kept identical across every story.
///
/// This is a description of a **drawn cartoon character**, in English. It is
/// derived from the child's reference photo but is never a description of the
/// photo, of a photograph, or of a real person: only three colour-ish traits
/// come from the picture, and the costume comes from a curated wardrobe that
/// has never seen it.
///
/// [photoHash] is the fingerprint of the photo the three derived traits came
/// from. It is what makes the sheet a cache: the same photo answers from the
/// database, a replaced photo re-derives, and a photo that never changes never
/// costs a model call again.
///
/// A sheet may also exist **before** anything has been read from a photo: a
/// parent who tells the PC what their hero always wears writes the wardrobe
/// half on its own, and the three derived traits stay empty until there is a
/// photo to read them from. [isDerived] is the question every caller
/// downstream asks before using the line.
class HeroCharacterSheet {
  /// Creates a sheet.
  const HeroCharacterSheet({
    required this.profileId,
    required this.hair,
    required this.skinTone,
    required this.eyeColor,
    required this.outfit,
    required this.prop,
    required this.photoHash,
    required this.updatedAtUtc,
  });

  /// Profile whose hero this describes.
  final String profileId;

  /// Drawn hair, e.g. `short curly black hair`. Derived from the photo.
  final String hair;

  /// Drawn skin tone, e.g. `warm brown`. Derived from the photo.
  final String skinTone;

  /// Drawn eye colour, e.g. `dark brown`. Derived from the photo.
  final String eyeColor;

  /// The recurring outfit. Chosen once and kept across photo changes.
  final String outfit;

  /// The recurring prop. Chosen once and kept across photo changes.
  final String prop;

  /// SHA-256 of the photo the derived traits were read from.
  final String photoHash;

  /// When the sheet was last written.
  final DateTime updatedAtUtc;

  /// Whether the three traits that come from the photo have been read.
  ///
  /// False for a sheet holding only the wardrobe a parent typed: there is a
  /// hero being dressed, but nobody has looked at the child's photo yet, so
  /// there is no drawn face to promise. The story planner treats that exactly
  /// as it treats no sheet at all and invents the appearance itself.
  bool get isDerived =>
      hair.isNotEmpty &&
      skinTone.isNotEmpty &&
      eyeColor.isNotEmpty &&
      photoHash.isNotEmpty;

  /// The one English line the story planner and the illustrator both use.
  ///
  /// Deliberately the same shape the outline pass used to invent — hair,
  /// colours, clothes, one recurring prop — so everything downstream
  /// (`withHeroAppearance`, the scene descriptions, the picture prompts) keeps
  /// working unchanged; only the author of the line has changed.
  ///
  /// A part nobody has filled in is left out rather than written as an empty
  /// gap: a hero described as ` skin,  eyes` would be worse than a hero
  /// described in four words.
  String toPromptLine() {
    return <String>[
      hair,
      if (skinTone.isNotEmpty) '$skinTone skin',
      if (eyeColor.isNotEmpty) '$eyeColor eyes',
      outfit,
      prop,
    ].where((part) => part.isNotEmpty).join(', ');
  }

  /// Returns a copy wearing [outfit] and carrying [prop].
  ///
  /// The derived half is untouched: the PC owns what was read from the photo,
  /// and the parent owns what the hero wears and carries.
  HeroCharacterSheet withWardrobe({
    required String outfit,
    required String prop,
    required DateTime updatedAtUtc,
  }) {
    return HeroCharacterSheet(
      profileId: profileId,
      hair: hair,
      skinTone: skinTone,
      eyeColor: eyeColor,
      outfit: outfit,
      prop: prop,
      photoHash: photoHash,
      updatedAtUtc: updatedAtUtc,
    );
  }

  /// JSON shape the hero-sheet endpoints answer with.
  ///
  /// Private content in the same sense the photo is, so it travels only to a
  /// paired device that asked for this profile by id, and never into a log.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'hair': hair,
      'skinTone': skinTone,
      'eyeColor': eyeColor,
      'outfit': outfit,
      'prop': prop,
      'photoHash': photoHash,
      'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
    };
  }

  /// Returns a copy carrying freshly derived traits and [photoHash].
  ///
  /// The outfit and the prop are carried over untouched: they are the part of
  /// the hero that must not move when a parent uploads a newer photo.
  HeroCharacterSheet withDerivedTraits({
    required String hair,
    required String skinTone,
    required String eyeColor,
    required String photoHash,
    required DateTime updatedAtUtc,
  }) {
    return HeroCharacterSheet(
      profileId: profileId,
      hair: hair,
      skinTone: skinTone,
      eyeColor: eyeColor,
      outfit: outfit,
      prop: prop,
      photoHash: photoHash,
      updatedAtUtc: updatedAtUtc,
    );
  }
}

/// Reads and writes the `hero_character_sheets` rows of the master library.
///
/// The sheet is private content in the same sense the photo is — it is how one
/// particular child's hero looks — so it is never logged, and it leaves the PC
/// only through the three `/profiles/<id>/hero-sheet` endpoints, to a paired
/// device that asked for one named profile. It is deliberately **not** part of
/// the sync manifest: a manifest is broadcast metadata every device downloads
/// wholesale, and how one child is drawn is not that.
class CharacterSheetStore {
  /// Creates a store over [library].
  const CharacterSheetStore({required this.library});

  /// The initialized master library this store queries.
  final MasterLibrary library;

  /// Returns the stored sheet of [profileId], or `null` when there is none.
  HeroCharacterSheet? findSheet(String profileId) {
    final rows = library.database.select(
      'SELECT hair, skin_tone, eye_color, outfit, prop, photo_hash, '
      'updated_at_utc FROM hero_character_sheets WHERE profile_id = ?',
      <Object?>[profileId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return HeroCharacterSheet(
      profileId: profileId,
      hair: row['hair']! as String,
      skinTone: row['skin_tone']! as String,
      eyeColor: row['eye_color']! as String,
      outfit: row['outfit']! as String,
      prop: row['prop']! as String,
      photoHash: row['photo_hash']! as String,
      updatedAtUtc: DateTime.parse(row['updated_at_utc']! as String).toUtc(),
    );
  }

  /// Inserts or replaces the sheet of [sheet]'s profile.
  ///
  /// `created_at_utc` is preserved across a refresh, so the row still says
  /// when this child's hero was first drawn.
  void saveSheet(HeroCharacterSheet sheet) {
    final db = library.database;
    final stamp = sheet.updatedAtUtc.toUtc().toIso8601String();
    runInDatabaseTransaction(db, () {
      db.execute(
        'INSERT INTO hero_character_sheets '
        '(profile_id, hair, skin_tone, eye_color, outfit, prop, photo_hash, '
        ' created_at_utc, updated_at_utc) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(profile_id) DO UPDATE SET '
        ' hair = excluded.hair, skin_tone = excluded.skin_tone, '
        ' eye_color = excluded.eye_color, outfit = excluded.outfit, '
        ' prop = excluded.prop, photo_hash = excluded.photo_hash, '
        ' updated_at_utc = excluded.updated_at_utc',
        <Object?>[
          sheet.profileId,
          sheet.hair,
          sheet.skinTone,
          sheet.eyeColor,
          sheet.outfit,
          sheet.prop,
          sheet.photoHash,
          stamp,
          stamp,
        ],
      );
    });
  }

  /// Stores what [profileId]'s hero always wears and carries.
  ///
  /// The half of the sheet the **parent** owns, written without touching the
  /// half the PC read from the photo. A profile that has no sheet yet gets one
  /// carrying the wardrobe alone: the derived traits stay empty until there is
  /// a photo to read, and the parent's choice is not lost in the meantime.
  ///
  /// Returns the sheet as it now stands.
  HeroCharacterSheet saveWardrobe({
    required String profileId,
    required String outfit,
    required String prop,
    required DateTime nowUtc,
  }) {
    final HeroCharacterSheet? stored = findSheet(profileId);
    final HeroCharacterSheet saved =
        stored?.withWardrobe(
          outfit: outfit,
          prop: prop,
          updatedAtUtc: nowUtc,
        ) ??
        HeroCharacterSheet(
          profileId: profileId,
          hair: '',
          skinTone: '',
          eyeColor: '',
          outfit: outfit,
          prop: prop,
          photoHash: '',
          updatedAtUtc: nowUtc,
        );
    saveSheet(saved);
    return saved;
  }
}
