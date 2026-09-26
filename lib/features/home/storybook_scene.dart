import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// An original, offline castle scene with a finite camera approach and scroll depth.
class StorybookScene extends StatefulWidget {
  /// The existing welcome controls remain above the decorative scene.
  const StorybookScene({required this.child, super.key});

  /// Localized welcome content and its existing action.
  final Widget child;

  @override
  State<StorybookScene> createState() => _StorybookSceneState();
}

class _StorybookSceneState extends State<StorybookScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _approach = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _approach.value = 1;
    } else {
      _approach.forward();
    }
  }

  @override
  void dispose() {
    _approach.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scroll = reduced ? null : Scrollable.maybeOf(context)?.position;
    final accent = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = !isWideReaderWidth(constraints.maxWidth);
        return ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              Positioned.fill(
                child: ExcludeSemantics(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _CastlePainter(
                        approach: _approach,
                        scroll: scroll,
                        accent: accent,
                        textDirection: Directionality.of(context),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(child: _readingScrim(compact)),
              _welcomeContent(compact),
            ],
          ),
        );
      },
    );
  }

  Widget _readingScrim(bool compact) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: compact
              ? Alignment.topCenter
              : (rtl ? Alignment.centerRight : Alignment.centerLeft),
          end: compact
              ? Alignment.bottomCenter
              : (rtl ? Alignment.centerLeft : Alignment.centerRight),
          colors: const [
            AppTheme.castleScrimDense,
            AppTheme.castleScrimSoft,
            AppTheme.castleScrimClear,
          ],
          stops: compact ? const [0, 0.48, 0.78] : const [0, 0.3, 0.74],
        ),
      ),
    );
  }

  Widget _welcomeContent(bool compact) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: compact ? 0 : 560),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          compact ? 24 : 40,
          compact ? 32 : 64,
          compact ? 24 : 40,
          compact ? 320 : 64,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 640 : 390),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _CastlePainter extends CustomPainter {
  _CastlePainter({
    required this.approach,
    required this.scroll,
    required this.accent,
    required this.textDirection,
  }) : super(repaint: Listenable.merge([approach, ?scroll]));

  final Animation<double> approach;
  final ScrollPosition? scroll;
  final Color accent;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final travel = ((scroll?.pixels ?? 0) / 600).clamp(0.0, 1.0);
    final opening = Curves.easeOutCubic.transform(approach.value);
    _sky(canvas, size, travel);
    final compact = !isWideReaderWidth(size.width);
    final scale = compact ? size.width / 610 : size.width / 1080;
    canvas.save();
    canvas.translate(
      size.width *
          (compact ? 0.5 : (textDirection == TextDirection.rtl ? 0.27 : 0.73)),
      compact ? size.height - 142 : size.height * 0.62,
    );
    canvas.scale(scale);
    canvas.save();
    canvas.scale(0.92 + opening * 0.08 + travel * 0.05);
    _mountains(canvas, travel);
    _moon(canvas, travel);
    canvas.restore();
    canvas.scale(0.62 + opening * 0.38 + travel * 0.55);
    canvas.translate(0, travel * 24);
    _bridge(canvas);
    _gatehouse(canvas);
    _lanterns(canvas, approach.value);
    _mist(canvas, approach.value, travel);
    canvas.restore();
    _vignette(canvas, size);
  }

  void _sky(Canvas canvas, Size size, double travel) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.castleSkyTop,
            AppTheme.castleHorizon,
            AppTheme.castleSkyBottom,
          ],
        ).createShader(bounds),
    );
    for (var star = 0; star < 58; star++) {
      final x = ((star * 137.508) % 997) / 997 * size.width;
      final y = ((star * 79.3) % 431) / 431 * size.height * 0.66 - travel * 5;
      canvas.drawCircle(
        Offset(x, y),
        star % 7 == 0 ? 1.3 : 0.65,
        Paint()
          ..color = AppTheme.castleStar.withValues(
            alpha: star % 3 == 0 ? 0.6 : 0.25,
          ),
      );
    }
  }

  void _mountains(Canvas canvas, double travel) {
    canvas.save();
    canvas.translate(0, -travel * 15);
    final ridge = Path()
      ..moveTo(-700, 200)
      ..lineTo(-700, -30)
      ..lineTo(-490, -140)
      ..lineTo(-355, -80)
      ..lineTo(-240, -155)
      ..lineTo(-80, -60)
      ..lineTo(100, -175)
      ..lineTo(270, -88)
      ..lineTo(390, -190)
      ..lineTo(590, -55)
      ..lineTo(700, -130)
      ..lineTo(700, 200)
      ..close();
    canvas.drawPath(ridge, Paint()..color = AppTheme.castleMountain);
    canvas.restore();
  }

  void _moon(Canvas canvas, double travel) {
    final center = Offset(147, -218 - travel * 8);
    canvas.drawCircle(
      center,
      105,
      Paint()
        ..shader = const RadialGradient(
          colors: [AppTheme.castleMoonHalo, AppTheme.castleMoonHaloClear],
        ).createShader(Rect.fromCircle(center: center, radius: 105)),
    );
    canvas.drawCircle(center, 49, Paint()..color = AppTheme.castleMoon);
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: 49)),
    );
    for (var crater = 0; crater < 11; crater++) {
      canvas.drawCircle(
        center +
            Offset(math.sin(crater * 2.4) * 35, math.cos(crater * 1.7) * 34),
        5 + (crater % 3) * 4,
        Paint()..color = AppTheme.castleMoonCrater,
      );
    }
    canvas.restore();
  }

  void _bridge(Canvas canvas) {
    final path = Path()
      ..moveTo(-47, 35)
      ..lineTo(47, 35)
      ..lineTo(205, 330)
      ..lineTo(-205, 330)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.castleBridgeFar, AppTheme.castleBridgeNear],
        ).createShader(const Rect.fromLTWH(-205, 35, 410, 295)),
    );
    final rail = Paint()
      ..color = AppTheme.castleBridgeRail
      ..strokeWidth = 5;
    canvas.drawLine(const Offset(-50, 35), const Offset(-215, 330), rail);
    canvas.drawLine(const Offset(50, 35), const Offset(215, 330), rail);
    for (var step = 1; step < 13; step++) {
      final depth = step / 12;
      final y = 35 + math.pow(depth, 1.7).toDouble() * 295;
      final width = 47 + (y - 35) / 295 * 158;
      canvas.drawLine(
        Offset(-width, y),
        Offset(width, y),
        Paint()
          ..color = AppTheme.castleBridgeJoint
          ..strokeWidth = 1,
      );
    }
  }

  void _gatehouse(Canvas canvas) {
    _stoneWall(canvas, const Rect.fromLTWH(-238, -82, 476, 128));
    _battlements(canvas, const Rect.fromLTWH(-238, -98, 476, 16));
    _stoneWall(canvas, const Rect.fromLTWH(-113, -171, 226, 218));
    _battlements(canvas, const Rect.fromLTWH(-113, -190, 226, 19));
    _tower(canvas, -166);
    _tower(canvas, 98);
    _gateway(canvas);
    for (final x in [-77.0, 65.0]) {
      _window(canvas, Offset(x, -139));
      _window(canvas, Offset(x, -54));
    }
  }

  void _stoneWall(Canvas canvas, Rect wall) {
    canvas.drawRect(
      wall,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            AppTheme.castleStoneLeft,
            AppTheme.castleStoneFace,
            AppTheme.castleStoneRight,
          ],
        ).createShader(wall),
    );
    canvas.save();
    canvas.clipRect(wall);
    final mortar = Paint()
      ..color = AppTheme.castleMortar
      ..strokeWidth = 1.5;
    for (var row = 0; row < (wall.height / 14).ceil(); row++) {
      final y = wall.top + row * 14;
      canvas.drawLine(Offset(wall.left, y), Offset(wall.right, y), mortar);
      for (var col = -1; col < (wall.width / 29).ceil(); col++) {
        final x = wall.left + col * 29 + (row.isEven ? 0 : 14);
        canvas.drawLine(Offset(x, y), Offset(x, y + 14), mortar);
        if ((row + col) % 4 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(x + 2, y + 2, 25, 10),
            Paint()..color = AppTheme.castleStoneHighlight,
          );
        }
      }
    }
    canvas.restore();
  }

  void _tower(Canvas canvas, double left) {
    final wall = Rect.fromLTWH(left, -216, 68, 270);
    _stoneWall(canvas, wall);
    canvas.drawRect(
      wall,
      Paint()
        ..shader = const LinearGradient(
          colors: [
            AppTheme.castleTowerShadow,
            AppTheme.castleTowerClear,
            AppTheme.castleTowerShade,
          ],
          stops: [0, 0.45, 1],
        ).createShader(wall),
    );
    _battlements(canvas, Rect.fromLTWH(left - 4, -234, 76, 23));
    _window(canvas, Offset(left + 27, -165));
    _window(canvas, Offset(left + 27, -75));
    canvas.drawRect(
      Rect.fromLTWH(left - 3, -19, 74, 6),
      Paint()..color = AppTheme.castleTowerLedge,
    );
  }

  void _battlements(Canvas canvas, Rect top) {
    canvas.drawRect(
      Rect.fromLTWH(top.left, top.bottom - 5, top.width, 5),
      Paint()..color = AppTheme.castleParapet,
    );
    for (double x = top.left; x < top.right - 9; x += 24) {
      canvas.drawRect(
        Rect.fromLTWH(x, top.top, 14, top.height),
        Paint()..color = AppTheme.castleBattlement,
      );
      canvas.drawLine(
        Offset(x, top.top),
        Offset(x + 14, top.top),
        Paint()
          ..color = AppTheme.castleParapetHighlight
          ..strokeWidth = 1,
      );
    }
  }

  Path _arch(Rect bounds) => Path()
    ..moveTo(bounds.left, bounds.bottom)
    ..lineTo(bounds.left, bounds.top + bounds.height * 0.42)
    ..quadraticBezierTo(
      bounds.left,
      bounds.top + 10,
      bounds.center.dx,
      bounds.top,
    )
    ..quadraticBezierTo(
      bounds.right,
      bounds.top + 10,
      bounds.right,
      bounds.top + bounds.height * 0.42,
    )
    ..lineTo(bounds.right, bounds.bottom)
    ..close();

  void _gateway(Canvas canvas) {
    final arch = _arch(const Rect.fromLTWH(-50, -118, 100, 166));
    canvas.drawPath(arch, Paint()..color = AppTheme.castleArchShadow);
    canvas.drawPath(
      arch,
      Paint()
        ..color = AppTheme.castleArchRim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9,
    );
    canvas.save();
    canvas.clipPath(arch);
    canvas.drawRect(
      const Rect.fromLTWH(-50, -118, 100, 166),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, 0.9),
          radius: 1.3,
          colors: [
            accent.withValues(alpha: 0.9),
            AppTheme.castleGateWarm,
            AppTheme.castleGateDark,
          ],
        ).createShader(const Rect.fromLTWH(-50, -118, 100, 166)),
    );
    for (var bar = -4; bar <= 4; bar++) {
      canvas.drawLine(
        Offset(bar * 11.0, -118),
        Offset(bar * 11.0, -64),
        Paint()
          ..color = AppTheme.castlePortcullis
          ..strokeWidth = 3,
      );
    }
    canvas.drawLine(
      const Offset(-50, -82),
      const Offset(50, -82),
      Paint()
        ..color = AppTheme.castlePortcullis
        ..strokeWidth = 4,
    );
    canvas.restore();
  }

  void _window(Canvas canvas, Offset origin) {
    canvas.drawRect(
      origin & const Size(12, 36),
      Paint()..color = AppTheme.castleWindowShadow,
    );
    canvas.drawRect(
      (origin + const Offset(3, 3)) & const Size(6, 30),
      Paint()..color = Color.lerp(accent, AppTheme.castleWindowLight, 0.45)!,
    );
  }

  void _lanterns(Canvas canvas, double opening) {
    for (final position in [
      const Offset(-71, 4),
      const Offset(71, 4),
      const Offset(-127, 174),
      const Offset(127, 174),
    ]) {
      canvas.drawLine(
        position,
        position + const Offset(0, 33),
        Paint()
          ..color = AppTheme.castleTorchStand
          ..strokeWidth = 5,
      );
      final flicker =
          math.sin(opening * math.pi * 15 + position.dx) * (1 - opening);
      final glow = Rect.fromCircle(center: position, radius: 43 + flicker * 3);
      canvas.drawOval(
        glow,
        Paint()
          ..shader = RadialGradient(
            colors: [
              accent.withValues(alpha: 0.42),
              accent.withValues(alpha: 0),
            ],
          ).createShader(glow),
      );
      final flame = Path()
        ..moveTo(position.dx - 5, position.dy)
        ..quadraticBezierTo(
          position.dx - 4,
          position.dy - 8,
          position.dx + flicker * 2,
          position.dy - 16,
        )
        ..quadraticBezierTo(
          position.dx + 8,
          position.dy - 3,
          position.dx + 5,
          position.dy,
        )
        ..close();
      canvas.drawPath(flame, Paint()..color = AppTheme.castleFlame);
    }
  }

  void _mist(Canvas canvas, double opening, double travel) {
    for (var layer = 0; layer < 3; layer++) {
      final center = Offset(
        -180 + layer * 200 + opening * 35 - travel * 55,
        72 + layer * 48.0,
      );
      final cloud = Rect.fromCenter(center: center, width: 700, height: 80);
      canvas.drawOval(
        cloud,
        Paint()
          ..shader = const RadialGradient(
            colors: [AppTheme.castleMist, AppTheme.castleMistClear],
          ).createShader(cloud),
      );
    }
  }

  void _vignette(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.9,
          colors: [AppTheme.castleVignetteClear, AppTheme.castleVignette],
          stops: [0.35, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_CastlePainter oldDelegate) =>
      oldDelegate.textDirection != textDirection ||
      oldDelegate.accent != accent ||
      oldDelegate.approach != approach ||
      oldDelegate.scroll != scroll;
}
