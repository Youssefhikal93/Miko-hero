import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
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
  ///
  /// The reading action owns its own full-width row and the secondary icons wrap
  /// below it, so a one-column shelf on a 360 px phone keeps every 48 px touch
  /// target no matter how many actions the surrounding feature allows.
  Widget _actions(AppLocalizations text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FilledButton.tonalIcon(
          onPressed: actions.open,
          icon: const Icon(Icons.chrome_reader_mode_rounded),
          label: Text(text.openStory),
        ),
        if (_iconActions(text).isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Wrap(alignment: WrapAlignment.end, children: _iconActions(text)),
        ],
      ],
    );
  }

  /// Secondary story commands allowed by the current feature surface.
  List<Widget> _iconActions(AppLocalizations text) {
    return <Widget>[
      if (actions.favorite != null)
        IconButton(
          onPressed: actions.favorite,
          tooltip: story.isFavorite ? text.removeFavorite : text.addFavorite,
          icon: Icon(
            story.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
          ),
        ),
      if (actions.collections != null)
        IconButton(
          onPressed: actions.collections,
          tooltip: text.manageCollections,
          icon: const Icon(Icons.folder_copy_outlined),
        ),
      if (actions.illustrate != null)
        IconButton(
          onPressed: actions.illustrate,
          tooltip: text.illustrateStory,
          icon: const Icon(Icons.palette_outlined),
        ),
      if (actions.share != null)
        IconButton(
          onPressed: actions.share,
          tooltip: text.shareStoryFile,
          icon: const Icon(Icons.ios_share_rounded),
        ),
      if (actions.delete != null)
        IconButton(
          onPressed: actions.delete,
          tooltip: text.delete,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
    ];
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
}

/// Story cover: the book's own first picture once the PC has drawn one.
///
/// Until then, and always for demo content, the deterministic gradient stands
/// in for it. A real drawn cover is deliberately darkened rather than shown at
/// full strength, because the title and the DEMO badge sit on top of it and
/// have to stay readable over whatever the PC happened to draw.
class StoryCover extends ConsumerWidget {
  /// Creates a cover for the supplied story.
  const StoryCover({required this.story, required this.height, super.key});

  /// Story whose first page, title, and style define the cover.
  final StoryBook story;

  /// Vertical cover extent in logical pixels.
  final double height;

  @override
  /// Makes demo artwork unmistakable while preserving the final layout.
  Widget build(BuildContext context, WidgetRef ref) {
    final cover = _coverBytes(ref);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(decoration: BoxDecoration(gradient: _gradient())),
          if (cover != null) _coverImage(cover),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: <Widget>[
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.auto_awesome,
                    color: Color(0xCCFFFFFF),
                    size: 28,
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (!BridgeStoryProvenance.marksStory(story)) ...<Widget>[
                        _demoBadge(context),
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

  /// Reads the cached first-page image of a PC story, or null for anything else.
  Uint8List? _coverBytes(WidgetRef ref) {
    if (!BridgeStoryProvenance.marksStory(story)) return null;
    final pages = story.content.pages;
    if (pages.isEmpty) return null;
    final provenance = BridgeStoryProvenance.fromSceneDescription(
      pages.first.sceneDescription,
    );
    if (provenance == null) return null;
    return ref
        .watch(illustrationBytesProvider(provenance.illustrationId))
        .value;
  }

  /// Paints the drawn cover behind the card content, dimmed for readability.
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

  /// Labels demo stories so sample content cannot pass as AI output.
  ///
  /// Bridge-generated stories carry no badge: their text is real AI output
  /// whether the PC has drawn their pictures yet or not.
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
