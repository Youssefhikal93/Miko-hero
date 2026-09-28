import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/illustration/illustration_repository.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';

/// One child profile as the management endpoints describe it.
///
/// Metadata only. The photo is reported as a yes-or-no, never as bytes and
/// never as a path: whether a child has a reference photo is something the
/// owner needs to know, and what the child looks like is not something an
/// HTTP answer should carry.
class ProfileSummary {
  /// Creates a profile summary.
  const ProfileSummary({
    required this.id,
    required this.displayName,
    required this.hasPhoto,
    required this.storyCount,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  /// Stable id of the `profiles` row.
  final String id;

  /// The hero's name as the last story generation spelled it.
  final String displayName;

  /// Whether a reference photo is stored for this profile.
  final bool hasPhoto;

  /// How many stories this profile owns right now.
  final int storyCount;

  /// When the profile first appeared in the master library.
  final DateTime createdAtUtc;

  /// When the profile, its name or its photo last changed.
  final DateTime updatedAtUtc;

  /// JSON shape returned by `GET /profiles`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'displayName': displayName,
      'hasPhoto': hasPhoto,
      'storyCount': storyCount,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }
}

/// How far along one story's pictures are, as three counts.
///
/// The three always add up to the number of illustration rows the story has:
/// anything that is neither `completed` nor `failed` is still pending, so a
/// status this build does not know cannot make a page disappear from the
/// tally.
class IllustrationTally {
  /// Creates a tally.
  const IllustrationTally({
    required this.pending,
    required this.completed,
    required this.failed,
  });

  /// Pages queued or waiting to be drawn.
  final int pending;

  /// Pages with a stored image file.
  final int completed;

  /// Pages whose render did not succeed.
  final int failed;

  /// JSON shape embedded in a story summary.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'pending': pending,
      'completed': completed,
      'failed': failed,
    };
  }
}

/// One story as the management endpoints describe it.
///
/// Titles travel, page prose never does: `GET /stories` is a table of
/// contents, and `GET /stories/<storyId>` is where the book itself is read.
class StorySummary {
  /// Creates a story summary.
  const StorySummary({
    required this.id,
    required this.profileId,
    required this.title,
    required this.languageCode,
    required this.pageCount,
    required this.illustrations,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  /// Stable id of the `stories` row.
  final String id;

  /// Child profile owning the story.
  final String profileId;

  /// Story title in the story language.
  final String title;

  /// Two-letter language code of every page.
  final String languageCode;

  /// How many pages the story has.
  final int pageCount;

  /// Illustration progress across those pages.
  final IllustrationTally illustrations;

  /// When the story was written to the library.
  final DateTime createdAtUtc;

  /// When the story last changed.
  final DateTime updatedAtUtc;

  /// JSON shape returned by `GET /stories`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'profileId': profileId,
      'title': title,
      'languageCode': languageCode,
      'pageCount': pageCount,
      'illustrations': illustrations.toJson(),
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }
}

/// Reads the master library as the owner's table of contents.
///
/// Read-only by construction, like the sync reader: no method here writes a
/// row. Where sync answers "what changed since my copy", this answers "what
/// is in there" — the question the owner asks from Postman, and the only
/// reason the two shapes differ.
class LibraryCatalog {
  /// Creates a catalogue over [library], asking [photos] which children have
  /// a reference photo on disk.
  const LibraryCatalog({required this.library, required this.photos});

  /// The initialized master library this catalogue queries.
  final MasterLibrary library;

  /// The photo store consulted for photo presence.
  final ProfilePhotoStore photos;

  /// Whether a profile row exists under [profileId].
  bool profileExists(String profileId) => photos.profileExists(profileId);

  /// Lists every profile, oldest first, with its story count and whether it
  /// has a reference photo.
  List<ProfileSummary> listProfiles() {
    final rows = library.database.select(
      'SELECT p.id AS id, p.display_name AS display_name, '
      'p.created_at_utc AS created_at_utc, '
      'p.updated_at_utc AS updated_at_utc, '
      '(SELECT COUNT(*) FROM stories s WHERE s.profile_id = p.id) '
      'AS story_count '
      'FROM profiles p ORDER BY p.created_at_utc ASC, p.id ASC',
    );
    return rows
        .map((row) {
          final id = row['id']! as String;
          return ProfileSummary(
            id: id,
            displayName: row['display_name']! as String,
            hasPhoto: photos.findPhoto(id) != null,
            storyCount: row['story_count']! as int,
            createdAtUtc: _parseUtc(row['created_at_utc']! as String),
            updatedAtUtc: _parseUtc(row['updated_at_utc']! as String),
          );
        })
        .toList(growable: false);
  }

  /// Lists every story, oldest first, or only those of [profileId].
  ///
  /// The caller has already checked that [profileId] names a profile; an id
  /// that names none would simply answer an empty list here, which is not the
  /// answer a mistyped filter deserves.
  List<StorySummary> listStories({String? profileId}) {
    final tallies = _readTalliesByStory(profileId: profileId);
    final rows = library.database.select(
      'SELECT s.id AS id, s.profile_id AS profile_id, s.title AS title, '
      's.language_code AS language_code, '
      's.created_at_utc AS created_at_utc, '
      's.updated_at_utc AS updated_at_utc, '
      '(SELECT COUNT(*) FROM story_pages p WHERE p.story_id = s.id) '
      'AS page_count '
      'FROM stories s '
      '${profileId == null ? '' : 'WHERE s.profile_id = ? '}'
      'ORDER BY s.created_at_utc ASC, s.id ASC',
      <Object?>[?profileId],
    );
    return rows
        .map((row) {
          final id = row['id']! as String;
          return StorySummary(
            id: id,
            profileId: row['profile_id']! as String,
            title: row['title']! as String,
            languageCode: row['language_code']! as String,
            pageCount: row['page_count']! as int,
            illustrations:
                tallies[id] ??
                const IllustrationTally(pending: 0, completed: 0, failed: 0),
            createdAtUtc: _parseUtc(row['created_at_utc']! as String),
            updatedAtUtc: _parseUtc(row['updated_at_utc']! as String),
          );
        })
        .toList(growable: false);
  }

  Map<String, IllustrationTally> _readTalliesByStory({String? profileId}) {
    final rows = library.database.select(
      'SELECT p.story_id AS story_id, i.status AS status, '
      'COUNT(*) AS total '
      'FROM illustrations i JOIN story_pages p ON p.id = i.story_page_id '
      '${profileId == null ? '' : 'JOIN stories s ON s.id = p.story_id '
                'WHERE s.profile_id = ? '}'
      'GROUP BY p.story_id, i.status',
      <Object?>[?profileId],
    );
    final pending = <String, int>{};
    final completed = <String, int>{};
    final failed = <String, int>{};
    for (final row in rows) {
      final storyId = row['story_id']! as String;
      final status = (row['status'] as String?) ?? pendingIllustrationStatus;
      final total = row['total']! as int;
      final bucket = switch (status) {
        completedIllustrationStatus => completed,
        failedIllustrationStatus => failed,
        _ => pending,
      };
      bucket[storyId] = (bucket[storyId] ?? 0) + total;
    }
    final storyIds = <String>{
      ...pending.keys,
      ...completed.keys,
      ...failed.keys,
    };
    return <String, IllustrationTally>{
      for (final storyId in storyIds)
        storyId: IllustrationTally(
          pending: pending[storyId] ?? 0,
          completed: completed[storyId] ?? 0,
          failed: failed[storyId] ?? 0,
        ),
    };
  }

  DateTime _parseUtc(String value) => DateTime.parse(value).toUtc();
}
