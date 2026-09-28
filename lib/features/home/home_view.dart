import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/library/story_library_page.dart';

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

/// Which of the three things Home has to say goes under the greeting.
///
/// A kind rather than a sentence, so the wording stays in the widget with the
/// rest of the localization and this file stays free of `AppLocalizations`.
enum HomeGreetingLine {
  /// A book the active child can still finish, which is [HomeView.keepReading].
  continueReading,

  /// Drafts waiting for a parent, counted by [HomeView.draftCount].
  draftsWaiting,

  /// Neither of those: an invitation to write tonight's story.
  invitation,
}

/// Everything Home decides from one snapshot of the family's own state.
///
/// Home's screen used to work these out as it built itself, which put the
/// rules that actually break — the featured book leaving the strip, the strip's
/// cap, which of the three lines is true, and which child "See all" hands to
/// the shelf — where only a pumped widget could reach them. They are pure
/// functions of a stored snapshot and a moment, so they live here.
class HomeView {
  /// Groups one already-resolved screen; built only by [HomeView.of].
  const HomeView._({
    required this.activeProfile,
    required this.keepReading,
    required this.shelfStrip,
    required this.draftCount,
    required this.shelfRoute,
    required this.timeOfDay,
    required this.greetingLine,
  });

  /// Resolves everything Home shows for [state] at [now].
  ///
  /// [now] is supplied rather than read, so the greeting is assertable for any
  /// hour without waiting for it.
  factory HomeView.of(AppState state, {required DateTime now}) {
    final activeProfile = state.activeProfile;
    final shelf = activeProfile == null
        ? const <StoryBook>[]
        : state.storiesForProfile(activeProfile.id);
    final keepReading = _keepReading(shelf, activeProfile);
    final draftCount = state.draftStories.length;
    final strip = shelf
        .where((story) => story.id != keepReading?.id)
        .take(_shelfStripLength)
        .toList(growable: false);
    return HomeView._(
      activeProfile: activeProfile,
      keepReading: keepReading,
      shelfStrip: strip,
      draftCount: draftCount,
      shelfRoute: strip.isEmpty || activeProfile == null
          ? null
          : libraryRouteForChild(activeProfile.id),
      timeOfDay: homeTimeOfDay(now),
      greetingLine: _greetingLine(
        keepReading: keepReading,
        draftCount: draftCount,
      ),
    );
  }

  /// Covers the shelf strip shows before the library takes over.
  static const _shelfStripLength = 6;

  /// The child the family is reading as, or null before one is chosen.
  final ChildProfile? activeProfile;

  /// The book Home offers to keep reading, or null when there is none.
  ///
  /// The newest approved story on the active child's own shelf that this
  /// device has not recorded as read to its last page. Nothing about a reading
  /// position is stored, so a shelf where every book is finished, an empty
  /// shelf, and a family with no active child all resolve to null rather than
  /// to a book the child already closed.
  final StoryBook? keepReading;

  /// The covers under "On the shelf", newest first and at most six.
  ///
  /// [keepReading] is left out by identity, so the strip is the rest of the
  /// shelf rather than a second look at the same cover.
  final List<StoryBook> shelfStrip;

  /// Drafts waiting for a parent to read them, across every child.
  final int draftCount;

  /// Where "See all" hands the rest of the shelf, naming the active child.
  ///
  /// Null exactly when [shelfStrip] is empty, because the heading that carries
  /// the link only exists over a strip.
  final String? shelfRoute;

  /// Which part of the day the greeting belongs to.
  final HomeTimeOfDay timeOfDay;

  /// Which of the three lines goes under the greeting.
  final HomeGreetingLine greetingLine;

  /// The newest book on [profile]'s shelf this device has not finished.
  static StoryBook? _keepReading(List<StoryBook> shelf, ChildProfile? profile) {
    if (profile == null) return null;
    for (final story in shelf) {
      if (!profile.finishedStoryIds.contains(story.id)) return story;
    }
    return null;
  }

  /// Picks the one line that is true, in the order a family would act on it.
  ///
  /// A book the active child can still finish comes first, because that is the
  /// next thing a child would do. Drafts come next: they are the next thing a
  /// parent has to do, and nobody can read them until it is done. With neither,
  /// the line invites the family to write tonight's story.
  static HomeGreetingLine _greetingLine({
    required StoryBook? keepReading,
    required int draftCount,
  }) {
    if (keepReading != null) return HomeGreetingLine.continueReading;
    if (draftCount > 0) return HomeGreetingLine.draftsWaiting;
    return HomeGreetingLine.invitation;
  }
}
