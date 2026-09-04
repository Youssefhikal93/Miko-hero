import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/hero_face.dart';

/// Resolves the Material icon that stands for one favourite symbol.
///
/// Bounded on purpose: every symbol is a bundled Material glyph, so no new
/// binary asset and no download is ever needed.
IconData kingdomSymbolIcon(KingdomSymbol symbol) {
  return switch (symbol) {
    KingdomSymbol.star => AppIcons.star,
    KingdomSymbol.rocket => AppIcons.rocket,
    KingdomSymbol.crown => AppIcons.crown,
    KingdomSymbol.butterfly => AppIcons.butterfly,
    KingdomSymbol.dragon => AppIcons.dragon,
    KingdomSymbol.flower => AppIcons.flower,
    KingdomSymbol.football => AppIcons.football,
    KingdomSymbol.music => AppIcons.music,
    KingdomSymbol.book => AppIcons.stories,
    KingdomSymbol.paw => AppIcons.paw,
    KingdomSymbol.rainbow => AppIcons.rainbow,
    KingdomSymbol.sparkles => AppIcons.sparkle,
  };
}

/// Builds the page backdrop for one child, keeping dark-theme text readable.
///
/// Every flavor stays a dark, low-luminance wash over the shared night token so
/// body text keeps the same contrast it has on the default night sky.
LinearGradient kingdomBackdropGradient(KingdomBackdrop backdrop) {
  const ink = AppTheme.night;
  final tint = switch (backdrop) {
    KingdomBackdrop.nightSky => const Color(0xFF2F2340),
    KingdomBackdrop.meadow => const Color(0xFF1D3A24),
    KingdomBackdrop.ocean => const Color(0xFF11313F),
    KingdomBackdrop.sunset => const Color(0xFF43241B),
  };
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color.alphaBlend(tint.withValues(alpha: 0.85), ink), ink],
  );
}

/// Decorative castle header drawn for the active child's chosen style.
class KingdomCastle extends StatelessWidget {
  /// Creates a castle painted in the child's saved application color.
  const KingdomCastle({
    required this.style,
    required this.color,
    this.height = 132,
    super.key,
  });

  /// Silhouette chosen by the parent for this child.
  final CastleStyle style;

  /// Child's saved kingdom color, used for the whole silhouette.
  final Color color;

  /// Painted height; the width always follows the available space.
  final double height;

  @override
  /// Paints the silhouette without any image asset or network request.
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _CastlePainter(style: style, color: color),
      ),
    );
  }
}

/// Child photo wrapped in the frame the parent chose for that child.
///
/// The face itself is the shared [HeroFace], so a kingdom avatar decodes the
/// stored photo, falls back, and reads an initial exactly as every other
/// surface does. This widget owns only what is its own: the painted frame.
class KingdomAvatar extends StatelessWidget {
  /// Creates a framed avatar around one child's face.
  const KingdomAvatar({
    required this.profile,
    required this.frame,
    this.radius = 42,
    super.key,
  });

  /// Child whose locally stored photo and colour the avatar is built from.
  final ChildProfile profile;

  /// Decoration drawn around the photo.
  final AvatarFrameStyle frame;

  /// Photo radius; the frame is painted in the ring just outside it.
  final double radius;

  /// Child's saved kingdom color, used for the frame decoration.
  Color get color => Color(profile.themeColorValue);

  @override
  /// Keeps the plain circle identical to the pre-personalization avatar.
  Widget build(BuildContext context) {
    final photo = HeroFace(profile: profile, size: radius * 2);
    if (frame == AvatarFrameStyle.none) return photo;
    final diameter = (radius + _frameInset) * 2;
    return SizedBox.square(
      dimension: diameter,
      child: CustomPaint(
        painter: _AvatarFramePainter(frame: frame, color: color),
        child: Center(child: photo),
      ),
    );
  }

  /// Space reserved around the photo for the painted frame.
  static const _frameInset = 12.0;
}

/// Paints one of the four castle silhouettes into the available box.
class _CastlePainter extends CustomPainter {
  /// Creates a painter for one style and one opaque child color.
  const _CastlePainter({required this.style, required this.color});

  final CastleStyle style;
  final Color color;

  @override
  /// Draws towers, domes, spires, or canopies over a shared ground line.
  void paint(Canvas canvas, Size size) {
    final body = Paint()..color = color.withValues(alpha: 0.72);
    final accent = Paint()..color = color;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 6, size.width, 6),
      Paint()..color = color.withValues(alpha: 0.4),
    );
    switch (style) {
      case CastleStyle.classicTowers:
        _paintClassicTowers(canvas, size, body, accent);
      case CastleStyle.roundDomes:
        _paintRoundDomes(canvas, size, body, accent);
      case CastleStyle.crystalSpires:
        _paintCrystalSpires(canvas, size, body, accent);
      case CastleStyle.forestTreehouse:
        _paintForestTreehouse(canvas, size, body, accent);
    }
  }

  /// Draws three square keeps finished with crenellated battlements.
  void _paintClassicTowers(Canvas canvas, Size size, Paint body, Paint accent) {
    final center = size.width / 2;
    final unit = size.height / 10;
    _tower(canvas, center - unit * 5, size, unit * 5, unit * 2.4, body, accent);
    _tower(
      canvas,
      center + unit * 2.6,
      size,
      unit * 5,
      unit * 2.4,
      body,
      accent,
    );
    _tower(
      canvas,
      center - unit * 1.8,
      size,
      unit * 7.4,
      unit * 3.6,
      body,
      accent,
    );
  }

  /// Draws one keep plus the merlons that make its roof line readable.
  void _tower(
    Canvas canvas,
    double left,
    Size size,
    double towerHeight,
    double width,
    Paint body,
    Paint accent,
  ) {
    final top = size.height - towerHeight;
    canvas.drawRect(Rect.fromLTWH(left, top, width, towerHeight - 6), body);
    final merlon = width / 5;
    for (var index = 0; index < 3; index++) {
      canvas.drawRect(
        Rect.fromLTWH(left + index * merlon * 2, top - merlon, merlon, merlon),
        accent,
      );
    }
  }

  /// Draws wide palace towers capped with rounded domes.
  void _paintRoundDomes(Canvas canvas, Size size, Paint body, Paint accent) {
    final center = size.width / 2;
    final unit = size.height / 10;
    for (final offset in <double>[-unit * 4.4, 0, unit * 4.4]) {
      final width = offset == 0 ? unit * 4 : unit * 3;
      final height = offset == 0 ? unit * 7 : unit * 5;
      final left = center + offset - width / 2;
      final top = size.height - height;
      canvas.drawRect(Rect.fromLTWH(left, top, width, height - 6), body);
      canvas.drawArc(
        Rect.fromLTWH(left, top - width / 2, width, width),
        math.pi,
        math.pi,
        true,
        accent,
      );
    }
  }

  /// Draws tall faceted spires that read as crystal even in one flat color.
  void _paintCrystalSpires(Canvas canvas, Size size, Paint body, Paint accent) {
    final center = size.width / 2;
    final unit = size.height / 10;
    for (final offset in <double>[-unit * 4.2, 0, unit * 4.2]) {
      final width = offset == 0 ? unit * 3.4 : unit * 2.4;
      final height = offset == 0 ? unit * 9 : unit * 6.4;
      final left = center + offset - width / 2;
      final base = size.height - 6;
      final spire = Path()
        ..moveTo(left + width / 2, base - height)
        ..lineTo(left + width, base - height * 0.42)
        ..lineTo(left + width * 0.78, base)
        ..lineTo(left + width * 0.22, base)
        ..lineTo(left, base - height * 0.42)
        ..close();
      canvas.drawPath(spire, offset == 0 ? accent : body);
    }
  }

  /// Draws a trunk, layered canopies, and the hut that sits between them.
  void _paintForestTreehouse(
    Canvas canvas,
    Size size,
    Paint body,
    Paint accent,
  ) {
    final center = size.width / 2;
    final unit = size.height / 10;
    final base = size.height - 6;
    canvas.drawRect(
      Rect.fromLTWH(center - unit * 0.7, base - unit * 4, unit * 1.4, unit * 4),
      accent,
    );
    for (var layer = 0; layer < 3; layer++) {
      final width = unit * (7 - layer * 1.4);
      final top = base - unit * (5 + layer * 1.7);
      final canopy = Path()
        ..moveTo(center, top - unit * 1.9)
        ..lineTo(center + width / 2, top)
        ..lineTo(center - width / 2, top)
        ..close();
      canvas.drawPath(canopy, body);
    }
    final hut = Rect.fromLTWH(
      center - unit * 2.2,
      base - unit * 5.6,
      unit * 4.4,
      unit * 2.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(hut, const Radius.circular(6)),
      accent,
    );
  }

  @override
  /// Repaints only when the parent picks a different style or color.
  bool shouldRepaint(_CastlePainter oldDelegate) {
    return oldDelegate.style != style || oldDelegate.color != color;
  }
}

/// Paints stars, hearts, or laurel leaves in the ring around a child photo.
class _AvatarFramePainter extends CustomPainter {
  /// Creates a painter for one frame style and one opaque child color.
  const _AvatarFramePainter({required this.frame, required this.color});

  final AvatarFrameStyle frame;
  final Color color;

  @override
  /// Places every decoration on a circle so the photo itself stays untouched.
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width / 2 - 6;
    final paint = Paint()..color = color;
    switch (frame) {
      case AvatarFrameStyle.none:
        return;
      case AvatarFrameStyle.stars:
        _scatter(canvas, center, ringRadius, 8, (offset) {
          _star(canvas, offset, 7, paint);
        });
      case AvatarFrameStyle.hearts:
        _scatter(canvas, center, ringRadius, 8, (offset) {
          _heart(canvas, offset, 7, paint);
        });
      case AvatarFrameStyle.laurel:
        _laurel(canvas, center, ringRadius, paint);
    }
  }

  /// Places [count] decorations evenly around the photo ring.
  void _scatter(
    Canvas canvas,
    Offset center,
    double radius,
    int count,
    ValueChanged<Offset> draw,
  ) {
    for (var index = 0; index < count; index++) {
      final angle = index * 2 * math.pi / count - math.pi / 2;
      draw(
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
      );
    }
  }

  /// Draws one five-pointed star centred on [center].
  void _star(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var point = 0; point < 10; point++) {
      final pointRadius = point.isEven ? radius : radius / 2.4;
      final angle = point * math.pi / 5 - math.pi / 2;
      final offset = Offset(
        center.dx + pointRadius * math.cos(angle),
        center.dy + pointRadius * math.sin(angle),
      );
      point == 0
          ? path.moveTo(offset.dx, offset.dy)
          : path.lineTo(offset.dx, offset.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  /// Draws one heart from two lobes and a point, centred on [center].
  void _heart(Canvas canvas, Offset center, double radius, Paint paint) {
    final lobe = radius / 2;
    canvas.drawCircle(center.translate(-lobe / 1.2, -lobe / 2), lobe, paint);
    canvas.drawCircle(center.translate(lobe / 1.2, -lobe / 2), lobe, paint);
    final point = Path()
      ..moveTo(center.dx - radius * 0.82, center.dy - lobe / 2)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx + radius * 0.82, center.dy - lobe / 2)
      ..close();
    canvas.drawPath(point, paint);
  }

  /// Draws mirrored laurel leaves along the left and right of the photo.
  void _laurel(Canvas canvas, Offset center, double radius, Paint paint) {
    for (final side in <double>[-1, 1]) {
      for (var leaf = 0; leaf < 5; leaf++) {
        final angle = (0.42 + leaf * 0.26) * math.pi;
        final position = Offset(
          center.dx + side * radius * math.sin(angle - math.pi / 2).abs(),
          center.dy - radius * math.cos(angle - math.pi / 2),
        );
        canvas.save();
        canvas.translate(position.dx, position.dy);
        canvas.rotate(side * (angle - math.pi / 2));
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 14, height: 6),
          paint,
        );
        canvas.restore();
      }
    }
  }

  @override
  /// Repaints only when the parent picks a different frame or color.
  bool shouldRepaint(_AvatarFramePainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.color != color;
  }
}
