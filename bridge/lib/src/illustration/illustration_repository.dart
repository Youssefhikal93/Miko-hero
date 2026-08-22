import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';

/// Status written on an illustration row whose image is stored.
const String completedIllustrationStatus = 'completed';

/// Status written on an illustration row whose render did not succeed.
///
/// A failed row is not a dead end: `POST /stories/<id>/illustrate` picks it
/// up again on the next run, exactly like a pending one.
const String failedIllustrationStatus = 'failed';

/// One page of a story that still needs an image.
class IllustrationTarget {
  /// Creates a render target.
  const IllustrationTarget({
    required this.illustrationId,
    required this.storyPageId,
    required this.pageIndex,
    required this.sceneDescription,
    required this.relativePath,
    required this.status,
  });

  /// Stable id of the `illustrations` row.
  final String illustrationId;

  /// Stable id of the `story_pages` row this illustration belongs to.
  final String storyPageId;

  /// Zero-based page index; the reader sees `pageIndex + 1`.
  final int pageIndex;

  /// English scene description the page was generated with. Story content —
  /// never logged.
  final String sceneDescription;

  /// Library-relative, forward-slash path the PNG must occupy.
  final String relativePath;

  /// Current status of the row (`pending` or `failed`).
  final String status;
}

/// Everything one illustrate request needs to know about a story.
class StoryIllustrationTargets {
  /// Creates a target list.
  const StoryIllustrationTargets({
    required this.storyId,
    required this.profileId,
    required this.pending,
    required this.totalPageCount,
  });

  /// The story being illustrated.
  final String storyId;

  /// Profile owning the story; decides which reference photo is used.
  final String profileId;

  /// Pages still needing an image, in page order.
  final List<IllustrationTarget> pending;

  /// Total number of illustration rows the story has.
  final int totalPageCount;
}

/// One stored illustration as the sync download endpoint sees it.
class StoredIllustration {
  /// Creates a stored illustration descriptor.
  const StoredIllustration({
    required this.id,
    required this.storyId,
    required this.pageIndex,
    required this.relativePath,
    required this.status,
  });

  /// Stable id of the `illustrations` row.
  final String id;

  /// Story the illustration belongs to.
  final String storyId;

  /// Zero-based page index.
  final int pageIndex;

  /// Library-relative, forward-slash path of the PNG.
  final String relativePath;

  /// Lifecycle status: `pending`, `completed` or `failed`.
  final String status;

  /// Whether an image file is supposed to exist for this row.
  bool get isCompleted => status == completedIllustrationStatus;
}

/// Reads and updates the `illustrations` rows of the master library.
///
/// Every write is one small transaction covering exactly one page plus its
/// story's `updated_at_utc`, so a job that fails halfway leaves the pages it
/// did finish permanently done — a six-page book never has to be re-rendered
/// because page five timed out.
class IllustrationRepository {
  /// Creates a repository over [library].
  const IllustrationRepository({required this.library});

  /// The initialized master library this repository queries.
  final MasterLibrary library;

  /// Reads the pages of [storyId] that still need an image.
  ///
  /// Returns `null` when no such story exists. Rows that are already
  /// `completed` are left out: re-running an illustrate request must not
  /// redo work that succeeded.
  StoryIllustrationTargets? readTargets(String storyId) {
    final db = library.database;
    final storyRows = db.select(
      'SELECT profile_id FROM stories WHERE id = ?',
      <Object?>[storyId],
    );
    if (storyRows.isEmpty) {
      return null;
    }
    final rows = db.select(
      'SELECT i.id AS id, i.relative_path AS relative_path, '
      'i.status AS status, p.id AS page_id, p.page_index AS page_index, '
      'p.scene_description AS scene_description '
      'FROM illustrations i JOIN story_pages p ON p.id = i.story_page_id '
      'WHERE p.story_id = ? ORDER BY p.page_index ASC',
      <Object?>[storyId],
    );
    final pending = <IllustrationTarget>[];
    for (final row in rows) {
      final status = (row['status'] as String?) ?? pendingIllustrationStatus;
      if (status == completedIllustrationStatus) {
        continue;
      }
      pending.add(
        IllustrationTarget(
          illustrationId: row['id']! as String,
          storyPageId: row['page_id']! as String,
          pageIndex: row['page_index']! as int,
          sceneDescription: (row['scene_description'] as String?) ?? '',
          relativePath: row['relative_path']! as String,
          status: status,
        ),
      );
    }
    return StoryIllustrationTargets(
      storyId: storyId,
      profileId: storyRows.first['profile_id']! as String,
      pending: List<IllustrationTarget>.unmodifiable(pending),
      totalPageCount: rows.length,
    );
  }

  /// Reads one illustration row by id, or `null` when it is unknown.
  StoredIllustration? readIllustration(String illustrationId) {
    final rows = library.database.select(
      'SELECT i.id AS id, i.relative_path AS relative_path, '
      'i.status AS status, p.story_id AS story_id, '
      'p.page_index AS page_index '
      'FROM illustrations i JOIN story_pages p ON p.id = i.story_page_id '
      'WHERE i.id = ?',
      <Object?>[illustrationId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final row = rows.first;
    return StoredIllustration(
      id: row['id']! as String,
      storyId: row['story_id']! as String,
      pageIndex: row['page_index']! as int,
      relativePath: row['relative_path']! as String,
      status: (row['status'] as String?) ?? pendingIllustrationStatus,
    );
  }

  /// Sets the status of one illustration row and bumps its story.
  ///
  /// The story's `updated_at_utc` moves with the row so the next sync
  /// manifest shows the story as changed — that is how a second device
  /// learns there is now an image to download, or that a page failed.
  /// Both statements share one transaction: a row can never claim an image
  /// the manifest does not advertise.
  void markStatus({
    required String illustrationId,
    required String storyId,
    required String status,
    required DateTime nowUtc,
  }) {
    final db = library.database;
    final stamp = nowUtc.toUtc().toIso8601String();
    runInDatabaseTransaction(db, () {
      db.execute(
        'UPDATE illustrations SET status = ?, updated_at_utc = ? WHERE id = ?',
        <Object?>[status, stamp, illustrationId],
      );
      db.execute(
        'UPDATE stories SET updated_at_utc = ? WHERE id = ?',
        <Object?>[stamp, storyId],
      );
    });
  }
}
