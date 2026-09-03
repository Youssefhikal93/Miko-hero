// Rasterizes the one brand drawing, assets/brand/iam_hero_mark.svg, into the
// PNG masters that flutter_launcher_icons and flutter_native_splash slice into
// per-platform icons and splash screens.
//
//   flutter test tool/render_brand_assets.dart
//
// It is shaped as a test so it can borrow the Flutter test engine: that is the
// only headless rasterizer the toolchain already ships, so regenerating the
// brand needs no image editor and no machine-specific tool path. `flutter test`
// with no arguments only globs test/, so this never runs as part of the suite.
//
// The backdrop rectangle is taken out of the SVG and painted by this script
// instead, so the night background always bleeds to the edge of an icon
// whatever scale the mark itself is drawn at.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// The grid the mark is drawn on, i.e. the SVG's viewBox.
const double _grid = 1024;

const String _markPath = 'assets/brand/iam_hero_mark.svg';
const String _outputDirectory = 'assets/brand/generated';

/// Matches the backdrop rectangle and captures the night colour, which is
/// authored in the SVG and nowhere else in this script.
final RegExp _backdropPattern = RegExp(
  r'<rect\s+id="backdrop"[^>]*fill="#([0-9a-fA-F]{6})"[^>]*/>',
);

/// Matches the candle glow, which the themed Android icon leaves out.
final RegExp _glowPattern = RegExp(r'<circle\s+id="glow"[^>]*/>');

/// One PNG master. [markScale] shrinks the mark inside the canvas for the
/// targets whose platform crops or pads what it is given.
class _Master {
  const _Master({
    required this.fileName,
    required this.size,
    required this.markScale,
    required this.opaque,
    this.glow = true,
  });

  final String fileName;
  final int size;
  final double markScale;
  final bool opaque;
  final bool glow;
}

const List<_Master> _masters = <_Master>[
  // iOS AppIcon, legacy Android launcher, web favicon and PWA icons. The mark
  // is authored inside the maskable safe circle, so the web maskable icons can
  // be this same master resized.
  _Master(fileName: 'app_icon.png', size: 1024, markScale: 1, opaque: true),
  // Android adaptive foreground layer. Not shrunk here: the generator insets
  // the foreground by 16% itself, and the mark is already inside the safe
  // circle, so the two together clear the launcher's crop.
  _Master(
    fileName: 'app_icon_foreground.png',
    size: 1024,
    markScale: 1,
    opaque: false,
  ),
  // Android 13+ themed icon, where the system keeps only the alpha and tints
  // it, so the mark ships as a silhouette without its halo.
  _Master(
    fileName: 'app_icon_monochrome.png',
    size: 1024,
    markScale: 1,
    opaque: false,
    glow: false,
  ),
  // Pre-Android-12, iOS launch storyboard and web page splash, all of which
  // centre it on the night colour themselves.
  _Master(fileName: 'splash.png', size: 1024, markScale: 1, opaque: false),
  // Android 12+ splash icon: a 1152 px canvas whose art has to sit inside the
  // 768 px circle the system crops to.
  _Master(
    fileName: 'splash_android_12.png',
    size: 1152,
    markScale: 0.8,
    opaque: false,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('renders the brand PNG masters from the SVG mark', () async {
    final File markFile = File(_markPath);
    expect(
      markFile.existsSync(),
      isTrue,
      reason: 'the brand mark must live at $_markPath',
    );

    final String authored = markFile.readAsStringSync();
    final RegExpMatch? backdrop = _backdropPattern.firstMatch(authored);
    expect(
      backdrop,
      isNotNull,
      reason:
          'the mark must carry a <rect id="backdrop" ... fill="#RRGGBB"/>, '
          'which is where the night colour of every opaque icon comes from',
    );

    final ui.Color night = ui.Color(
      int.parse('FF${backdrop!.group(1)!}', radix: 16),
    );
    final String markOnly = authored.replaceFirst(backdrop.group(0)!, '');
    final String markWithoutGlow = markOnly.replaceFirst(_glowPattern, '');
    expect(
      markWithoutGlow,
      isNot(markOnly),
      reason:
          'the mark must carry a <circle id="glow" .../>, which the '
          'themed Android icon leaves out',
    );

    final Directory outputDirectory = Directory(_outputDirectory)
      ..createSync(recursive: true);

    for (final _Master master in _masters) {
      final Uint8List png = await _rasterize(
        master,
        master.glow ? markOnly : markWithoutGlow,
        night,
      );
      final File file = File('${outputDirectory.path}/${master.fileName}');
      file.writeAsBytesSync(png);
      stdout.writeln(
        'wrote ${file.path} (${master.size}x${master.size}, '
        'mark at ${(master.markScale * 100).round()}%)',
      );
      expect(png, isNotEmpty);
    }
  });
}

Future<Uint8List> _rasterize(
  _Master master,
  String markSvg,
  ui.Color night,
) async {
  final PictureInfo mark = await vg.loadPicture(SvgStringLoader(markSvg), null);
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);

  final double side = master.size.toDouble();
  if (master.opaque) {
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, side, side),
      ui.Paint()..color = night,
    );
  }

  canvas.translate(side / 2, side / 2);
  canvas.scale(side / _grid * master.markScale);
  canvas.translate(-_grid / 2, -_grid / 2);
  canvas.drawPicture(mark.picture);
  mark.picture.dispose();

  final ui.Image image = await recorder.endRecording().toImage(
    master.size,
    master.size,
  );
  final ByteData? png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return png!.buffer.asUint8List();
}
