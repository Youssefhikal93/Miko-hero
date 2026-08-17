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
}
