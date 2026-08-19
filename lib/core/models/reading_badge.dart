/// Local reading badges earned by finishing distinct stories.
///
/// Counts only: there are deliberately no streaks, dates, or daily goals, so a
/// child who reads nothing for a month never loses anything.
enum ReadingBadge {
  /// Earned the first time a story is read to its last page.
  firstStory(1),

  /// Earned after five different stories are finished.
  fiveStories(5),

  /// Earned after ten different stories are finished.
  tenStories(10),

  /// Earned after twenty-five different stories are finished.
  twentyFiveStories(25);

  /// Associates one badge with the number of finished stories it needs.
  const ReadingBadge(this.requiredStories);

  /// Distinct finished stories required before this badge is earned.
  final int requiredStories;

  /// Whether [finishedStories] is already enough for this badge.
  bool isEarnedWith(int finishedStories) {
    return finishedStories >= requiredStories;
  }

  /// Badges earned with [finishedStories], in ascending threshold order.
  static List<ReadingBadge> earnedWith(int finishedStories) {
    return ReadingBadge.values
        .where((badge) => badge.isEarnedWith(finishedStories))
        .toList(growable: false);
  }

  /// Badge whose threshold is reached exactly at [finishedStories], if any.
  ///
  /// Used to congratulate a child once, at the moment a badge is first earned.
  static ReadingBadge? reachedAt(int finishedStories) {
    for (final badge in ReadingBadge.values) {
      if (badge.requiredStories == finishedStories) return badge;
    }
    return null;
  }

  /// Next badge still to earn after [finishedStories], or null when all are.
  static ReadingBadge? nextAfter(int finishedStories) {
    for (final badge in ReadingBadge.values) {
      if (!badge.isEarnedWith(finishedStories)) return badge;
    }
    return null;
  }
}
