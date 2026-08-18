import 'package:flutter/widgets.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Complete locally persisted state needed to render the application.
class AppState {
  /// Creates an immutable application snapshot.
  const AppState({
    required this.locale,
    required this.profiles,
    required this.stories,
    required this.activeProfileId,
  });

  /// Current interface locale.
  final Locale locale;

  /// Child profiles in their stable local display order.
  final List<ChildProfile> profiles;

  /// Books sorted newest first.
  final List<StoryBook> stories;

  /// Profile currently controlling the personalized application theme.
  final String? activeProfileId;

  /// Active profile, or null until the parent selects or saves one.
  ChildProfile? get activeProfile {
    final profileId = activeProfileId;
    return profileId == null ? null : profileById(profileId);
  }

  /// Resolves the child associated with a story, including its private photo.
  ChildProfile? profileById(String profileId) {
    for (final profile in profiles) {
      if (profile.id == profileId) return profile;
    }
    return null;
  }

  /// Returns the newest-first shelf belonging to one child profile.
  List<StoryBook> storiesForProfile(String profileId) {
    return stories
        .where((story) => story.content.request.profileId == profileId)
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
}
