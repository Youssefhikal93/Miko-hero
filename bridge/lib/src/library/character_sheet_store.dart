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

  /// The one English line the story planner and the illustrator both use.
  ///
  /// Deliberately the same shape the outline pass used to invent — hair,
  /// colours, clothes, one recurring prop — so everything downstream
  /// (`withHeroAppearance`, the scene descriptions, the picture prompts) keeps
  /// working unchanged; only the author of the line has changed.
  String toPromptLine() {
    return '$hair, $skinTone skin, $eyeColor eyes, $outfit, $prop';
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
/// particular child's hero looks — so it is never logged and never echoed in a
/// response. It is deliberately **not** part of the sync manifest yet: this
/// milestone keeps it on the PC.
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
}
