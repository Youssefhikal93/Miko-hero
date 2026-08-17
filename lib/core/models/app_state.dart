import 'package:flutter/widgets.dart';
import 'package:miko_hero/core/models/daughter_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Complete locally persisted state needed to render the application.
class AppState {
  /// Creates an immutable application snapshot.
  const AppState({
    required this.locale,
    required this.profile,
    required this.stories,
  });

  /// Current interface locale.
  final Locale locale;

  /// Single child profile, or null until onboarding is complete.
  final DaughterProfile? profile;

  /// Books sorted newest first.
  final List<StoryBook> stories;
}
