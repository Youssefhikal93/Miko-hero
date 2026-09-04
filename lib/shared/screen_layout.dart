import 'package:flutter/material.dart';
import 'package:miko_hero/app/app_theme.dart';

/// Constrains feature content while retaining comfortable phone padding.
class ScreenLayout extends StatelessWidget {
  /// Creates a scrollable screen with an optional narrower content width.
  const ScreenLayout({
    required this.child,
    this.maxWidth = 1160,
    this.backgroundGradient,
    super.key,
  });

  /// Feature content rendered inside the responsive constraint.
  final Widget child;

  /// Largest content width before centered gutters grow.
  final double maxWidth;

  /// Optional per-page backdrop replacing the shared ambient gradient.
  ///
  /// Used by My Kingdom for the active child's chosen flavor; every accepted
  /// gradient must stay dark enough for the shared light-on-dark text.
  final Gradient? backgroundGradient;

  @override
  /// Adds safe-area spacing and a subtle ambient background gradient.
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: backgroundGradient ?? _ambientGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  /// Shared ambient wash used by every page without its own backdrop.
  static const _ambientGradient = RadialGradient(
    center: Alignment(0.8, -0.9),
    radius: 1.2,
    colors: <Color>[AppTheme.ambientGlow, AppTheme.night],
  );
}

/// Width from which the application lays itself out for a desktop window.
///
/// The navigation shell swaps its bottom bar for the extended rail here, so
/// the mosaic widens at exactly the same point and a screen never changes
/// shape twice while a window is being resized.
const double desktopBreakpoint = 900;

/// Width from which a reading surface has room for two columns side by side.
///
/// The reader puts its picture beside its prose from here up, and the review
/// queue puts two draft cards on a row. Deliberately below [desktopBreakpoint]:
/// a landscape phone is already wide enough for a spread while its navigation
/// still belongs at the bottom of the screen.
const double wideReaderBreakpoint = 760;

/// Whether [width] belongs to a desktop window rather than a phone-shaped one.
bool isDesktopWidth(double width) => width >= desktopBreakpoint;

/// Whether [width] has room for a picture beside its prose.
bool isWideReaderWidth(double width) => width >= wideReaderBreakpoint;

/// Columns a [MosaicGrid] resolves for the [width] it was handed.
int mosaicColumnsFor(double width) => isDesktopWidth(width) ? 3 : 2;

/// Builds the tiles of a mosaic that has already resolved [columns] columns.
typedef MosaicTileBuilder = List<MosaicTile> Function(int columns);

/// One tile inside a [MosaicGrid].
class MosaicTile {
  /// Creates a tile covering [span] of the grid's columns.
  const MosaicTile({required this.child, this.span = 1});

  /// Tile content, which keeps deciding its own height.
  final Widget child;

  /// Columns the tile covers: one for a half tile, two for a full-width one.
  ///
  /// A span wider than the grid is narrowed to the grid, so a two-column tile
  /// simply fills the row of a two-column phone.
  final int span;
}

/// Mosaic of differently sized tiles shared by every redesigned screen.
///
/// Two columns on a phone and three from [desktopBreakpoint] up. Tiles are
/// placed in order, left to right, and a tile that no longer fits the row it
/// is offered starts the next one. Row widths always add up to the available
/// width, so nothing overflows horizontally. The grid scrolls nothing itself
/// and stays as tall as its tiles, which is what lets it sit inside the page
/// scroll view every feature already has.
///
/// A screen whose tile shapes depend on how wide the mosaic turned out uses
/// [MosaicGrid.builder] and is handed the resolved column count, rather than
/// measuring the width a second time and risking a different answer.
class MosaicGrid extends StatelessWidget {
  /// Creates a mosaic of fixed tiles separated by one consistent [gap].
  const MosaicGrid({required List<MosaicTile> tiles, this.gap = 12, super.key})
    : _fixedTiles = tiles,
      _tileBuilder = null;

  /// Creates a mosaic whose [tiles] are chosen from the resolved column count.
  const MosaicGrid.builder({
    required MosaicTileBuilder tiles,
    this.gap = 12,
    super.key,
  }) : _tileBuilder = tiles,
       _fixedTiles = null;

  /// Tiles in display order, for a mosaic whose shapes never change.
  final List<MosaicTile>? _fixedTiles;

  /// Source of the tiles, for a mosaic whose shapes follow the column count.
  final MosaicTileBuilder? _tileBuilder;

  /// Space between two columns and between two rows.
  final double gap;

  @override
  /// Resolves the column count for the real width the feature has to spend.
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = mosaicColumnsFor(constraints.maxWidth);
        final tiles = _fixedTiles ?? _tileBuilder!(columns);
        if (tiles.isEmpty) return const SizedBox.shrink();
        final columnWidth =
            (constraints.maxWidth - (columns - 1) * gap) / columns;
        final rows = _rows(tiles, columns);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var index = 0; index < rows.length; index++) ...<Widget>[
              if (index > 0) SizedBox(height: gap),
              _row(rows[index], columns, columnWidth),
            ],
          ],
        );
      },
    );
  }

  /// Groups [tiles] into rows that never ask for more than [columns] columns.
  List<List<MosaicTile>> _rows(List<MosaicTile> tiles, int columns) {
    final rows = <List<MosaicTile>>[];
    var row = <MosaicTile>[];
    var used = 0;
    for (final tile in tiles) {
      final span = _spanOf(tile, columns);
      if (used + span > columns) {
        rows.add(row);
        row = <MosaicTile>[];
        used = 0;
      }
      row.add(tile);
      used += span;
    }
    if (row.isNotEmpty) rows.add(row);
    return rows;
  }

  /// Lays one row out, leaving unused columns of a short row empty.
  Widget _row(List<MosaicTile> row, int columns, double columnWidth) {
    final segments = <_MosaicSegment>[];
    var used = 0;
    for (final tile in row) {
      final span = _spanOf(tile, columns);
      if (segments.isNotEmpty) segments.add(_MosaicSegment(width: gap));
      segments.add(
        _MosaicSegment(width: _widthOf(span, columnWidth), child: tile.child),
      );
      used += span;
    }
    if (used < columns) {
      segments
        ..add(_MosaicSegment(width: gap))
        ..add(_MosaicSegment(width: _widthOf(columns - used, columnWidth)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < segments.length; index++)
          // The closing segment takes whatever the column division rounded
          // away, so a full row can never be a fraction of a pixel too wide.
          if (index == segments.length - 1)
            Expanded(child: segments[index].child ?? const SizedBox.shrink())
          else
            SizedBox(
              width: segments[index].width,
              child: segments[index].child,
            ),
      ],
    );
  }

  /// Width of [span] columns including the gaps the span covers.
  double _widthOf(int span, double columnWidth) {
    return span * columnWidth + (span - 1) * gap;
  }

  /// Columns one tile may cover in a grid of [columns].
  int _spanOf(MosaicTile tile, int columns) => tile.span.clamp(1, columns);
}

/// One horizontal slice of a mosaic row: a tile, a gap, or an empty column.
class _MosaicSegment {
  /// Creates a slice of the given width, empty unless a tile fills it.
  const _MosaicSegment({required this.width, this.child});

  /// Width the slice occupies in the row.
  final double width;

  /// Tile drawn in the slice, absent for gaps and unused columns.
  final Widget? child;
}

/// Reusable tile reserved for hero-level content.
class AccentPanel extends StatelessWidget {
  /// Creates a highlighted panel around the supplied content.
  const AccentPanel({required this.child, super.key});

  /// Content displayed on the tile surface.
  final Widget child;

  @override
  /// Renders a flat tile ringed by the active child's accent.
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppTheme.tile,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: child,
    );
  }
}

/// Consistent feature heading with optional supporting text.
class SectionHeading extends StatelessWidget {
  /// Creates a heading whose subtitle may be omitted when no context is needed.
  const SectionHeading({required this.title, this.subtitle, super.key});

  /// Main section label.
  final String title;

  /// Optional explanatory sentence.
  final String? subtitle;

  @override
  /// Renders title and subtitle using the current localized text direction.
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppTheme.muted),
          ),
        ],
      ],
    );
  }
}
