import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/hero_face.dart';

/// A one-pixel PNG, small enough to decode inside a widget test.
const _pngPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

/// Verifies that one widget draws every hero face, however the photo went bad.
void main() {
  testWidgets('a hero with no photo is named by their initial', (tester) async {
    await _pumpFace(tester, _profile(name: 'Miko', photoBase64: ''));

    expect(find.text('M'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hero with a saved photo shows the photo', (tester) async {
    await _pumpFace(tester, _profile(name: 'Miko', photoBase64: _pngPixel));

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('M'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('base64 that cannot be decoded falls back without throwing', (
    tester,
  ) async {
    await _pumpFace(
      tester,
      _profile(name: 'Miko', photoBase64: 'not base64 at all!!'),
    );

    expect(find.text('M'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bytes that are not an image fall back through errorBuilder', (
    tester,
  ) async {
    // Valid base64 carrying three bytes no decoder will recognize.
    await _pumpFace(tester, _profile(name: 'Miko', photoBase64: 'AAEC'));
    await tester.pumpAndSettle();

    expect(find.text('M'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a name outside the basic plane keeps its whole first glyph', (
    tester,
  ) async {
    await _pumpFace(tester, _profile(name: '🦕 Miko', photoBase64: ''));

    expect(find.text('🦕'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hero with no name at all still draws a face', (tester) async {
    await _pumpFace(tester, _profile(name: '   ', photoBase64: ''));

    expect(find.text('·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a surface can ask for a glyph instead of an initial', (
    tester,
  ) async {
    await _pumpFace(
      tester,
      _profile(name: 'Miko', photoBase64: ''),
      fallbackIcon: AppIcons.hero,
    );

    expect(find.byIcon(AppIcons.hero), findsOneWidget);
    expect(find.text('M'), findsNothing);
  });

  testWidgets('the ring is drawn only where a surface asked for one', (
    tester,
  ) async {
    final profile = _profile(name: 'Miko', photoBase64: '');

    await _pumpFace(tester, profile);
    expect(_ringSize(tester), isNull, reason: 'an unringed face wears no ring');

    await _pumpFace(tester, profile, ring: true);
    expect(
      _ringSize(tester),
      const Size(52, 52),
      reason: '44, plus a ring and its breathing room on each side',
    );
  });

  testWidgets('a face with no hero at all is still safe to draw', (
    tester,
  ) async {
    await _pumpFace(tester, null);

    expect(find.text('·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Places one face on a plain themed surface at its natural size.
Future<void> _pumpFace(
  WidgetTester tester,
  ChildProfile? profile, {
  bool ring = false,
  IconData? fallbackIcon,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: HeroFace(
            profile: profile,
            size: 44,
            ring: ring,
            fallbackIcon: fallbackIcon,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Measures the ring around the face, or null when the face wears none.
Size? _ringSize(WidgetTester tester) {
  final ring = find.descendant(
    of: find.byType(HeroFace),
    matching: find.byType(Container),
  );
  if (ring.evaluate().isEmpty) return null;
  return tester.getSize(ring.first);
}

/// Builds one profile carrying exactly the name and photo under test.
ChildProfile _profile({required String name, required String photoBase64}) {
  return ChildProfile(
    id: 'miko',
    name: name,
    legacyAge: 7,
    photoBase64: photoBase64,
    gender: ChildGender.girl,
    themeColorValue: roseProfileThemeColorValue,
    hasCustomThemeColor: false,
  );
}
