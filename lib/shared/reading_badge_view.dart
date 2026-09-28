import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/reading_badge.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';

/// Bounded Material icon drawn for one reading badge.
///
/// Icons only: badges add no image asset and no download, exactly like the
/// kingdom decorations.
IconData readingBadgeIcon(ReadingBadge badge) {
  return switch (badge) {
    ReadingBadge.firstStory => AppIcons.stories,
    ReadingBadge.fiveStories => AppIcons.star,
    ReadingBadge.tenStories => AppIcons.crown,
    ReadingBadge.twentyFiveStories => AppIcons.readingBadge,
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
