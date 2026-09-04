import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/reading_badge.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/reading_badge_view.dart';

/// Earned reading badges and progress toward the next one for one child.
///
/// Shows counts only. There is deliberately no streak, calendar, or daily goal,
/// so a week without reading never takes anything away from a child.
class ReadingRewardsCard extends StatelessWidget {
  /// Creates the reward summary for the active My Kingdom profile.
  const ReadingRewardsCard({required this.profile, super.key});

  /// Active child whose finished stories produced these badges.
  final ChildProfile profile;

  @override
  /// Renders the finished count, every badge, and the next milestone.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final finished = profile.finishedStoryCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.readingBadge),
              title: Text(text.readingBadgesTitle),
              subtitle: Text(text.readingBadgesBody(profile.name)),
            ),
            Text(text.storiesFinished(finished)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ReadingBadge.values
                  .map((badge) => _badgeChip(context, text, badge, finished))
                  .toList(growable: false),
            ),
            const SizedBox(height: 16),
            ..._progress(context, text, finished),
          ],
        ),
      ),
    );
  }

  /// Builds one badge chip that shows plainly whether it is earned yet.
  Widget _badgeChip(
    BuildContext context,
    AppLocalizations text,
    ReadingBadge badge,
    int finished,
  ) {
    final earned = badge.isEarnedWith(finished);
    final color = earned
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).disabledColor;
    return Chip(
      key: ValueKey<String>('reading-badge-${badge.name}'),
      avatar: Icon(readingBadgeIcon(badge), size: 18, color: color),
      label: Text(readingBadgeName(text, badge)),
      labelStyle: TextStyle(color: color),
    );
  }

  /// Describes the next milestone, or celebrates a complete collection.
  List<Widget> _progress(
    BuildContext context,
    AppLocalizations text,
    int finished,
  ) {
    final next = ReadingBadge.nextAfter(finished);
    if (next == null) {
      return <Widget>[Text(text.allBadgesEarned)];
    }
    return <Widget>[
      ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: finished / next.requiredStories,
          minHeight: 8,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        text.nextBadgeProgress(
          next.requiredStories - finished,
          readingBadgeName(text, next),
        ),
      ),
    ];
  }
}
