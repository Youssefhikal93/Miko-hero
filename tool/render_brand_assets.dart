// Builds platform-sized masters from the transparent 3D mascot.
// Run with: flutter test tool/render_brand_assets.dart
// The Flutter test engine supplies a headless image renderer; this file is
// outside test/ so ordinary test runs never rewrite the brand assets.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_theme.dart';

const _source = 'assets/brand/hero_mascot.png';
const _output = 'assets/brand/generated';

enum _Finish { opaque, transparent, silhouette }

class _Master {
  const _Master(this.name, this.size, this.scale, this.finish);

  final String name;
  final int size;
  final double scale;
  final _Finish finish;
}

const _masters = [
  _Master('app_icon.png', 1024, 0.88, _Finish.opaque),
  _Master('favicon.png', 64, 0.88, _Finish.opaque),
  // The launcher generator adds its own 16% adaptive foreground inset.
  _Master('app_icon_foreground.png', 1024, 0.78, _Finish.transparent),
  _Master('app_icon_monochrome.png', 1024, 0.78, _Finish.silhouette),
  _Master('brand_logo.png', 128, 1, _Finish.transparent),
  _Master('splash.png', 1024, 0.92, _Finish.transparent),
  // Keep the whole mascot within the platform's central safe circle.
  _Master('splash_android_12.png', 1152, 0.56, _Finish.transparent),
  _Master('Icon-maskable-192.png', 192, 0.64, _Finish.opaque),
  _Master('Icon-maskable-512.png', 512, 0.64, _Finish.opaque),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('renders the mascot into platform brand masters', () async {
    final codec = await ui.instantiateImageCodec(
      File(_source).readAsBytesSync(),
    );
    final mascot = (await codec.getNextFrame()).image;
    codec.dispose();
    Directory(_output).createSync(recursive: true);
    try {
      for (final master in _masters) {
        await _render(mascot, master);
      }
    } finally {
      mascot.dispose();
    }
  });
}

Future<void> _render(ui.Image mascot, _Master master) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final side = master.size.toDouble();
  if (master.finish == _Finish.opaque) {
    canvas.drawColor(AppTheme.night, ui.BlendMode.src);
  }
  final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
  if (master.finish == _Finish.silhouette) {
    paint.colorFilter = const ui.ColorFilter.mode(
      AppTheme.light,
      ui.BlendMode.srcIn,
    );
  }
  canvas.drawImageRect(
    mascot,
    ui.Rect.fromLTWH(0, 0, mascot.width.toDouble(), mascot.height.toDouble()),
    ui.Rect.fromCenter(
      center: ui.Offset(side / 2, side / 2),
      width: side * master.scale,
      height: side * master.scale,
    ),
    paint,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(master.size, master.size);
  picture.dispose();
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  File('$_output/${master.name}').writeAsBytesSync(png!.buffer.asUint8List());
  stdout.writeln('Rendered ${master.name}: ${master.size}px');
}
