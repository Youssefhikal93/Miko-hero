/// Status written on freshly created illustration rows.
///
/// The image files themselves arrive with the ComfyUI milestone; until then
/// every row is a placeholder that already owns its stable id and path.
const String pendingIllustrationStatus = 'pending';

/// One persisted page plus its pending illustration slot.
class GeneratedStoryPage {
  /// Creates a persisted page view.
  const GeneratedStoryPage({
    required this.id,
    required this.pageNumber,
    required this.text,
    required this.illustrationScene,
    required this.illustrationId,
    required this.illustrationRelativePath,
    required this.illustrationStatus,
  });

  /// Stable id of the `story_pages` row.
  final String id;

  /// One-based page number shown to the reader.
  final int pageNumber;

  /// Page prose in the story language.
  final String text;

  /// English scene description used by the illustration milestone.
  final String illustrationScene;

  /// Stable id of the `illustrations` row belonging to this page.
  final String illustrationId;

  /// Library-relative, forward-slash path the image file will occupy.
  final String illustrationRelativePath;

  /// Illustration lifecycle status; `pending` until an image exists.
  final String illustrationStatus;

  /// JSON shape returned to the app.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'pageNumber': pageNumber,
      'text': text,
      'illustrationScene': illustrationScene,
      'illustrationId': illustrationId,
      'illustrationRelativePath': illustrationRelativePath,
      'illustrationStatus': illustrationStatus,
    };
  }
}

/// A story after it has been written to the master library.
///
/// Held on the completed job so the app can fetch the whole book — including
/// the illustration ids it will later poll — in one call.
class GeneratedStory {
  /// Creates a persisted story view.
  const GeneratedStory({
    required this.id,
    required this.profileId,
    required this.title,
    required this.languageCode,
    required this.createdAtUtc,
    required this.pages,
  });

  /// Stable id of the `stories` row.
  final String id;

  /// Child profile owning the story.
  final String profileId;

  /// Story title in the story language.
  final String title;

  /// Two-letter language code of every page.
  final String languageCode;

  /// When the story was written to the library.
  final DateTime createdAtUtc;

  /// Ordered pages, one per requested page.
  final List<GeneratedStoryPage> pages;

  /// JSON shape returned to the app.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'profileId': profileId,
      'title': title,
      'languageCode': languageCode,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'pages': pages.map((page) => page.toJson()).toList(growable: false),
    };
  }
}
