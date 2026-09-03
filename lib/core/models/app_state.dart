import 'package:flutter/widgets.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';

/// Snapshot schema written by this version; 4 introduced reading comfort.
///
/// Version 2 introduced profile birth dates; version 3 added the per-child
/// castle, photo frame, backdrop, and favourite symbol; version 4 added each
/// child's reader text size, easy-reading font, and finished-story rewards.
const appStateSchemaVersion = 4;

/// Oldest snapshot schema this version still reads; 1 predates birth dates.
const minimumAppStateSchemaVersion = 1;

/// Reports a snapshot written by a newer, unknown application version.
///
/// Restoring it could silently drop fields this build cannot represent, so the
/// backup is refused instead of partially applied.
class UnsupportedSchemaVersionException implements Exception {
  /// Creates the error carrying the version found in the snapshot.
  const UnsupportedSchemaVersionException(this.version);

  /// Schema version read from the snapshot.
  final int version;

  /// Keeps diagnostics concise without exposing stored family content.
  @override
  String toString() {
    return 'Unsupported application state schema version: $version.';
  }
}

/// Complete locally persisted state needed to render the application.
class AppState {
  /// Creates an immutable application snapshot.
  const AppState({
    required this.locale,
    required this.profiles,
    required this.stories,
    required this.activeProfileId,
  });

  /// Creates an immutable snapshot after checking cross-model relationships.
  factory AppState.validated({
    required Locale locale,
    required List<ChildProfile> profiles,
    required List<StoryBook> stories,
    required String? activeProfileId,
  }) {
    final sortedStories = stories.toList()
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    final state = AppState(
      locale: locale,
      profiles: List<ChildProfile>.unmodifiable(profiles),
      stories: List<StoryBook>.unmodifiable(sortedStories),
      activeProfileId: activeProfileId,
    );
    state._validateRelationships();
    return state;
  }

  /// Current interface locale.
  final Locale locale;

  /// Child profiles in their stable local display order.
  final List<ChildProfile> profiles;

  /// Books sorted newest first.
  final List<StoryBook> stories;

  /// Profile currently controlling the personalized application theme.
  final String? activeProfileId;

  /// Converts the complete family snapshot into a portable JSON object.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': appStateSchemaVersion,
      'locale': locale.languageCode,
      'profiles': profiles.map((profile) => profile.toJson()).toList(),
      'stories': stories.map((story) => story.toJson()).toList(),
      'activeProfileId': activeProfileId,
    };
  }

  /// Validates and restores a complete current-schema family snapshot.
  ///
  /// An absent `schemaVersion` is the original version 1, and versions 1
  /// through [appStateSchemaVersion] are all accepted. A newer version is
  /// refused with [UnsupportedSchemaVersionException] rather than guessed at.
  factory AppState.fromJson(Map<String, Object?> json) {
    requireSupportedAppStateSchemaVersion(json['schemaVersion']);
    final localeCode = json['locale'];
    final encodedProfiles = json['profiles'];
    final encodedStories = json['stories'];
    final activeProfileId = json['activeProfileId'];
    if (localeCode is! String ||
        encodedProfiles is! List ||
        encodedStories is! List ||
        (activeProfileId != null && activeProfileId is! String)) {
      throw const FormatException('Malformed application state.');
    }
    final profiles = encodedProfiles.map(_decodeProfile).toList();
    final stories = encodedStories.map(_decodeStory).toList();
    return AppState.validated(
      locale: AppLanguage.requireCode(localeCode).locale,
      profiles: profiles,
      stories: stories,
      activeProfileId: activeProfileId as String?,
    );
  }

  /// Active profile, or null until the parent selects or saves one.
  ChildProfile? get activeProfile {
    final profileId = activeProfileId;
    return profileId == null ? null : profileById(profileId);
  }

  /// Parent-approved books visible on child-facing shelves and home.
  List<StoryBook> get approvedStories {
    return stories
        .where((story) => story.reviewStatus == StoryReviewStatus.approved)
        .toList(growable: false);
  }

  /// Generated books still waiting for explicit parent review.
  List<StoryBook> get draftStories {
    return stories
        .where((story) => story.reviewStatus == StoryReviewStatus.draft)
        .toList(growable: false);
  }

  /// Resolves the child associated with a story, including its private photo.
  ChildProfile? profileById(String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  /// Resolves one stored book by identity, or null when it is already gone.
  StoryBook? storyById(String storyId) {
    for (final story in stories) {
      if (story.id == storyId) return story;
    }
    return null;
  }

  /// Resolves one stored book or reports it as recoverably missing.
  ///
  /// A parent reaches this by acting on a card whose story another screen
  /// deleted meanwhile, so it is an [UnknownEntityException] the surface is
  /// expected to catch rather than a programming error.
  StoryBook requireStoryById(String storyId) {
    final story = storyById(storyId);
    if (story == null) throw const UnknownEntityException('story');
    return story;
  }

  /// Returns the newest-first shelf belonging to one child profile.
  List<StoryBook> storiesForProfile(String profileId) {
    return stories
        .where(
          (story) =>
              story.reviewStatus == StoryReviewStatus.approved &&
              story.content.request.profileId == profileId,
        )
        .toList(growable: false);
  }

  /// Returns a snapshot with a newly persisted interface locale.
  AppState withLocale(Locale savedLocale) {
    return AppState(
      locale: savedLocale,
      profiles: profiles,
      stories: stories,
      activeProfileId: activeProfileId,
    );
  }

  /// Returns a snapshot after profile persistence selects an active child.
  AppState withProfiles(
    List<ChildProfile> savedProfiles, {
    required String? savedActiveProfileId,
  }) {
    return AppState(
      locale: locale,
      profiles: savedProfiles,
      stories: stories,
      activeProfileId: savedActiveProfileId,
    );
  }

  /// Returns a snapshot after the newest-first story library is persisted.
  AppState withStories(List<StoryBook> savedStories) {
    return AppState(
      locale: locale,
      profiles: profiles,
      stories: savedStories,
      activeProfileId: activeProfileId,
    );
  }

  /// Removes family content while retaining the parent's interface language.
  AppState withoutFamilyData() {
    return AppState(
      locale: locale,
      profiles: const <ChildProfile>[],
      stories: const <StoryBook>[],
      activeProfileId: null,
    );
  }

  /// Rejects duplicate identities and references outside this family snapshot.
  void _validateRelationships() {
    final profileIds = profiles.map((profile) => profile.id).toSet();
    if (profileIds.length != profiles.length) {
      throw const FormatException('Child profile identities must be unique.');
    }
    final storyIds = stories.map((story) => story.id).toSet();
    if (storyIds.length != stories.length) {
      throw const FormatException('Story identities must be unique.');
    }
    final activeId = activeProfileId;
    if (activeId != null && !profileIds.contains(activeId)) {
      throw const FormatException('Active child profile does not exist.');
    }
    for (final story in stories) {
      if (!profileIds.contains(story.content.request.profileId)) {
        throw const FormatException(
          'Story references an unknown child profile.',
        );
      }
    }
  }
}

/// Accepts every schema version this build understands and refuses the rest.
///
/// Shared by every portable payload that carries a snapshot version, including
/// the single-story share file, so all of them agree on what is readable.
void requireSupportedAppStateSchemaVersion(Object? encodedVersion) {
  if (encodedVersion == null) return;
  if (encodedVersion is! int || encodedVersion < minimumAppStateSchemaVersion) {
    throw const FormatException('Malformed application state schema version.');
  }
  if (encodedVersion > appStateSchemaVersion) {
    throw UnsupportedSchemaVersionException(encodedVersion);
  }
}

/// Decodes one profile entry while preserving the model's format validation.
ChildProfile _decodeProfile(Object? encodedProfile) {
  if (encodedProfile is! Map<String, Object?>) {
    throw const FormatException('Malformed child profile entry.');
  }
  return ChildProfile.fromJson(encodedProfile);
}

/// Decodes one story entry while preserving the model's format validation.
StoryBook _decodeStory(Object? encodedStory) {
  if (encodedStory is! Map<String, Object?>) {
    throw const FormatException('Malformed story library entry.');
  }
  return StoryBook.fromJson(encodedStory);
}
