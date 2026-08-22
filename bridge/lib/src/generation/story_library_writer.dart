import 'package:iam_hero_bridge/src/generation/generated_story.dart';
import 'package:iam_hero_bridge/src/generation/generation_errors.dart';
import 'package:iam_hero_bridge/src/generation/story_draft.dart';
import 'package:iam_hero_bridge/src/generation/story_generation_request.dart';
import 'package:iam_hero_bridge/src/library/db_transactions.dart';
import 'package:iam_hero_bridge/src/library/master_library.dart';
import 'package:uuid/uuid.dart';

/// Writes validated stories into the master library.
///
/// Every story lands in a single transaction: the profile upsert, the story
/// row, all page rows and one pending illustration row per page either all
/// commit or all roll back. A failed write leaves no partial story behind.
class StoryLibraryWriter {
  /// Creates a writer over [library].
  StoryLibraryWriter({required this._library, this._uuid = const Uuid()});

  final MasterLibrary _library;
  final Uuid _uuid;

  /// Persists [draft] for [request] and returns the stored story.
  ///
  /// Throws a [GenerationException] with
  /// [GenerationFailureCode.libraryWriteFailed] when the transaction cannot
  /// commit; in that case nothing was written.
  GeneratedStory writeStory({
    required StoryGenerationRequest request,
    required StoryDraft draft,
    required DateTime nowUtc,
  }) {
    final storyId = _uuid.v4();
    final timestamp = nowUtc.toUtc();
    final stamp = timestamp.toIso8601String();
    final pages = <GeneratedStoryPage>[];
    for (final page in draft.pages) {
      final pageIndex = page.pageNumber - 1;
      pages.add(
        GeneratedStoryPage(
          id: _uuid.v4(),
          pageNumber: page.pageNumber,
          text: page.text,
          illustrationScene: page.illustrationScene,
          illustrationId: _uuid.v4(),
          illustrationRelativePath: illustrationRelativePath(
            storyId: storyId,
            pageIndex: pageIndex,
          ),
          illustrationStatus: pendingIllustrationStatus,
        ),
      );
    }

    try {
      final db = _library.database;
      runInDatabaseTransaction(db, () {
        db.execute(
          'INSERT INTO profiles '
          '(id, display_name, created_at_utc, updated_at_utc) '
          'VALUES (?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET '
          'display_name = excluded.display_name, '
          'updated_at_utc = excluded.updated_at_utc',
          <Object?>[request.profileId, request.heroName, stamp, stamp],
        );
        db.execute(
          'INSERT INTO stories '
          '(id, profile_id, title, language_code, created_at_utc, '
          'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?)',
          <Object?>[
            storyId,
            request.profileId,
            draft.title,
            request.language.code,
            stamp,
            stamp,
          ],
        );
        for (final page in pages) {
          db.execute(
            'INSERT INTO story_pages '
            '(id, story_id, page_index, prose, scene_description, '
            'created_at_utc, updated_at_utc) VALUES (?, ?, ?, ?, ?, ?, ?)',
            <Object?>[
              page.id,
              storyId,
              page.pageNumber - 1,
              page.text,
              page.illustrationScene,
              stamp,
              stamp,
            ],
          );
          db.execute(
            'INSERT INTO illustrations '
            '(id, story_page_id, relative_path, status, created_at_utc, '
            'updated_at_utc) VALUES (?, ?, ?, ?, ?, ?)',
            <Object?>[
              page.illustrationId,
              page.id,
              page.illustrationRelativePath,
              page.illustrationStatus,
              stamp,
              stamp,
            ],
          );
        }
      });
    } on GenerationException {
      rethrow;
    } catch (_) {
      // The transaction rolled back, so the library is untouched. The cause
      // is deliberately dropped: it can quote row values.
      throw const GenerationException(
        GenerationFailureCode.libraryWriteFailed,
        'The story could not be written to the master library.',
      );
    }

    return GeneratedStory(
      id: storyId,
      profileId: request.profileId,
      title: draft.title,
      languageCode: request.language.code,
      createdAtUtc: timestamp,
      updatedAtUtc: timestamp,
      pages: List<GeneratedStoryPage>.unmodifiable(pages),
    );
  }
}

/// Deterministic library-relative path of one page illustration.
///
/// Always forward-slashed, like every other relative path in the database;
/// the file itself is created by the illustration milestone.
String illustrationRelativePath({
  required String storyId,
  required int pageIndex,
}) {
  return 'illustrations/$storyId/$pageIndex.png';
}
