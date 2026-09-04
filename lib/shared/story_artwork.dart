import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/ai_connection/bridge_story_provenance.dart';
import 'package:miko_hero/core/illustrations/illustration_providers.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Every story's artwork: the picture the PC drew, or the colours standing in.
///
/// One table decides what a book looks like before ComfyUI has drawn it, and
/// one lookup decides whether it has. The shelf tile, the reader page and the
/// creation form's style swatch all read them here, so the swatch a parent taps
/// is the artwork the story comes back wearing.
abstract final class StoryArtwork {
  /// Placeholder colours of one illustration style for one hero.
  ///
  /// The single hue table. Ordered as the gradient paints them, so the list is
  /// directly comparable between the swatch, the cover and the page.
  static List<Color> placeholderColors(
    IllustrationStyle style,
    ChildGender gender,
  ) {
    final primary = AppTheme.primaryFor(gender);
    final secondary = AppTheme.secondaryFor(gender);
    return switch (style) {
      IllustrationStyle.pictureBook => <Color>[primary, secondary],
      IllustrationStyle.watercolor => <Color>[
        secondary,
        primary.withValues(alpha: 0.78),
      ],
      // The violet is a palette decision, not an artwork-private one: the
      // redesign reference paints its own cover placeholders with it. It is
      // [AppTheme.violet] rather than [AppTheme.purple] so a parent choosing a
      // purple kingdom cannot repaint a story's artwork.
      IllustrationStyle.colorful3d => <Color>[
        primary,
        secondary,
        AppTheme.violet,
      ],
    };
  }

  /// Placeholder gradient of one illustration style for one hero.
  static LinearGradient placeholderGradient(
    IllustrationStyle style,
    ChildGender gender,
  ) {
    return LinearGradient(colors: placeholderColors(style, gender));
  }

  /// Placeholder gradient [story] falls back to on every surface showing it.
  static LinearGradient gradientOf(StoryBook story) {
    final request = story.content.request;
    return placeholderGradient(request.presentation.style, request.gender);
  }

  /// Colours the creation form previews one illustration style with.
  ///
  /// The same table the story will be painted from, so a girl no longer taps a
  /// cyan card and receives rose artwork. A request with no hero chosen yet has
  /// no gender either, and previews the neutral palette it would produce.
  static List<Color> swatchFor(IllustrationStyle style, ChildGender? gender) {
    return placeholderColors(style, gender ?? ChildGender.unspecified);
  }

  /// Cached bytes of [story]'s cover picture, or null while it has none.
  ///
  /// The cover is the first page's picture: a book the PC has not illustrated,
  /// and every demo book, resolves to no bytes and keeps its gradient.
  static Uint8List? coverOf(WidgetRef ref, StoryBook story) {
    final pages = story.content.pages;
    if (pages.isEmpty) return null;
    return pageOf(ref, pages.first);
  }

  /// Cached bytes of one page's picture, or null while it has none.
  ///
  /// Watches the shared per-page provider, so one finished download repaints
  /// exactly the surfaces showing that page.
  static Uint8List? pageOf(WidgetRef ref, StoryPage page) {
    final provenance = BridgeStoryProvenance.fromSceneDescription(
      page.sceneDescription,
    );
    if (provenance == null) return null;
    return ref
        .watch(illustrationBytesProvider(provenance.illustrationId))
        .value;
  }
}
