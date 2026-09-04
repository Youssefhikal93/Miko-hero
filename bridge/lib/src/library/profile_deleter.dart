import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/library/profile_photo_store.dart';
import 'package:iam_hero_bridge/src/library/story_deleter.dart';
import 'package:uuid/uuid.dart';

/// Outcome of deleting one profile and everything it owned.
class ProfileDeletion {
  /// Creates a deletion outcome.
  const ProfileDeletion({
    required this.profileId,
    required this.deletedAtUtc,
    required this.deletedStoryCount,
    required this.deletedPageCount,
    required this.deletedIllustrationCount,
    required this.removedFileCount,
    required this.photoRemoved,
  });

  /// The profile that is now gone.
  final String profileId;

  /// When the profile and its stories were deleted.
  final DateTime deletedAtUtc;

  /// How many stories went with it.
  final int deletedStoryCount;

  /// How many story pages went with it.
  final int deletedPageCount;

  /// How many illustration rows went with it.
  final int deletedIllustrationCount;

  /// How many illustration files were removed from disk.
  final int removedFileCount;

  /// Whether a reference photo file was removed.
  final bool photoRemoved;

  /// JSON shape returned by `DELETE /profiles/<profileId>`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'profileId': profileId,
      'deletedAtUtc': deletedAtUtc.toIso8601String(),
      'deletedStoryCount': deletedStoryCount,
      'deletedPageCount': deletedPageCount,
      'deletedIllustrationCount': deletedIllustrationCount,
      'removedFileCount': removedFileCount,
      'photoRemoved': photoRemoved,
    };
  }
}

/// Deletes one child profile and everything the library holds for it.
///
/// The counterpart of [StoryDeleter], one level up: stories, pages,
/// illustration rows, the profile row and a `deletion_records` entry **per
/// story** all commit or all roll back together. The per-story records are
/// deliberately the same ones a single story deletion writes, so a paired
/// device that never saw this happen learns each book is gone from its next
/// manifest through the path it already understands, rather than through a
/// new kind of record it would have to be taught. The profile's own
/// disappearance needs no record: every manifest carries the complete profile
/// list, so a profile that is no longer in it is a profile that is gone.
///
/// Files — illustrations and the reference photo — are removed after the
/// transaction commits, for the reason [StoryDeleter] gives: the file system
/// cannot join a transaction, and an orphaned file is harmless where a row
/// pointing at a deleted file is not.
class ProfileDeleter {
  /// Creates a deleter over [library], removing photos through [photos].
  ProfileDeleter({
    required this._library,
    required this._photos,
    this._uuid = const Uuid(),
  });

  final MasterLibrary _library;
  final ProfilePhotoStore _photos;
  final Uuid _uuid;

  /// Permanently deletes [profileId] on behalf of [requestedByDeviceId].
  ///
  /// Returns `null` when no such profile exists, so the caller can answer the
  /// same typed `404 profile_not_found` the photo endpoints already answer.
  /// Unlike a story deletion this is not idempotent: nothing records that a
  /// profile once existed, so a second call is indistinguishable from a
  /// mistyped id and is refused as one.
  Future<ProfileDeletion?> deleteProfile({
    required String profileId,
    required String requestedByDeviceId,
    required DateTime nowUtc,
  }) async {
    if (!ProfilePhotoStore.isValidProfileId(profileId)) {
      return null;
    }
    final db = _library.database;
    final stamp = nowUtc.toUtc();
    final _ProfileDeletionPlan? plan = runInDatabaseTransaction(db, () {
      final existing = db.select(
        'SELECT id FROM profiles WHERE id = ?',
        <Object?>[profileId],
      );
      if (existing.isEmpty) {
        return null;
      }
      final storyRows = db.select(
        'SELECT id FROM stories WHERE profile_id = ?',
        <Object?>[profileId],
      );
      final storyIds = storyRows
          .map((row) => row['id']! as String)
          .toList(growable: false);
      final illustrationRows = db.select(
        'SELECT i.relative_path AS relative_path FROM illustrations i '
        'JOIN story_pages p ON p.id = i.story_page_id '
        'JOIN stories s ON s.id = p.story_id WHERE s.profile_id = ?',
        <Object?>[profileId],
      );
      final paths = illustrationRows
          .map((row) => row['relative_path']! as String)
          .toList(growable: false);
      final pageRows = db.select(
        'SELECT COUNT(*) AS total FROM story_pages p '
        'JOIN stories s ON s.id = p.story_id WHERE s.profile_id = ?',
        <Object?>[profileId],
      );
      final pageCount = pageRows.first['total']! as int;

      db.execute(
        'DELETE FROM illustrations WHERE story_page_id IN '
        '(SELECT p.id FROM story_pages p JOIN stories s ON s.id = p.story_id '
        'WHERE s.profile_id = ?)',
        <Object?>[profileId],
      );
      db.execute(
        'DELETE FROM story_pages WHERE story_id IN '
        '(SELECT id FROM stories WHERE profile_id = ?)',
        <Object?>[profileId],
      );
      db.execute('DELETE FROM stories WHERE profile_id = ?', <Object?>[
        profileId,
      ]);
      for (final storyId in storyIds) {
        db.execute(
          'INSERT INTO deletion_records '
          '(id, entity_type, entity_id, requested_by_device_id, '
          'deleted_at_utc) VALUES (?, ?, ?, ?, ?)',
          <Object?>[
            _uuid.v4(),
            storyDeletionEntityType,
            storyId,
            requestedByDeviceId,
            stamp.toIso8601String(),
          ],
        );
      }
      db.execute('DELETE FROM profiles WHERE id = ?', <Object?>[profileId]);
      return _ProfileDeletionPlan(
        storyCount: storyIds.length,
        pageCount: pageCount,
        illustrationRelativePaths: paths,
      );
    });

    if (plan == null) {
      return null;
    }
    final removedFiles = await removeIllustrationFiles(
      _library,
      plan.illustrationRelativePaths,
    );
    final photoRemoved = await _photos.removePhotoFiles(profileId);
    return ProfileDeletion(
      profileId: profileId,
      deletedAtUtc: stamp,
      deletedStoryCount: plan.storyCount,
      deletedPageCount: plan.pageCount,
      deletedIllustrationCount: plan.illustrationRelativePaths.length,
      removedFileCount: removedFiles,
      photoRemoved: photoRemoved,
    );
  }
}

/// What the transactional part of one profile deletion removed.
class _ProfileDeletionPlan {
  const _ProfileDeletionPlan({
    required this.storyCount,
    required this.pageCount,
    required this.illustrationRelativePaths,
  });

  final int storyCount;
  final int pageCount;
  final List<String> illustrationRelativePaths;
}
