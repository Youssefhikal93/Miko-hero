import 'package:miko_hero/core/ai_connection/bridge_models.dart';

/// What this device has already taken from the PC master library.
///
/// Deliberately separate from the story library itself. Stories live in the
/// persisted `AppState`, which is what makes previously synced books readable
/// offline; this record only holds the bookkeeping a device needs to sync
/// incrementally: the last reported watermark, the master-library version of
/// every story it downloaded, and the stories the parent does not want on
/// this device.
class LibrarySyncState {
  /// Creates one immutable synchronization record.
  const LibrarySyncState({
    this.lastSyncedAtUtc,
    this.storyVersions = const <String, DateTime>{},
    this.declinedStoryIds = const <String>[],
  });

  /// Manifest generation time of the last completed sync, absent until one.
  final DateTime? lastSyncedAtUtc;

  /// Bridge `updatedAtUtc` of every story this device downloaded, by identity.
  ///
  /// A manifest entry whose timestamp differs from the recorded one is
  /// downloaded again; an entry that matches is skipped without transferring
  /// any prose.
  final Map<String, DateTime> storyVersions;

  /// Bridge stories the parent removed from this device on purpose.
  ///
  /// Sync must not re-download them. The list is cleared by the parent's
  /// explicit re-download control, and one identity leaves it as soon as the
  /// story is deleted everywhere, because then there is nothing to decline.
  final List<String> declinedStoryIds;

  /// Whether this device has ever completed one sync with the PC.
  bool get hasSynced => lastSyncedAtUtc != null;

  /// Whether the parent removed [storyId] from this device on purpose.
  bool isDeclined(String storyId) => declinedStoryIds.contains(storyId);

  /// Master-library version this device holds of [storyId], if any.
  DateTime? versionOf(String storyId) => storyVersions[storyId];

  /// Converts the record into a JSON-compatible local storage object.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'lastSyncedAtUtc': lastSyncedAtUtc?.toIso8601String(),
      'storyVersions': <String, Object?>{
        for (final entry in storyVersions.entries)
          entry.key: entry.value.toIso8601String(),
      },
      'declinedStoryIds': declinedStoryIds,
    };
  }

  /// Validates and restores the record written by this or an older version.
  ///
  /// Every field is optional: a device that synced before any of them existed
  /// simply re-downloads what it cannot account for, which is exactly what the
  /// bridge contract expects of a device that lost its notes.
  factory LibrarySyncState.fromJson(Map<String, Object?> json) {
    return LibrarySyncState(
      lastSyncedAtUtc: _decodedMoment(json['lastSyncedAtUtc']),
      storyVersions: _decodedStoryVersions(json['storyVersions']),
      declinedStoryIds: _decodedStoryIds(json['declinedStoryIds']),
    );
  }

  /// Returns the record after one completed sync reported [manifestMoment].
  LibrarySyncState withLastSyncedAt(DateTime manifestMoment) {
    return _copy(lastSyncedAtUtc: manifestMoment.toUtc());
  }

  /// Returns the record after [storyId] was downloaded at [updatedAtUtc].
  LibrarySyncState withStoryVersion(String storyId, DateTime updatedAtUtc) {
    return _copy(
      storyVersions: <String, DateTime>{
        ...storyVersions,
        storyId: updatedAtUtc.toUtc(),
      },
    );
  }

  /// Returns the record with [storyId] kept off this device by choice.
  ///
  /// The recorded version goes with the local copy: nothing about a story that
  /// is not here is worth remembering except that it is not wanted.
  LibrarySyncState withDeclinedStory(String storyId) {
    return _copy(
      storyVersions: _versionsWithout(<String>{storyId}),
      declinedStoryIds: declinedStoryIds.contains(storyId)
          ? declinedStoryIds
          : <String>[...declinedStoryIds, storyId],
    );
  }

  /// Returns the record after the parent asked for declined stories again.
  LibrarySyncState withoutDeclinedStories() {
    if (declinedStoryIds.isEmpty) return this;
    return _copy(declinedStoryIds: const <String>[]);
  }

  /// Returns the record after [storyIds] left the master library for good.
  ///
  /// Both the recorded version and a declined marker are dropped: a deletion
  /// record protects every device, so nothing about that story is left to
  /// remember here.
  LibrarySyncState withoutStories(Set<String> storyIds) {
    return _withoutVersions(storyIds);
  }

  /// Drops [storyIds] from both the version map and the declined list.
  LibrarySyncState _withoutVersions(Set<String> storyIds) {
    final declined = declinedStoryIds
        .where((identity) => !storyIds.contains(identity))
        .toList(growable: false);
    return _copy(
      storyVersions: _versionsWithout(storyIds),
      declinedStoryIds: declined,
    );
  }

  /// Copies the version map without the supplied identities.
  Map<String, DateTime> _versionsWithout(Set<String> storyIds) {
    return <String, DateTime>{
      for (final entry in storyVersions.entries)
        if (!storyIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// Copies the record so a newly stored field cannot be dropped by accident.
  LibrarySyncState _copy({
    DateTime? lastSyncedAtUtc,
    Map<String, DateTime>? storyVersions,
    List<String>? declinedStoryIds,
  }) {
    return LibrarySyncState(
      lastSyncedAtUtc: lastSyncedAtUtc ?? this.lastSyncedAtUtc,
      storyVersions: Map<String, DateTime>.unmodifiable(
        storyVersions ?? this.storyVersions,
      ),
      declinedStoryIds: List<String>.unmodifiable(
        declinedStoryIds ?? this.declinedStoryIds,
      ),
    );
  }
}

/// Accepts an absent watermark and refuses an unreadable stored one.
DateTime? _decodedMoment(Object? encodedMoment) {
  if (encodedMoment == null) return null;
  if (encodedMoment is! String) {
    throw const FormatException('Malformed library sync moment.');
  }
  try {
    return parseBridgeTimestamp(encodedMoment);
  } on Exception {
    throw const FormatException('Malformed library sync moment.');
  }
}

/// Validates the stored story-version map, rejecting unusable entries.
Map<String, DateTime> _decodedStoryVersions(Object? encodedVersions) {
  if (encodedVersions == null) return const <String, DateTime>{};
  if (encodedVersions is! Map<String, Object?>) {
    throw const FormatException('Malformed library sync story versions.');
  }
  final versions = <String, DateTime>{};
  for (final entry in encodedVersions.entries) {
    if (entry.key.trim().isEmpty) {
      throw const FormatException('Malformed library sync story identity.');
    }
    final moment = _decodedMoment(entry.value);
    if (moment == null) {
      throw const FormatException('Malformed library sync story version.');
    }
    versions[entry.key] = moment;
  }
  return Map<String, DateTime>.unmodifiable(versions);
}

/// Validates a stored identity list and drops duplicate entries.
List<String> _decodedStoryIds(Object? encodedIdentities) {
  if (encodedIdentities == null) return const <String>[];
  if (encodedIdentities is! List) {
    throw const FormatException('Malformed library sync story identities.');
  }
  final identities = <String>[];
  for (final value in encodedIdentities) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Malformed library sync story identity.');
    }
    if (!identities.contains(value)) identities.add(value);
  }
  return List<String>.unmodifiable(identities);
}
