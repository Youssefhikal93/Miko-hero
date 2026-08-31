import 'dart:math' as math;

import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:pdf/pdf.dart';

/// Draws one child's favourite kingdom symbol into a printed page.
///
/// Vector shapes rather than an icon font on purpose: the export must stay
/// fully offline and must not depend on Flutter's own bundled Material icon
/// file, which is an implementation detail of the framework and not part of
/// this app's asset bundle. The marks are deliberately simple — they print at
/// about 26 points on the dedication page — but each one is distinct, which is
/// the whole job: the child recognizes their own badge.
///
/// [size] is the box handed in by the PDF canvas; the mark is centred in it and
/// scaled to fit, and every coordinate is PDF-native (origin bottom left,
/// y growing upwards).
void paintKingdomSymbol(
  PdfGraphics canvas,
  PdfPoint size,
  KingdomSymbol symbol, {
  required PdfColor color,
  required PdfColor background,
}) {
  final edge = math.min(size.x, size.y);
  if (edge <= 0) {
    return;
  }
  final cx = size.x / 2;
  final cy = size.y / 2;
  final r = edge / 2;
  canvas.setFillColor(color);
  switch (symbol) {
    case KingdomSymbol.star:
      _star(canvas, cx, cy, r, points: 5, innerRatio: 0.44);
    case KingdomSymbol.sparkles:
      _star(canvas, cx + r * 0.28, cy + r * 0.3, r * 0.62, points: 4);
      _star(canvas, cx - r * 0.44, cy - r * 0.12, r * 0.42, points: 4);
      _star(canvas, cx + r * 0.16, cy - r * 0.62, r * 0.3, points: 4);
    case KingdomSymbol.crown:
      _crown(canvas, cx, cy, r);
    case KingdomSymbol.flower:
      _flower(canvas, cx, cy, r, background: background, color: color);
    case KingdomSymbol.football:
      _football(canvas, cx, cy, r, background: background, color: color);
    case KingdomSymbol.music:
      _music(canvas, cx, cy, r);
    case KingdomSymbol.book:
      _book(canvas, cx, cy, r, background: background, color: color);
    case KingdomSymbol.paw:
      _paw(canvas, cx, cy, r);
    case KingdomSymbol.rainbow:
      _rainbow(canvas, cx, cy, r, background: background, color: color);
    case KingdomSymbol.butterfly:
      _butterfly(canvas, cx, cy, r);
    case KingdomSymbol.rocket:
      _rocket(canvas, cx, cy, r, background: background, color: color);
    case KingdomSymbol.dragon:
      _dragon(canvas, cx, cy, r);
  }
}

/// Fills a regular star with [points] tips inscribed in radius [r].
void _star(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r, {
  required int points,
  double innerRatio = 0.4,
}) {
  final step = math.pi / points;
  canvas.moveTo(cx, cy + r);
  for (var index = 1; index < points * 2; index++) {
    final radius = index.isOdd ? r * innerRatio : r;
    final angle = math.pi / 2 + step * index;
    canvas.lineTo(cx + radius * math.cos(angle), cy + radius * math.sin(angle));
  }
  canvas.closePath();
  canvas.fillPath();
}

/// Fills a circle centred on [cx], [cy].
void _disc(PdfGraphics canvas, double cx, double cy, double r) {
  canvas.drawEllipse(cx, cy, r, r);
  canvas.fillPath();
}

/// Fills the upper half of a circle, used to build the rainbow's bands.
void _halfDisc(PdfGraphics canvas, double cx, double cy, double r) {
  const segments = 24;
  canvas.moveTo(cx + r, cy);
  for (var index = 1; index <= segments; index++) {
    final angle = math.pi * index / segments;
    canvas.lineTo(cx + r * math.cos(angle), cy + r * math.sin(angle));
  }
  canvas.closePath();
  canvas.fillPath();
}

/// Fills the polygon through [corners].
void _polygon(PdfGraphics canvas, List<PdfPoint> corners) {
  canvas.moveTo(corners.first.x, corners.first.y);
  for (final corner in corners.skip(1)) {
    canvas.lineTo(corner.x, corner.y);
  }
  canvas.closePath();
  canvas.fillPath();
}

/// A band of battlements over a solid base.
void _crown(PdfGraphics canvas, double cx, double cy, double r) {
  final left = cx - r * 0.82;
  final right = cx + r * 0.82;
  final base = cy - r * 0.62;
  final rim = cy - r * 0.14;
  final top = cy + r * 0.78;
  _polygon(canvas, <PdfPoint>[
    PdfPoint(left, base),
    PdfPoint(right, base),
    PdfPoint(right, rim),
    PdfPoint(left, rim),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(left, rim),
    PdfPoint(left + r * 0.4, rim),
    PdfPoint(left + r * 0.2, top),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.28, rim),
    PdfPoint(cx + r * 0.28, rim),
    PdfPoint(cx, top + r * 0.14),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(right - r * 0.4, rim),
    PdfPoint(right, rim),
    PdfPoint(right - r * 0.2, top),
  ]);
}

/// Six petals around a cut-out centre.
void _flower(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r, {
  required PdfColor background,
  required PdfColor color,
}) {
  for (var index = 0; index < 6; index++) {
    final angle = math.pi / 2 + index * math.pi / 3;
    _disc(
      canvas,
      cx + r * 0.52 * math.cos(angle),
      cy + r * 0.52 * math.sin(angle),
      r * 0.4,
    );
  }
  canvas.setFillColor(background);
  _disc(canvas, cx, cy, r * 0.3);
  canvas.setFillColor(color);
}

/// A ball with a light pentagon panel.
void _football(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r, {
  required PdfColor background,
  required PdfColor color,
}) {
  _disc(canvas, cx, cy, r * 0.92);
  canvas.setFillColor(background);
  final corners = <PdfPoint>[
    for (var index = 0; index < 5; index++)
      PdfPoint(
        cx + r * 0.44 * math.cos(math.pi / 2 + index * 2 * math.pi / 5),
        cy + r * 0.44 * math.sin(math.pi / 2 + index * 2 * math.pi / 5),
      ),
  ];
  _polygon(canvas, corners);
  canvas.setFillColor(color);
}

/// A quaver: note head, stem and flag.
void _music(PdfGraphics canvas, double cx, double cy, double r) {
  canvas.drawEllipse(cx - r * 0.22, cy - r * 0.52, r * 0.34, r * 0.26);
  canvas.fillPath();
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx + r * 0.08, cy - r * 0.52),
    PdfPoint(cx + r * 0.24, cy - r * 0.52),
    PdfPoint(cx + r * 0.24, cy + r * 0.86),
    PdfPoint(cx + r * 0.08, cy + r * 0.86),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx + r * 0.24, cy + r * 0.86),
    PdfPoint(cx + r * 0.82, cy + r * 0.56),
    PdfPoint(cx + r * 0.82, cy + r * 0.24),
    PdfPoint(cx + r * 0.24, cy + r * 0.54),
  ]);
}

/// An open book: two leaves meeting at a spine.
void _book(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r, {
  required PdfColor background,
  required PdfColor color,
}) {
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.9, cy + r * 0.5),
    PdfPoint(cx - r * 0.06, cy + r * 0.68),
    PdfPoint(cx - r * 0.06, cy - r * 0.66),
    PdfPoint(cx - r * 0.9, cy - r * 0.5),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx + r * 0.9, cy + r * 0.5),
    PdfPoint(cx + r * 0.06, cy + r * 0.68),
    PdfPoint(cx + r * 0.06, cy - r * 0.66),
    PdfPoint(cx + r * 0.9, cy - r * 0.5),
  ]);
  canvas.setFillColor(background);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.72, cy + r * 0.3),
    PdfPoint(cx - r * 0.2, cy + r * 0.42),
    PdfPoint(cx - r * 0.2, cy + r * 0.24),
    PdfPoint(cx - r * 0.72, cy + r * 0.12),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx + r * 0.72, cy + r * 0.3),
    PdfPoint(cx + r * 0.2, cy + r * 0.42),
    PdfPoint(cx + r * 0.2, cy + r * 0.24),
    PdfPoint(cx + r * 0.72, cy + r * 0.12),
  ]);
  canvas.setFillColor(color);
}

/// A pad with four toes.
void _paw(PdfGraphics canvas, double cx, double cy, double r) {
  canvas.drawEllipse(cx, cy - r * 0.34, r * 0.52, r * 0.42);
  canvas.fillPath();
  const offsets = <(double, double, double)>[
    (-0.66, 0.24, 0.26),
    (-0.24, 0.62, 0.24),
    (0.24, 0.62, 0.24),
    (0.66, 0.24, 0.26),
  ];
  for (final (dx, dy, size) in offsets) {
    _disc(canvas, cx + r * dx, cy + r * dy, r * size);
  }
}

/// Three arcs, drawn largest first with the page colour between them.
void _rainbow(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r, {
  required PdfColor background,
  required PdfColor color,
}) {
  final base = cy - r * 0.42;
  final radii = <double>[0.96, 0.74, 0.52, 0.3];
  for (var index = 0; index < radii.length; index++) {
    canvas.setFillColor(index.isEven ? color : background);
    _halfDisc(canvas, cx, base, r * radii[index]);
  }
  canvas.setFillColor(color);
}

/// Two pairs of wings around a slim body.
void _butterfly(PdfGraphics canvas, double cx, double cy, double r) {
  canvas.drawEllipse(cx - r * 0.44, cy + r * 0.34, r * 0.42, r * 0.5);
  canvas.fillPath();
  canvas.drawEllipse(cx + r * 0.44, cy + r * 0.34, r * 0.42, r * 0.5);
  canvas.fillPath();
  canvas.drawEllipse(cx - r * 0.36, cy - r * 0.42, r * 0.32, r * 0.38);
  canvas.fillPath();
  canvas.drawEllipse(cx + r * 0.36, cy - r * 0.42, r * 0.32, r * 0.38);
  canvas.fillPath();
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.09, cy + r * 0.82),
    PdfPoint(cx + r * 0.09, cy + r * 0.82),
    PdfPoint(cx + r * 0.06, cy - r * 0.86),
    PdfPoint(cx - r * 0.06, cy - r * 0.86),
  ]);
}

/// A capsule body with fins and a porthole.
void _rocket(
  PdfGraphics canvas,
  double cx,
  double cy,
  double r, {
  required PdfColor background,
  required PdfColor color,
}) {
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx, cy + r * 0.94),
    PdfPoint(cx + r * 0.34, cy + r * 0.2),
    PdfPoint(cx + r * 0.34, cy - r * 0.6),
    PdfPoint(cx - r * 0.34, cy - r * 0.6),
    PdfPoint(cx - r * 0.34, cy + r * 0.2),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.34, cy + r * 0.06),
    PdfPoint(cx - r * 0.34, cy - r * 0.6),
    PdfPoint(cx - r * 0.86, cy - r * 0.84),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx + r * 0.34, cy + r * 0.06),
    PdfPoint(cx + r * 0.34, cy - r * 0.6),
    PdfPoint(cx + r * 0.86, cy - r * 0.84),
  ]);
  canvas.setFillColor(background);
  _disc(canvas, cx, cy + r * 0.22, r * 0.2);
  canvas.setFillColor(color);
}

/// A friendly head with horns and one raised wing.
void _dragon(PdfGraphics canvas, double cx, double cy, double r) {
  canvas.drawEllipse(cx - r * 0.16, cy - r * 0.18, r * 0.5, r * 0.42);
  canvas.fillPath();
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.46, cy + r * 0.18),
    PdfPoint(cx - r * 0.18, cy + r * 0.22),
    PdfPoint(cx - r * 0.4, cy + r * 0.72),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.02, cy + r * 0.2),
    PdfPoint(cx + r * 0.24, cy + r * 0.12),
    PdfPoint(cx + r * 0.06, cy + r * 0.66),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx + r * 0.2, cy - r * 0.06),
    PdfPoint(cx + r * 0.94, cy + r * 0.5),
    PdfPoint(cx + r * 0.86, cy - r * 0.5),
  ]);
  _polygon(canvas, <PdfPoint>[
    PdfPoint(cx - r * 0.6, cy - r * 0.38),
    PdfPoint(cx - r * 0.1, cy - r * 0.5),
    PdfPoint(cx - r * 0.34, cy - r * 0.86),
  ]);
}
