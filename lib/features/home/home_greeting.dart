import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Part of the day Home greets the family in.
enum HomeTimeOfDay {
  /// From five in the morning until noon.
  morning,

  /// From noon until five in the afternoon.
  afternoon,

  /// From five in the afternoon until ten at night.
  evening,

  /// From ten at night until five in the morning.
  night,
}

/// Resolves the part of the day [moment] falls in, on the device's own clock.
///
/// Kept a pure function of one supplied moment so the greeting is assertable
/// without waiting for a real hour to come round.
HomeTimeOfDay homeTimeOfDay(DateTime moment) {
  final hour = moment.hour;
  if (hour >= 22 || hour < 5) return HomeTimeOfDay.night;
  if (hour < 12) return HomeTimeOfDay.morning;
  if (hour < 17) return HomeTimeOfDay.afternoon;
  return HomeTimeOfDay.evening;
}

/// Localized greeting for one part of the day.
String homeGreeting(AppLocalizations text, HomeTimeOfDay timeOfDay) {
  return switch (timeOfDay) {
    HomeTimeOfDay.morning => text.greetingMorning,
    HomeTimeOfDay.afternoon => text.greetingAfternoon,
    HomeTimeOfDay.evening => text.greetingEvening,
    HomeTimeOfDay.night => text.greetingNight,
  };
}

/// The one line under the greeting, taken from what this family really has.
///
/// A book the active child can still finish comes first, because that is the
/// next thing a child would do. Drafts come next: they are the next thing a
/// parent has to do, and nobody can read them until it is done. With neither,
/// the line invites the family to write tonight's story.
String homeGreetingLine(
  AppLocalizations text, {
  required StoryBook? keepReading,
  required bool hasDrafts,
}) {
  if (keepReading != null) {
    return text.greetingContinueStory(keepReading.content.title);
  }
  if (hasDrafts) return text.greetingDraftsWaiting;
  return text.greetingCreateStory;
}

/// The book Home offers to keep reading, or null when there is none.
///
/// The newest approved story on [profile]'s own shelf that this device has not
/// recorded as read to its last page. Nothing about a reading position is
/// stored, so a shelf where every book is finished, an empty shelf, and a
/// family with no active child all resolve to null rather than to a book the
/// child already closed.
StoryBook? keepReadingStory(AppState state, ChildProfile? profile) {
  if (profile == null) return null;
  for (final story in state.storiesForProfile(profile.id)) {
    if (!profile.finishedStoryIds.contains(story.id)) return story;
  }
  return null;
}
