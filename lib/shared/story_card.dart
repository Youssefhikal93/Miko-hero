import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Library card that exposes only observable story actions.
class StoryCard extends StatelessWidget {
  /// Creates a book card with the actions allowed by its surrounding feature.
  const StoryCard({required this.story, required this.actions, super.key});

  /// Story represented by the card.
  final StoryBook story;

  /// Commands exposed by the current library, review, or home surface.
  final StoryCardActions actions;

  @override
  /// Renders a responsive cover, metadata, and explicit actions.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: actions.open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            StoryCover(story: story, height: 190),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    story.content.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat.yMMMd(
                      Localizations.localeOf(context).toString(),
                    ).format(story.createdAt.toLocal()),
                    style: const TextStyle(color: Color(0xFFA7ABBA)),
                  ),
                  const SizedBox(height: 14),
                  _actions(text),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Keeps destructive and primary actions visually distinct.
  Widget _actions(AppLocalizations text) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.tonalIcon(
            onPressed: actions.open,
            icon: const Icon(Icons.chrome_reader_mode_rounded),
            label: Text(text.openStory),
          ),
        ),
        if (actions.favorite != null) ...<Widget>[
          const SizedBox(width: 4),
          IconButton(
            onPressed: actions.favorite,
            tooltip: story.isFavorite ? text.removeFavorite : text.addFavorite,
            icon: Icon(
              story.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
          ),
        ],
        if (actions.collections != null) ...<Widget>[
          IconButton(
            onPressed: actions.collections,
            tooltip: text.manageCollections,
            icon: const Icon(Icons.folder_copy_outlined),
          ),
        ],
        if (actions.delete != null) ...<Widget>[
          const SizedBox(width: 8),
          IconButton(
            onPressed: actions.delete,
            tooltip: text.delete,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ],
    );
  }
}

/// Observable story-card commands grouped to keep widget construction stable.
class StoryCardActions {
  /// Creates actions supported by the card's current feature surface.
  const StoryCardActions({
    required this.open,
    this.delete,
    this.favorite,
    this.collections,
  });

  /// Opens the approved reader or parent draft review.
  final VoidCallback open;

  /// Permanently deletes the story when the parent surface allows it.
  final VoidCallback? delete;

  /// Toggles the child-facing favorite marker when available.
  final VoidCallback? favorite;

  /// Opens parent-managed collection labels when available.
  final VoidCallback? collections;
}

/// Generated cover treatment used until ComfyUI supplies real illustrations.
class StoryCover extends StatelessWidget {
  /// Creates a deterministic visual cover for the supplied story.
  const StoryCover({required this.story, required this.height, super.key});

  /// Story whose title and style define the cover.
  final StoryBook story;

  /// Vertical cover extent in logical pixels.
  final double height;

  @override
  /// Makes demo artwork unmistakable while preserving the final layout.
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: _gradient()),
      child: Stack(
        children: <Widget>[
          const Align(
            alignment: Alignment.topRight,
            child: Icon(Icons.auto_awesome, color: Color(0xCCFFFFFF), size: 28),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _demoBadge(context),
                const SizedBox(height: 10),
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
    );
  }

  /// Labels placeholder art so it cannot be mistaken for AI output.
  Widget _demoBadge(BuildContext context) {
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

  /// Selects a stable palette corresponding to the requested visual style.
  LinearGradient _gradient() {
    final primary = AppTheme.primaryFor(story.content.request.gender);
    final secondary = AppTheme.secondaryFor(story.content.request.gender);
    return switch (story.content.request.presentation.style) {
      IllustrationStyle.pictureBook => LinearGradient(
        colors: <Color>[primary, secondary],
      ),
      IllustrationStyle.watercolor => LinearGradient(
        colors: <Color>[secondary, primary.withValues(alpha: 0.78)],
      ),
      IllustrationStyle.colorful3d => LinearGradient(
        colors: <Color>[primary, secondary, const Color(0xFF5545D9)],
      ),
    };
  }
}
