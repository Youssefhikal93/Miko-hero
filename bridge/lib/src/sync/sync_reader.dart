import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:iam_hero_bridge/src/sync/sync_manifest.dart';
import 'package:sqlite3/sqlite3.dart';

/// Reads the master library into the two payloads sync is built from.
///
/// Read-only by construction: no method here writes a row. The manifest is
/// metadata, the story download is content, and nothing in between exists —
/// there is no change feed to keep consistent, only timestamps a device can
/// compare against its own copy.
class SyncReader {
  /// Creates a reader over [library].
  const SyncReader({required this.library});

  /// The initialized master library this reader queries.
  final MasterLibrary library;

  /// Builds the manifest for [deviceId] as of [nowUtc].
  SyncManifest readManifest({
    required String deviceId,
    required DateTime nowUtc,
  }) {
    final db = library.database;
    return SyncManifest(
      generatedAtUtc: nowUtc.toUtc(),
      lastSyncedAtUtc: _readLastSyncedAt(db, deviceId),
      profiles: _readProfiles(db),
      stories: _readStories(db),
      deletions: _readDeletions(db),
    );
  }

  /// Reads the complete content of [storyId], or `null` when no such story
  /// exists (including one that was deleted).
  GeneratedStory? readStory(String storyId) {
    final db = library.database;
    final storyRows = db.select(
      'SELECT id, profile_id, title, language_code, created_at_utc, '
      'updated_at_utc FROM stories WHERE id = ?',
      <Object?>[storyId],
    );
    if (storyRows.isEmpty) {
      return null;
    }
    final story = storyRows.first;
    final pageRows = db.select(
      'SELECT p.id AS page_id, p.page_index AS page_index, p.prose AS prose, '
      'p.scene_description AS scene_description, i.id AS illustration_id, '
      'i.relative_path AS relative_path, i.status AS status '
      'FROM story_pages p '
      'LEFT JOIN illustrations i ON i.story_page_id = p.id '
      'WHERE p.story_id = ? ORDER BY p.page_index ASC',
      <Object?>[storyId],
    );
    final pages = pageRows
        .map(
          (row) => GeneratedStoryPage(
            id: row['page_id']! as String,
            pageNumber: (row['page_index']! as int) + 1,
            text: row['prose']! as String,
            illustrationScene: row['scene_description']! as String,
            illustrationId: (row['illustration_id'] as String?) ?? '',
            illustrationRelativePath: (row['relative_path'] as String?) ?? '',
            illustrationStatus:
                (row['status'] as String?) ?? pendingIllustrationStatus,
          ),
        )
        .toList(growable: false);
    return GeneratedStory(
      id: story['id']! as String,
      profileId: story['profile_id']! as String,
      title: story['title']! as String,
      languageCode: story['language_code']! as String,
      createdAtUtc: _parseUtc(story['created_at_utc']! as String),
      updatedAtUtc: _parseUtc(story['updated_at_utc']! as String),
      pages: pages,
    );
  }

  DateTime? _readLastSyncedAt(Database db, String deviceId) {
    final rows = db.select(
      'SELECT last_synced_at_utc FROM sync_state WHERE device_id = ?',
      <Object?>[deviceId],
    );
    if (rows.isEmpty) {
      return null;
    }
    final stored = rows.first['last_synced_at_utc'];
    return stored is String ? _parseUtc(stored) : null;
  }

  List<SyncProfileEntry> _readProfiles(Database db) {
    final rows = db.select(
      'SELECT id, display_name, updated_at_utc FROM profiles '
      'ORDER BY created_at_utc ASC, id ASC',
    );
    return rows
        .map(
          (row) => SyncProfileEntry(
            id: row['id']! as String,
            displayName: row['display_name']! as String,
            updatedAtUtc: _parseUtc(row['updated_at_utc']! as String),
          ),
        )
        .toList(growable: false);
  }

  List<SyncStoryEntry> _readStories(Database db) {
    final illustrationsByStory = _readIllustrationsByStory(db);
    final rows = db.select(
      'SELECT s.id AS id, s.profile_id AS profile_id, s.title AS title, '
      's.language_code AS language_code, s.created_at_utc AS created_at_utc, '
      's.updated_at_utc AS updated_at_utc, '
      '(SELECT COUNT(*) FROM story_pages p WHERE p.story_id = s.id) '
      'AS page_count '
      'FROM stories s ORDER BY s.created_at_utc ASC, s.id ASC',
    );
    return rows
        .map((row) {
          final id = row['id']! as String;
          return SyncStoryEntry(
            id: id,
            profileId: row['profile_id']! as String,
            title: row['title']! as String,
            languageCode: row['language_code']! as String,
            createdAtUtc: _parseUtc(row['created_at_utc']! as String),
            updatedAtUtc: _parseUtc(row['updated_at_utc']! as String),
            pageCount: row['page_count']! as int,
            illustrations:
                illustrationsByStory[id] ?? const <SyncIllustrationEntry>[],
          );
        })
        .toList(growable: false);
  }

  Map<String, List<SyncIllustrationEntry>> _readIllustrationsByStory(
    Database db,
  ) {
    final rows = db.select(
      'SELECT p.story_id AS story_id, p.page_index AS page_index, '
      'i.id AS id, i.status AS status '
      'FROM illustrations i JOIN story_pages p ON p.id = i.story_page_id '
      'ORDER BY p.story_id ASC, p.page_index ASC',
    );
    final grouped = <String, List<SyncIllustrationEntry>>{};
    for (final row in rows) {
      final storyId = row['story_id']! as String;
      grouped
          .putIfAbsent(storyId, () => <SyncIllustrationEntry>[])
          .add(
            SyncIllustrationEntry(
              id: row['id']! as String,
              pageNumber: (row['page_index']! as int) + 1,
              status: row['status']! as String,
            ),
          );
    }
    return grouped;
  }

  List<SyncDeletionEntry> _readDeletions(Database db) {
    final rows = db.select(
      'SELECT entity_type, entity_id, deleted_at_utc FROM deletion_records '
      'ORDER BY deleted_at_utc ASC, id ASC',
    );
    return rows
        .map(
          (row) => SyncDeletionEntry(
            entityType: row['entity_type']! as String,
            entityId: row['entity_id']! as String,
            deletedAtUtc: _parseUtc(row['deleted_at_utc']! as String),
          ),
        )
        .toList(growable: false);
  }

  DateTime _parseUtc(String value) => DateTime.parse(value).toUtc();
}
