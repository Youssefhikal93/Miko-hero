import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:miko_hero/core/models/child_profile.dart';

/// One child's face in a circle: their photo, or the initial standing in.
///
/// Six screens used to decode the same stored photo six ways, each re-deciding
/// its own ring, accent and fallback, and only one of them survived a photo
/// that would not decode. `ChildProfile` validates base64 at the storage seam,
/// but a widget must not depend on an invariant it cannot see, so every failure
/// this widget can meet — an empty photo, base64 that will not decode, bytes
/// that are not an image — ends at the initial rather than at a broken build.
class HeroFace extends StatelessWidget {
  /// Creates the face of [profile] at [size] logical pixels across.
  const HeroFace({
    required this.profile,
    required this.size,
    this.ring = false,
    this.accent,
    this.background,
    this.fallbackIcon,
    this.fallbackColor,
    super.key,
  });

  /// Child whose face this is, absent before a family has chosen one.
  final ChildProfile? profile;

  /// Diameter of the face itself; a ring is drawn just outside it.
  final double size;

  /// Whether the face wears a ring in its accent.
  final bool ring;

  /// Ink of the ring and of the initial, defaulting to the child's own colour.
  final Color? accent;

  /// Surface behind a face with no photo, defaulting to a wash of the accent.
  final Color? background;

  /// Glyph preferred over the initial when there is no photo to draw.
  final IconData? fallbackIcon;

  /// Ink of the initial or the icon, defaulting to the accent.
  final Color? fallbackColor;

  /// Width of the ring, matching the design reference on every surface.
  static const _ringWidth = 2.0;

  @override
  /// Draws the photo when there is one, and never fails when there is not.
  Widget build(BuildContext context) {
    final face = ClipOval(
      child: SizedBox.square(dimension: size, child: _face(context)),
    );
    if (!ring) return face;
    return Container(
      padding: const EdgeInsets.all(_ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _accent(context), width: _ringWidth),
      ),
      child: face,
    );
  }

  /// Decodes the stored photo, falling back the moment anything is wrong.
  Widget _face(BuildContext context) {
    final photo = profile?.photoBase64 ?? '';
    if (photo.isEmpty) return _fallback(context);
    try {
      return Image.memory(
        base64Decode(photo),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _fallback(context),
      );
    } on FormatException {
      return _fallback(context);
    }
  }

  /// Names the child with their initial, or with the glyph a surface asked for.
  Widget _fallback(BuildContext context) {
    final accent = _accent(context);
    final ink = fallbackColor ?? accent;
    final icon = fallbackIcon;
    return ColoredBox(
      color: background ?? accent.withValues(alpha: 0.16),
      child: Center(
        child: icon == null
            ? Text(
                _initial,
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              )
            : Icon(icon, size: size * 0.52, color: ink),
      ),
    );
  }

  /// The child's saved colour, or the theme's before a child is active.
  Color _accent(BuildContext context) {
    final child = profile;
    if (accent != null) return accent!;
    if (child == null) return Theme.of(context).colorScheme.primary;
    return Color(child.themeColorValue);
  }

  /// The first whole character of the hero's name, emoji and all.
  ///
  /// Read as a grapheme cluster rather than a code unit, so a name that starts
  /// outside the basic plane is not sliced into half a character.
  String get _initial {
    final name = profile?.name.trim() ?? '';
    if (name.isEmpty) return '·';
    return name.characters.first.toUpperCase();
  }
}
