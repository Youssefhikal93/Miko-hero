/// One child profile as advertised in a sync manifest.
class SyncProfileEntry {
  /// Creates a profile entry.
  const SyncProfileEntry({
    required this.id,
    required this.displayName,
    required this.updatedAtUtc,
  });

  /// Stable id of the `profiles` row.
  final String id;

  /// Name the parent gave the child.
  final String displayName;

  /// When the profile last changed.
  final DateTime updatedAtUtc;

  /// JSON shape inside a manifest.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'displayName': displayName,
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
    };
  }
}

/// One page illustration slot as advertised in a sync manifest.
///
/// Every entry is `pending` until the ComfyUI milestone produces files; the
/// id and page number exist from the first save so a device can already show
/// which pages will gain an image.
class SyncIllustrationEntry {
  /// Creates an illustration entry.
  const SyncIllustrationEntry({
    required this.id,
    required this.pageNumber,
    required this.status,
  });

  /// Stable id of the `illustrations` row.
  final String id;

  /// One-based page number the illustration belongs to.
  final int pageNumber;

  /// Illustration lifecycle status; `pending` until an image file exists.
  final String status;

  /// JSON shape inside a manifest.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'pageNumber': pageNumber,
      'status': status,
    };
  }
}

/// One story as advertised in a sync manifest: metadata only, never prose.
class SyncStoryEntry {
  /// Creates a story entry.
  const SyncStoryEntry({
    required this.id,
    required this.profileId,
    required this.title,
    required this.languageCode,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.pageCount,
    required this.illustrations,
  });

  /// Stable id of the `stories` row.
  final String id;

  /// Profile owning the story.
  final String profileId;

  /// Story title in the story language.
  final String title;

  /// Two-letter language code of every page.
  final String languageCode;

  /// When the story was first written.
  final DateTime createdAtUtc;

  /// When the story last changed.
  ///
  /// This is the only value a device needs for incremental sync: a story
  /// whose [updatedAtUtc] is newer than the copy on the device is downloaded
  /// again, everything else is skipped.
  final DateTime updatedAtUtc;

  /// Number of persisted pages.
  final int pageCount;

  /// Illustration slots ordered by page number.
  final List<SyncIllustrationEntry> illustrations;

  /// JSON shape inside a manifest.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'profileId': profileId,
      'title': title,
      'languageCode': languageCode,
      'createdAtUtc': createdAtUtc.toIso8601String(),
      'updatedAtUtc': updatedAtUtc.toIso8601String(),
      'pageCount': pageCount,
      'illustrations': illustrations
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}

/// One recorded deletion, so every device learns about it exactly once.
class SyncDeletionEntry {
  /// Creates a deletion entry.
  const SyncDeletionEntry({
    required this.entityType,
    required this.entityId,
    required this.deletedAtUtc,
  });

  /// Kind of entity that was deleted; `story` is the only kind today.
  final String entityType;

  /// Id the deleted entity had.
  final String entityId;

  /// When the deletion happened on the bridge.
  final DateTime deletedAtUtc;

  /// JSON shape inside a manifest.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'entityType': entityType,
      'entityId': entityId,
      'deletedAtUtc': deletedAtUtc.toIso8601String(),
    };
  }
}

/// Everything one device needs to decide what to download and what to drop.
///
/// Deliberately bounded to metadata: titles and timestamps travel here, prose
/// and files never do. A device fetches this once per sync, downloads the
/// stories whose [SyncStoryEntry.updatedAtUtc] moved, applies [deletions], and
/// then reports [generatedAtUtc] back through `POST /sync/complete`.
class SyncManifest {
  /// Creates a manifest.
  const SyncManifest({
    required this.generatedAtUtc,
    required this.lastSyncedAtUtc,
    required this.profiles,
    required this.stories,
    required this.deletions,
  });

  /// When the bridge built this manifest.
  final DateTime generatedAtUtc;

  /// The requesting device's last recorded successful sync, or `null` when it
  /// has never completed one.
  final DateTime? lastSyncedAtUtc;

  /// All profiles, oldest first.
  final List<SyncProfileEntry> profiles;

  /// All stories, oldest first.
  final List<SyncStoryEntry> stories;

  /// All recorded deletions, oldest first.
  final List<SyncDeletionEntry> deletions;

  /// JSON shape returned by `GET /sync/manifest`.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'generatedAtUtc': generatedAtUtc.toIso8601String(),
      'lastSyncedAtUtc': lastSyncedAtUtc?.toIso8601String(),
      'profiles': profiles
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'stories': stories.map((entry) => entry.toJson()).toList(growable: false),
      'deletions': deletions
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }
}
