import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/reading_badge.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/story_card.dart';

/// The book Home offers to open again, on a full-width cover tile.
///
/// Nothing about a reading position is stored, so the tile promises nothing
/// about one: it opens the reader at the first page and states how long the
/// book is, which is the honest version of the design's progress line.
class HomeKeepReadingTile extends StatelessWidget {
  /// Creates the tile for one unfinished story of the active child.
  const HomeKeepReadingTile({required this.story, super.key});

  /// Story opened when the tile is tapped.
  final StoryBook story;

  /// Height shared with the mosaic's two-column cover tile.
  static const double height = StoryCard.largeHeight;

  @override
  /// Keeps the whole cover one tap target that opens the reader.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return HomeTileSurface(
      key: const ValueKey<String>('home-keep-reading'),
      height: height,
      onTap: () => context.go('/story/${story.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          StoryCover(story: story, height: height),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text.keepReading.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.candleLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text.storyPageCount(story.content.pages.length),
                    style: const TextStyle(fontSize: 13, color: AppTheme.frost),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one-tap path to a new story, in the shared candle emphasis.
class HomeNewStoryTile extends StatelessWidget {
  /// Creates the create-story tile.
  const HomeNewStoryTile({super.key});

  /// Height shared by the two one-column tiles of the first mosaic row.
  static const double height = 128;

  @override
  /// Sends the family to the existing creation form without pre-filling it.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return HomeTileSurface(
      key: const ValueKey<String>('home-new-story'),
      height: height,
      color: AppTheme.candle,
      onTap: () => context.go('/create'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Icon(AppIcons.sparkle, size: 26, color: AppTheme.onCandle),
            Text(
              text.newStory,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: AppTheme.onCandle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How many of the four reading badges the active child has earned.
///
/// Read-only, like every other surface that shows badges: the count comes from
/// the child's own finished-story history and nothing here can change it.
class HomeReadingBadgesTile extends StatelessWidget {
  /// Creates the badge count tile for one child.
  const HomeReadingBadgesTile({required this.profile, super.key});

  /// Child whose finished stories produced the earned badges.
  final ChildProfile profile;

  /// Height shared by the two one-column tiles of the first mosaic row.
  static const double height = HomeNewStoryTile.height;

  @override
  /// States the count plainly rather than hinting at a reward to chase.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final earned = ReadingBadge.earnedWith(profile.finishedStoryCount).length;
    return HomeTileSurface(
      key: const ValueKey<String>('home-reading-badges'),
      height: height,
      bordered: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Icon(AppIcons.readingBadge, size: 26, color: AppTheme.candle),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  text.readingBadgesEarned(earned, ReadingBadge.values.length),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  text.readingBadgesTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.mutedDeep,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The parent's row of stories no child can read yet.
///
/// Shown only while drafts exist, and its tap leads to the review route, which
/// is where the parent gate already lives.
class HomeDraftsRow extends StatelessWidget {
  /// Creates the row for a family with [draftCount] stories awaiting review.
  const HomeDraftsRow({required this.draftCount, super.key});

  /// Number of generated stories still waiting for a parent decision.
  final int draftCount;

  /// Height of the two-column parent notice row.
  static const double height = 72;

  @override
  /// Says who the row is for, so a child is never puzzled by it.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return HomeTileSurface(
      key: const ValueKey<String>('home-drafts-waiting'),
      height: height,
      borderColor: AppTheme.hairlineWarm,
      bordered: true,
      onTap: () => context.go('/review'),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 12, 0),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.candle.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                AppIcons.factCheck,
                size: 20,
                color: AppTheme.candle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text.draftsWaitingForReview(draftCount),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    text.draftsWaitingHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.mutedDeep,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.forward, color: AppTheme.mutedDeep),
          ],
        ),
      ),
    );
  }
}

/// One rounded Home tile: a fixed height, and a whole face that acts at once.
class HomeTileSurface extends StatelessWidget {
  /// Creates a tile of [height], tappable only when [onTap] is supplied.
  const HomeTileSurface({
    required this.height,
    required this.child,
    this.onTap,
    this.color = AppTheme.tile,
    this.bordered = false,
    this.borderColor = AppTheme.hairline,
    super.key,
  });

  /// Height the tile keeps so mosaic rows line up.
  final double height;

  /// Tile content drawn inside the clipped surface.
  final Widget child;

  /// Command owning the whole tile face, absent on tiles that only report.
  final VoidCallback? onTap;

  /// Tile background.
  final Color color;

  /// Whether the tile needs a hairline, used where no artwork fills it.
  final bool bordered;

  /// Hairline colour, warm on the tiles addressed to a parent.
  final Color borderColor;

  @override
  /// Keeps a tile's action a full-size tap target, exactly like a story tile.
  Widget build(BuildContext context) {
    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: bordered ? BorderSide(color: borderColor) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: height, child: child),
      ),
    );
  }
}
