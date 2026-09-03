import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Verifies the shape of the grid every redesigned screen is laid out on.
///
/// The numbers a phone actually has are used on purpose: 360 px is the
/// narrowest phone the app supports, and 900 px is the width the navigation
/// shell already treats as a desktop window.
void main() {
  const gap = 12.0;

  testWidgets('a 360 px phone gets two columns', (tester) async {
    await _pumpGrid(tester, width: 360);

    const columnWidth = (360 - gap) / 2;
    expect(_rectOf(tester, 'tile-0').width, 360);
    expect(_rectOf(tester, 'tile-1').width, columnWidth);
    expect(_rectOf(tester, 'tile-2').width, columnWidth);

    // Two tiles share the first full row and the third one starts the next.
    expect(_rectOf(tester, 'tile-2').top, _rectOf(tester, 'tile-1').top);
    expect(
      _rectOf(tester, 'tile-2').left,
      _rectOf(tester, 'tile-1').right + gap,
    );
    expect(
      _rectOf(tester, 'tile-3').top,
      greaterThan(_rectOf(tester, 'tile-1').top),
    );
    expect(_rectOf(tester, 'tile-2').right, lessThanOrEqualTo(360));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the desktop breakpoint gets at least three columns', (
    tester,
  ) async {
    await _pumpGrid(tester, width: desktopBreakpoint);

    const columnWidth = (desktopBreakpoint - 2 * gap) / 3;
    final first = _rectOf(tester, 'tile-2');
    final second = _rectOf(tester, 'tile-3');
    final third = _rectOf(tester, 'tile-4');

    expect(first.width, columnWidth);
    expect(second.top, first.top);
    expect(third.top, first.top);
    expect(second.left, greaterThan(first.left));
    expect(third.left, greaterThan(second.left));
    expect(third.right, lessThanOrEqualTo(desktopBreakpoint));

    // The two-column tile still covers exactly two of the three columns.
    expect(_rectOf(tester, 'tile-0').width, 2 * columnWidth + gap);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tile never asks for more columns than the grid has', (
    tester,
  ) async {
    await _pumpGrid(tester, width: 360, spans: <int>[3, 1, 1, 1, 1]);

    expect(_rectOf(tester, 'tile-0').width, 360);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the grid scrolls inside the page scroll view', (tester) async {
    await _pumpGrid(tester, width: 360, height: 220);
    final before = _rectOf(tester, 'tile-1').top;

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -80));
    await tester.pump();

    expect(_rectOf(tester, 'tile-1').top, lessThan(before));
    expect(tester.takeException(), isNull);
  });
}

/// Places one mosaic of five tiles in a viewport of the requested width.
Future<void> _pumpGrid(
  WidgetTester tester, {
  required double width,
  double height = 900,
  List<int> spans = const <int>[2, 1, 1, 1, 1],
}) async {
  await tester.binding.setSurfaceSize(Size(width, height));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: height,
          child: SingleChildScrollView(
            child: MosaicGrid(
              tiles: <MosaicTile>[
                for (var index = 0; index < spans.length; index++)
                  MosaicTile(
                    span: spans[index],
                    child: SizedBox(
                      key: ValueKey<String>('tile-$index'),
                      height: 120,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Reads where one keyed tile ended up on screen.
Rect _rectOf(WidgetTester tester, String key) {
  return tester.getRect(find.byKey(ValueKey<String>(key)));
}
