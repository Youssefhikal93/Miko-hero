import 'package:miko_hero/core/ai_connection/bridge_exception.dart';
import 'package:miko_hero/core/ai_connection/bridge_models.dart';

/// Entity type of the only deletion kind the bridge records today.
const bridgeStoryEntityType = 'story';

/// Illustration status the bridge reports until the ComfyUI milestone lands.
const bridgePendingIllustrationStatus = 'pending';

/// One child profile as the master library advertises it.
///
/// Carries no photo and no birth date: the manifest is metadata only, so a
/// display name is all a device learns about a profile it does not have.
class BridgeSyncProfile {
  /// Creates one manifest profile entry.
  const BridgeSyncProfile({
    required this.id,
    required this.displayName,
    required this.updatedAtUtc,
  });

  /// Master-library identity, which is also the app's own profile identity.
  final String id;

  /// Name the parent gave this child on the device that generated for them.
  final String displayName;

  /// When the profile last changed on the PC.
  final DateTime updatedAtUtc;

  /// Validates one entry of the manifest's profile list.
  static BridgeSyncProfile fromEncodedProfile(Object? encodedProfile) {
    final json = _requiredObject(encodedProfile);
    return BridgeSyncProfile(
      id: _requiredText(json, 'id'),
      displayName: _requiredText(json, 'displayName'),
      updatedAtUtc: _requiredTimestamp(json, 'updatedAtUtc'),
    );
  }
}

/// One page illustration slot as the master library advertises it.
class BridgeSyncIllustration {
  /// Creates one manifest illustration entry.
  const BridgeSyncIllustration({
    required this.illustrationId,
    required this.pageNumber,
    required this.status,
  });

  /// Master-library identity of the illustration row.
  final String illustrationId;

  /// One-based page number the illustration belongs to.
  final int pageNumber;

  /// Lifecycle status, `pending` until an image file exists on the PC.
  final String status;

  /// Whether the PC has not produced this illustration's image file yet.
  bool get isPending => status == bridgePendingIllustrationStatus;

  /// Validates one entry of a manifest story's illustration list.
  ///
  /// The identity is read from `id`, the field the bridge writes, and from
  /// `illustrationId` so the same model also decodes the field name used by
  /// the story download payload.
  static BridgeSyncIllustration fromEncodedIllustration(
    Object? encodedIllustration,
  ) {
    final json = _requiredObject(encodedIllustration);
    return BridgeSyncIllustration(
      illustrationId: json.containsKey('id')
          ? _requiredText(json, 'id')
          : _requiredText(json, 'illustrationId'),
      pageNumber: _requiredCount(json, 'pageNumber'),
      status: _requiredText(json, 'status'),
    );
  }
}

/// One story as the master library advertises it: metadata only, never prose.
class BridgeSyncStory {
  /// Creates one manifest story entry.
  const BridgeSyncStory({
    required this.id,
    required this.profileId,
    required this.title,
    required this.languageCode,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.pageCount,
    required this.illustrations,
  });

  /// Master-library identity, which becomes the local story identity.
  final String id;

  /// Master-library profile this story belongs to.
  final String profileId;

  /// Cover title in the story language.
  final String title;

  /// ISO code of the language every page is written in.
  final String languageCode;

  /// When the PC first stored this story.
  final DateTime createdAtUtc;

  /// When the PC last changed this story.
  ///
  /// The only value incremental sync needs: a story whose timestamp differs
  /// from the one this device recorded is downloaded again, the rest are
  /// skipped without ever transferring prose.
  final DateTime updatedAtUtc;

  /// Number of pages the PC has stored.
  final int pageCount;

  /// Illustration slots ordered by page number.
  final List<BridgeSyncIllustration> illustrations;

  /// Validates one entry of the manifest's story list.
  static BridgeSyncStory fromEncodedStory(Object? encodedStory) {
    final json = _requiredObject(encodedStory);
    return BridgeSyncStory(
      id: _requiredText(json, 'id'),
      profileId: _requiredText(json, 'profileId'),
      title: _requiredText(json, 'title'),
      languageCode: _requiredText(json, 'languageCode'),
      createdAtUtc: _requiredTimestamp(json, 'createdAtUtc'),
      updatedAtUtc: _requiredTimestamp(json, 'updatedAtUtc'),
      pageCount: _requiredCount(json, 'pageCount'),
      illustrations: _entries(
        json['illustrations'],
        BridgeSyncIllustration.fromEncodedIllustration,
      ),
    );
  }
}

/// One deletion the PC recorded so every device drops its copy exactly once.
class BridgeSyncDeletion {
  /// Creates one manifest deletion record.
  const BridgeSyncDeletion({
    required this.entityType,
    required this.entityId,
    required this.deletedAtUtc,
  });

  /// Kind of entity that was deleted; `story` is the only kind today.
  final String entityType;

  /// Identity the deleted entity had.
  final String entityId;

  /// When the deletion happened on the PC.
  final DateTime deletedAtUtc;

  /// Whether this record deletes a story rather than a future entity kind.
  bool get isStory => entityType == bridgeStoryEntityType;

  /// Validates one entry of the manifest's deletion list.
  static BridgeSyncDeletion fromEncodedDeletion(Object? encodedDeletion) {
    final json = _requiredObject(encodedDeletion);
    return BridgeSyncDeletion(
      entityType: _requiredText(json, 'entityType'),
      entityId: _requiredText(json, 'entityId'),
      deletedAtUtc: _requiredTimestamp(json, 'deletedAtUtc'),
    );
  }
}

/// Everything one device needs to decide what to download and what to drop.
class BridgeSyncManifest {
  /// Creates one validated `GET /sync/manifest` answer.
  const BridgeSyncManifest({
    required this.generatedAtUtc,
    required this.lastSyncedAtUtc,
    required this.profiles,
    required this.stories,
    required this.deletions,
  });

  /// When the PC built this manifest; the watermark reported back at the end.
  final DateTime generatedAtUtc;

  /// This device's own last reported sync, absent until it completed one.
  final DateTime? lastSyncedAtUtc;

  /// Every profile the master library holds.
  final List<BridgeSyncProfile> profiles;

  /// Every story the master library holds, oldest first.
  final List<BridgeSyncStory> stories;

  /// Every recorded deletion, oldest first.
  final List<BridgeSyncDeletion> deletions;

  /// Identities of the deleted stories, including ones this device never held.
  Set<String> get deletedStoryIds {
    return deletions
        .where((deletion) => deletion.isStory)
        .map((deletion) => deletion.entityId)
        .toSet();
  }

  /// Display name the PC has for one profile, or null when it has none.
  String? displayNameForProfile(String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) return profile.displayName;
    }
    return null;
  }

  /// Validates the manifest before a single story is downloaded.
  ///
  /// An absent list decodes as empty so one added field cannot fail a whole
  /// sync, but a list of the wrong shape is refused. Deletions are read from
  /// `deletions`, the field the bridge writes, and from `deletionRecords` so
  /// the client stays readable against either spelling of the contract.
  factory BridgeSyncManifest.fromJson(Map<String, Object?> json) {
    return BridgeSyncManifest(
      generatedAtUtc: _requiredTimestamp(json, 'generatedAtUtc'),
      lastSyncedAtUtc: _optionalTimestamp(json, 'lastSyncedAtUtc'),
      profiles: _entries(
        json['profiles'],
        BridgeSyncProfile.fromEncodedProfile,
      ),
      stories: _entries(json['stories'], BridgeSyncStory.fromEncodedStory),
      deletions: _entries(
        json['deletions'] ?? json['deletionRecords'],
        BridgeSyncDeletion.fromEncodedDeletion,
      ),
    );
  }
}

/// One complete story downloaded from the PC master library.
///
/// The payload is the shape a completed generation job returns, so the same
/// [BridgeStory] validation covers both paths; only the owning profile is
/// additionally required here, because sync has to place the book on a shelf.
class BridgeSyncStoryDownload {
  /// Creates one validated `GET /sync/stories/<id>` answer.
  const BridgeSyncStoryDownload({required this.story, required this.profileId});

  /// The story with its ordered pages, prose, scenes, and illustration ids.
  final BridgeStory story;

  /// Master-library profile this story belongs to.
  final String profileId;

  /// Validates the downloaded payload before it can become a local book.
  factory BridgeSyncStoryDownload.fromJson(Map<String, Object?> json) {
    final encodedStory = json['story'];
    if (encodedStory is! Map<String, Object?>) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    final story = BridgeStory.fromJson(encodedStory);
    final profileId = story.profileId;
    if (profileId == null) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeSyncStoryDownload(story: story, profileId: profileId);
  }
}

/// Outcome of deleting one story on the PC and therefore everywhere.
class BridgeStoryDeletion {
  /// Creates one validated `POST /stories/<id>/delete` answer.
  const BridgeStoryDeletion({
    required this.storyId,
    required this.alreadyDeleted,
    required this.deletedAtUtc,
  });

  /// Identity of the story the PC deleted.
  final String storyId;

  /// Whether the story had already been deleted before this call.
  ///
  /// The endpoint is idempotent, so this is a success either way: the
  /// deletion record that protects every other device already exists.
  final bool alreadyDeleted;

  /// When the deletion was recorded on the PC.
  final DateTime deletedAtUtc;

  /// Validates the deletion answer before the local copy is removed.
  factory BridgeStoryDeletion.fromJson(Map<String, Object?> json) {
    final alreadyDeleted = json['alreadyDeleted'];
    if (alreadyDeleted != null && alreadyDeleted is! bool) {
      throw const BridgeException(BridgeFailure.invalidResponse);
    }
    return BridgeStoryDeletion(
      storyId: _requiredText(json, 'storyId'),
      alreadyDeleted: alreadyDeleted as bool? ?? false,
      deletedAtUtc: _requiredTimestamp(json, 'deletedAtUtc'),
    );
  }
}

/// Requires one JSON object inside a sync payload.
Map<String, Object?> _requiredObject(Object? encodedValue) {
  if (encodedValue is! Map<String, Object?>) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return encodedValue;
}

/// Requires one non-empty string field of a sync payload.
String _requiredText(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return value.trim();
}

/// Requires one non-negative integer field of a sync payload.
int _requiredCount(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value is! int || value < 0) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return value;
}

/// Requires one ISO-8601 timestamp field and normalizes it to UTC.
DateTime _requiredTimestamp(Map<String, Object?> json, String field) {
  final moment = _optionalTimestamp(json, field);
  if (moment == null) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return moment;
}

/// Reads an optional ISO-8601 timestamp and refuses an unparsable one.
DateTime? _optionalTimestamp(Map<String, Object?> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return parseBridgeTimestamp(value);
}

/// Validates one list of a sync payload, treating an absent list as empty.
List<T> _entries<T>(Object? encodedEntries, T Function(Object? entry) decode) {
  if (encodedEntries == null) return List<T>.unmodifiable(const <Never>[]);
  if (encodedEntries is! List) {
    throw const BridgeException(BridgeFailure.invalidResponse);
  }
  return List<T>.unmodifiable(encodedEntries.map(decode));
}
