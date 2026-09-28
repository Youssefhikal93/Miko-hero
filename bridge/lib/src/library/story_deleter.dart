import 'dart:io';

import 'package:iam_hero_bridge/src/common/paths.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:uuid/uuid.dart';

/// Entity type written to `deletion_records` for a deleted story.
const String storyDeletionEntityType = 'story';

/// Outcome of one delete-everywhere request.
class StoryDeletion {
  /// Creates a deletion outcome.
  const StoryDeletion({
    required this.storyId,
    required this.alreadyDeleted,
    required this.deletedAtUtc,
    required this.removedFileCount,
  });

  /// The story that is now gone.
  final String storyId;

  /// Whether the story had already been deleted before this call.
  ///
  /// `true` makes the endpoint idempotent: a device that retries a delete it
  /// already succeeded with gets the same `200`, not a `404`.
  final bool alreadyDeleted;

  /// When the story was deleted; the original time when [alreadyDeleted].
  final DateTime deletedAtUtc;

  /// Number of illustration files removed from disk by this call.
  final int removedFileCount;

  /// JSON shape returned by `POST /stories/<storyId>/delete`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'storyId': storyId,
      'alreadyDeleted': alreadyDeleted,
      'deletedAtUtc': deletedAtUtc.toIso8601String(),
      'removedFileCount': removedFileCount,
    };
  }
}

/// Deletes one story everywhere: rows, files, and a record of the deletion.
///
/// "Everywhere" is the point. The rows go in a single transaction together
/// with a `deletion_records` entry, so a device that never saw the story
/// vanish still learns about it from the next sync manifest instead of
/// silently re-uploading its own copy. Profiles and reference photos are
/// never touched by this class.
class StoryDeleter {
  /// Creates a deleter over [library].
  StoryDeleter({required this._library, this._uuid = const Uuid()});

  final MasterLibrary _library;
  final Uuid _uuid;

  /// Permanently deletes [storyId] on behalf of [requestedByDeviceId].
  ///
  /// Returns `null` when no such story exists and none was ever deleted
  /// under this id, so the caller can answer a typed `404`. Illustration
  /// files are removed after the transaction commits, because the file
  /// system cannot join it: an interrupted call may leave an orphan file
  /// behind, which is harmless, where the reverse order could leave a row
  /// pointing at a file that is already gone.
  Future<StoryDeletion?> deleteStory({
    required String storyId,
    required String requestedByDeviceId,
    required DateTime nowUtc,
  }) async {
    final db = _library.database;
    final stamp = nowUtc.toUtc();
    final _DeletionPlan plan = runInDatabaseTransaction(db, () {
      final existing = db.select(
        'SELECT id FROM stories WHERE id = ?',
        <Object?>[storyId],
      );
      if (existing.isEmpty) {
        final recorded = db.select(
          'SELECT deleted_at_utc FROM deletion_records '
          'WHERE entity_type = ? AND entity_id = ? '
          'ORDER BY deleted_at_utc ASC LIMIT 1',
          <Object?>[storyDeletionEntityType, storyId],
        );
        if (recorded.isEmpty) {
          return const _DeletionPlan.missing();
        }
        return _DeletionPlan.alreadyDeleted(
          DateTime.parse(recorded.first['deleted_at_utc']! as String).toUtc(),
        );
      }
      final illustrationRows = db.select(
        'SELECT i.relative_path AS relative_path FROM illustrations i '
        'JOIN story_pages p ON p.id = i.story_page_id WHERE p.story_id = ?',
        <Object?>[storyId],
      );
      final paths = illustrationRows
          .map((row) => row['relative_path']! as String)
          .toList(growable: false);
      db.execute(
        'DELETE FROM illustrations WHERE story_page_id IN '
        '(SELECT id FROM story_pages WHERE story_id = ?)',
        <Object?>[storyId],
      );
      db.execute('DELETE FROM story_pages WHERE story_id = ?', <Object?>[
        storyId,
      ]);
      db.execute('DELETE FROM stories WHERE id = ?', <Object?>[storyId]);
      db.execute(
        'INSERT INTO deletion_records '
        '(id, entity_type, entity_id, requested_by_device_id, deleted_at_utc) '
        'VALUES (?, ?, ?, ?, ?)',
        <Object?>[
          _uuid.v4(),
          storyDeletionEntityType,
          storyId,
          requestedByDeviceId,
          stamp.toIso8601String(),
        ],
      );
      return _DeletionPlan.deleted(stamp, paths);
    });

    if (plan.missing) {
      return null;
    }
    if (plan.alreadyGone) {
      return StoryDeletion(
        storyId: storyId,
        alreadyDeleted: true,
        deletedAtUtc: plan.deletedAtUtc!,
        removedFileCount: 0,
      );
    }
    final removed = await removeIllustrationFiles(_library, plan.relativePaths);
    return StoryDeletion(
      storyId: storyId,
      alreadyDeleted: false,
      deletedAtUtc: plan.deletedAtUtc!,
      removedFileCount: removed,
    );
  }
}

/// Removes the illustration files at [relativePaths] from [library] and
/// prunes any folder they emptied, answering how many files actually went.
///
/// Shared by story deletion and profile deletion, which delete the same kind
/// of file for different reasons, so the guard against a path pointing
/// outside `illustrations/` is written once. Always called *after* the
/// transaction that removed the rows: the file system cannot join it, and an
/// orphan file is harmless where a row pointing at a missing file is not.
Future<int> removeIllustrationFiles(
  MasterLibrary library,
  List<String> relativePaths,
) async {
  var removed = 0;
  final parents = <String>{};
  for (final relativePath in relativePaths) {
    if (!isIllustrationRelativePath(relativePath)) {
      // A path outside the illustrations folder is never deleted; only
      // generated illustrations belong to a story.
      continue;
    }
    final file = File(
      joinPath(library.rootPath, toPlatformRelativePath(relativePath)),
    );
    try {
      if (await file.exists()) {
        await file.delete();
        removed++;
      }
      parents.add(file.parent.path);
    } on FileSystemException {
      // A file that cannot be removed is an orphan, not a broken library:
      // its row is already gone. Nothing is logged, paths are content.
    }
  }
  for (final parent in parents) {
    final directory = Directory(parent);
    try {
      if (await directory.exists() && await directory.list().isEmpty) {
        await directory.delete();
      }
    } on FileSystemException {
      // Leaving an empty folder behind is harmless.
    }
  }
  return removed;
}

/// Whether [relativePath] is a library-relative illustration file path.
///
/// Guards the delete path against a stored value that points outside the
/// `illustrations/` folder — a restored backup is the only way such a row
/// could appear, and reference photos must never be deleted with a story.
bool isIllustrationRelativePath(String relativePath) {
  return isSafeLibraryRelativePath(
    relativePath,
    allowedRoots: const <String>{'illustrations'},
  );
}

/// Internal outcome of the transactional part of one deletion.
class _DeletionPlan {
  const _DeletionPlan.missing()
    : missing = true,
      alreadyGone = false,
      deletedAtUtc = null,
      relativePaths = const <String>[];

  const _DeletionPlan.alreadyDeleted(this.deletedAtUtc)
    : missing = false,
      alreadyGone = true,
      relativePaths = const <String>[];

  const _DeletionPlan.deleted(this.deletedAtUtc, this.relativePaths)
    : missing = false,
      alreadyGone = false;

  final bool missing;
  final bool alreadyGone;
  final DateTime? deletedAtUtc;
  final List<String> relativePaths;
}
