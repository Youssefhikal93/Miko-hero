import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/miko_hero_app.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies localized application behavior from the user's point of view.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appRouter.go('/');
  });

  testWidgets('first launch offers private profile setup', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MikoHeroApp()));
    await tester.pumpAndSettle();

    expect(find.text('A new adventure starts here'), findsOneWidget);
    expect(find.text('Set up profile'), findsWidgets);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('Arabic interface applies right-to-left direction', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ar',
    });

    await tester.pumpWidget(const ProviderScope(child: MikoHeroApp()));
    await tester.pumpAndSettle();

    final welcome = find.text('مغامرة جديدة تبدأ هنا');
    expect(welcome, findsOneWidget);
    expect(Directionality.of(tester.element(welcome)), TextDirection.rtl);
  });

  testWidgets('valid request creates a persisted book and opens its reader', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'daughter_profile': jsonEncode(<String, Object>{
        'name': 'Miko',
        'age': 7,
        'photoBase64': _transparentPixel,
      }),
    });
    final fixedTime = DateTime.utc(2026, 8, 17, 12);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          storyGeneratorProvider.overrideWithValue(
            DemoStoryGenerator(
              latency: Duration.zero,
              currentTime: () => fixedTime,
            ),
          ),
        ],
        child: const MikoHeroApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create another story'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'a moon garden');
    await tester.enterText(find.byType(TextFormField).at(1), 'kindness');
    final generateButton = find.text('Generate demo story');
    await tester.ensureVisible(generateButton);
    await tester.pumpAndSettle();
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 6'), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('story_library'), isTrue);
    ScaffoldMessenger.of(
      tester.element(find.byType(Scaffold).first),
    ).hideCurrentSnackBar();
    await tester.pumpAndSettle();
  });
}

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
