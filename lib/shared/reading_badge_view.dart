import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/reading_badge.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Bounded Material icon drawn for one reading badge.
///
/// Icons only: badges add no image asset and no download, exactly like the
/// kingdom decorations.
IconData readingBadgeIcon(ReadingBadge badge) {
  return switch (badge) {
    ReadingBadge.firstStory => Icons.auto_stories_rounded,
    ReadingBadge.fiveStories => Icons.star_rounded,
    ReadingBadge.tenStories => Icons.workspace_premium_rounded,
    ReadingBadge.twentyFiveStories => Icons.emoji_events_rounded,
  };
}

/// Localizes one badge name while keeping its stable stored threshold.
String readingBadgeName(AppLocalizations text, ReadingBadge badge) {
  return switch (badge) {
    ReadingBadge.firstStory => text.badgeFirstStory,
    ReadingBadge.fiveStories => text.badgeFiveStories,
    ReadingBadge.tenStories => text.badgeTenStories,
    ReadingBadge.twentyFiveStories => text.badgeTwentyFiveStories,
  };
}
