import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/story_artwork.dart';

/// Shape one story takes inside the shared mosaic.
enum StoryCardVariant {
  /// Two-column cover tile: title, page count and date, heart, Demo badge.
  large,

  /// One-column cover tile carrying nothing but the cover and the title.
  small,

  /// Two-column row: cover thumbnail, title, meta, and the overflow control.
  wide,
}

/// Story tile that exposes only observable story actions.
///
/// Every variant is one full-size tap target that opens the story. The
/// secondary commands the surrounding feature allows live behind a single
/// overflow menu on the [StoryCardVariant.large] and [StoryCardVariant.wide]
/// shapes, so the tile face stays a book cover. The card never decides which
/// commands exist: the feature does, by passing them in [StoryCardActions].
class StoryCard extends StatelessWidget {
  /// Creates a book tile with the actions allowed by its surrounding feature.
  const StoryCard({
    required this.story,
    required this.actions,
    this.variant = StoryCardVariant.large,
    super.key,
  });

  /// Story represented by the tile.
  final StoryBook story;

  /// Commands exposed by the current library, review, or home surface.
  final StoryCardActions actions;

  /// Shape this tile takes in its mosaic.
  final StoryCardVariant variant;

  /// Height of a two-column cover tile.
  static const double largeHeight = 188;

  /// Height of a one-column cover tile.
  static const double smallHeight = 158;

  /// Height of a two-column story row.
  static const double wideHeight = 96;

  @override
  /// Renders the requested shape without changing what the story can do.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return switch (variant) {
      StoryCardVariant.large => _large(context, text),
      StoryCardVariant.small => _small(context),
      StoryCardVariant.wide => _wide(context, text),
    };
  }

  /// Builds the cover tile that carries the full story identity.
  Widget _large(BuildContext context, AppLocalizations text) {
    return _StoryTileSurface(
      height: largeHeight,
      onTap: actions.open,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _StoryCoverArt(story: story),
          const _CoverScrim(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Stack(
              children: <Widget>[
                if (_isDemo)
                  const Align(
                    alignment: AlignmentDirectional.topStart,
                    child: StoryDemoBadge(),
                  ),
                Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (story.isFavorite) const _FavoriteHeart(size: 22),
                      if (_hasSecondaryActions)
                        _StoryOverflowMenu(
                          story: story,
                          actions: actions,
                          color: Colors.white,
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        story.content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _meta(context, text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.frost,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the compact cover tile used for the books behind the newest one.
  Widget _small(BuildContext context) {
    return _StoryTileSurface(
      height: smallHeight,
      onTap: actions.open,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _StoryCoverArt(story: story),
          const _CoverScrim(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Text(
                story.content.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the short row a long shelf reads as a list rather than a wall.
  Widget _wide(BuildContext context, AppLocalizations text) {
    return _StoryTileSurface(
      height: wideHeight,
      onTap: actions.open,
      bordered: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 6, 14),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.square(
                dimension: 68,
                child: _StoryCoverArt(story: story),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          story.content.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (story.isFavorite) const _FavoriteHeart(size: 18),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (_isDemo) ...<Widget>[
                        const StoryDemoBadge(),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          _meta(context, text),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.mutedDeep,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_hasSecondaryActions)
              _StoryOverflowMenu(story: story, actions: actions)
            else
              const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Reads the story's length and age the way the shelf refers to a book.
  String _meta(BuildContext context, AppLocalizations text) {
    final pages = text.storyPageCount(story.content.pages.length);
    final created = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).format(story.createdAt.toLocal());
    return '$pages · $created';
  }

  /// Whether the surrounding feature allows anything besides opening the book.
  bool get _hasSecondaryActions => actions.secondaryCommands.isNotEmpty;

  /// Whether this book is offline sample content rather than written prose.
  bool get _isDemo => !BridgeStoryProvenance.marksStory(story);
}

/// Observable story-card commands grouped to keep widget construction stable.
class StoryCardActions {
  /// Creates actions supported by the card's current feature surface.
  const StoryCardActions({
    required this.open,
    this.delete,
    this.favorite,
    this.collections,
    this.share,
    this.illustrate,
  });

  /// Opens the approved reader or parent draft review.
  final VoidCallback open;

  /// Permanently deletes the story when the parent surface allows it.
  final VoidCallback? delete;

  /// Toggles the child-facing favorite marker when available.
  final VoidCallback? favorite;

  /// Opens parent-managed collection labels when available.
  final VoidCallback? collections;

  /// Saves the story as an encrypted single-story file when available.
  final VoidCallback? share;

  /// Asks the paired PC to draw this story's page pictures when available.
  final VoidCallback? illustrate;

  /// Every allowed command except opening, in one deliberate menu order.
  ///
  /// The favorite marker comes first because it is the one command a child
  /// uses, and deletion comes last because it is the one that cannot be
  /// undone. A feature that allows nothing here gets no overflow control at
  /// all rather than an empty menu.
  List<StoryCardCommand> get secondaryCommands {
    return <StoryCardCommand>[
      if (favorite != null)
        StoryCardCommand(kind: StoryCardCommandKind.favorite, run: favorite!),
      if (collections != null)
        StoryCardCommand(
          kind: StoryCardCommandKind.collections,
          run: collections!,
        ),
      if (illustrate != null)
        StoryCardCommand(
          kind: StoryCardCommandKind.illustrate,
          run: illustrate!,
        ),
      if (share != null)
        StoryCardCommand(kind: StoryCardCommandKind.share, run: share!),
      if (delete != null)
        StoryCardCommand(kind: StoryCardCommandKind.delete, run: delete!),
    ];
  }
}

/// Secondary story command a feature allowed, and what it is.
enum StoryCardCommandKind {
  /// Toggles the child-facing favorite marker.
  favorite,

  /// Opens the parent-gated collection editor.
  collections,

  /// Asks the paired PC for this story's pictures.
  illustrate,

  /// Writes the parent-gated encrypted single-story file.
  share,

  /// Deletes the story behind the parent gate.
  delete,
}

/// One entry of the overflow menu: what it is and the command it runs.
class StoryCardCommand {
  /// Pairs a command kind with the callback its feature supplied.
  const StoryCardCommand({required this.kind, required this.run});

  /// Which of the five secondary commands this entry is.
  final StoryCardCommandKind kind;

  /// The feature's callback, run unchanged so gating stays where it lives.
  final VoidCallback run;
}

/// The one overflow control the large and wide tiles carry.
class _StoryOverflowMenu extends StatelessWidget {
  /// Creates a menu over the commands the feature allowed.
  const _StoryOverflowMenu({
    required this.story,
    required this.actions,
    this.color = AppTheme.frost,
  });

  /// Story every listed command applies to.
  final StoryBook story;

  /// Commands allowed by the surrounding feature.
  final StoryCardActions actions;

  /// Ink the control is drawn in, lighter when it sits on cover artwork.
  final Color color;

  @override
  /// Lists allowed commands only, and runs each one exactly as it was given.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return PopupMenuButton<StoryCardCommand>(
      tooltip: text.moreStoryActions,
      icon: Icon(AppIcons.moreActions, color: color),
      onSelected: (command) => command.run(),
      itemBuilder: (context) => <PopupMenuEntry<StoryCardCommand>>[
        for (final command in actions.secondaryCommands)
          PopupMenuItem<StoryCardCommand>(
            value: command,
            child: Row(
              children: <Widget>[
                Icon(_iconFor(command.kind), size: 20),
                const SizedBox(width: 12),
                // A menu is only as wide as the longest label it can show, so
                // the label wraps instead of running past its own edge.
                Expanded(child: Text(_labelFor(text, command.kind))),
              ],
            ),
          ),
      ],
    );
  }

  /// Keeps every command recognizable by the icon it had on the card face.
  IconData _iconFor(StoryCardCommandKind kind) {
    return switch (kind) {
      StoryCardCommandKind.favorite =>
        story.isFavorite ? AppIcons.favourite : AppIcons.notFavourite,
      StoryCardCommandKind.collections => AppIcons.collection,
      StoryCardCommandKind.illustrate => AppIcons.illustrate,
      StoryCardCommandKind.share => AppIcons.storyFile,
      StoryCardCommandKind.delete => AppIcons.delete,
    };
  }

  /// Reuses the wording each command already had as an icon tooltip.
  String _labelFor(AppLocalizations text, StoryCardCommandKind kind) {
    return switch (kind) {
      StoryCardCommandKind.favorite =>
        story.isFavorite ? text.removeFavorite : text.addFavorite,
      StoryCardCommandKind.collections => text.manageCollections,
      StoryCardCommandKind.illustrate => text.illustrateStory,
      StoryCardCommandKind.share => text.shareStoryFile,
      StoryCardCommandKind.delete => text.delete,
    };
  }
}

/// Shared tile body: one rounded surface whose whole face opens the story.
class _StoryTileSurface extends StatelessWidget {
  /// Creates a tile of fixed [height] around [child].
  const _StoryTileSurface({
    required this.height,
    required this.onTap,
    required this.child,
    this.bordered = false,
  });

  /// Height the tile keeps so mosaic rows line up.
  final double height;

  /// The story-opening command, which owns the whole tile.
  final VoidCallback onTap;

  /// Tile content drawn inside the clipped surface.
  final Widget child;

  /// Whether the tile needs a hairline, used where no cover fills it.
  final bool bordered;

  @override
  /// Keeps the open action a full-size tap target on every variant.
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.tile,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: bordered
            ? const BorderSide(color: AppTheme.hairline)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: height, child: child),
      ),
    );
  }
}

/// The favourite marker a story carries once a child has starred it.
class _FavoriteHeart extends StatelessWidget {
  /// Creates the heart at the size its tile has room for.
  const _FavoriteHeart({required this.size});

  /// Glyph size in logical pixels.
  final double size;

  @override
  /// Shows state only; favouriting itself lives in the overflow menu.
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Icon(AppIcons.favourite, size: size, color: AppTheme.candle),
    );
  }
}

/// Darkening wash between cover artwork and the text printed on it.
class _CoverScrim extends StatelessWidget {
  /// Creates the shared bottom-weighted scrim.
  const _CoverScrim();

  @override
  /// Keeps a title readable over whatever the PC happened to draw.
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: <double>[0, 0.65],
          colors: <Color>[Color(0xD106080F), Color(0x1406080F)],
        ),
      ),
    );
  }
}

/// Labels demo stories so sample content cannot pass as AI output.
///
/// Bridge-generated stories carry no badge: their text is real AI output
/// whether the PC has drawn their pictures yet or not.
class StoryDemoBadge extends StatelessWidget {
  /// Creates the demo badge in its one shared size.
  const StoryDemoBadge({super.key});

  @override
  /// Renders the localized badge on a dark, always-legible pill.
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        AppLocalizations.of(context).demoBadge,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
      ),
    );
  }
}

/// Story cover: the book's own first picture once the PC has drawn one.
///
/// Until then, and always for demo content, the deterministic gradient stands
/// in for it. Used by the parent review screen, which shows one book at a
/// time; the mosaic tiles compose the same artwork themselves.
class StoryCover extends StatelessWidget {
  /// Creates a cover for the supplied story.
  const StoryCover({required this.story, required this.height, super.key});

  /// Story whose first page, title, and style define the cover.
  final StoryBook story;

  /// Vertical cover extent in logical pixels.
  final double height;

  @override
  /// Makes demo artwork unmistakable while preserving the final layout.
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _StoryCoverArt(story: story),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: <Widget>[
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    AppIcons.sparkle,
                    color: Color(0xCCFFFFFF),
                    size: 28,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.bottomStart,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (!BridgeStoryProvenance.marksStory(story)) ...<Widget>[
                        const StoryDemoBadge(),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        story.content.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cover artwork alone: the drawn picture when there is one, else a gradient.
///
/// A real drawn cover is deliberately darkened rather than shown at full
/// strength, because a title, a badge and a heart sit on top of it and have to
/// stay readable over whatever the PC happened to draw.
class _StoryCoverArt extends ConsumerWidget {
  /// Creates the artwork layer of one story's cover.
  const _StoryCoverArt({required this.story});

  /// Story whose first page and style define the artwork.
  final StoryBook story;

  @override
  /// Paints the cached page image over its stable fallback gradient.
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = StoryArtwork.coverOf(ref, story);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(gradient: StoryArtwork.gradientOf(story)),
        ),
        if (cover != null) _coverImage(cover),
      ],
    );
  }

  /// Paints the drawn cover behind the tile content, dimmed for readability.
  Widget _coverImage(Uint8List bytes) {
    return Image.memory(
      bytes,
      key: const ValueKey<String>('story-cover-image'),
      fit: BoxFit.cover,
      color: Colors.black45,
      colorBlendMode: BlendMode.darken,
      gaplessPlayback: true,
    );
  }
}
