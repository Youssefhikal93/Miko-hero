import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verifies localized application behavior from the user's point of view.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    appRouter.go('/');
  });

  testWidgets('first launch offers the first private child profile', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    expect(find.text('Iam - hero'), findsOneWidget);
    expect(find.text('Add a profile'), findsWidgets);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('Arabic interface applies right-to-left direction', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ar',
    });

    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    final welcome = find.text('مغامرة جديدة تبدأ هنا');
    expect(welcome, findsOneWidget);
    expect(Directionality.of(tester.element(welcome)), TextDirection.rtl);
  });

  testWidgets('selected child receives the story and a separate library tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'child_profiles': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'miko',
          'name': 'Miko',
          'age': 7,
          'photoBase64': _transparentPixel,
          'gender': 'girl',
        },
        <String, Object>{
          'id': 'abbas',
          'name': 'Abbas',
          'age': 9,
          'photoBase64': _transparentPixel,
        },
      ]),
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
        child: const IamHeroApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create another story'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a hero profile'), findsOneWidget);
    final profileSelector = find.byKey(
      const ValueKey<String>('story-profile-selector'),
    );
    await tester.ensureVisible(profileSelector);
    await tester.tap(profileSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbas hero').last);
    await tester.pumpAndSettle();
    expect(find.text('Is this hero a girl or a boy?'), findsOneWidget);
    await tester.tap(find.text('Boy'));
    await tester.pumpAndSettle();
    final storyTitle = find.text('Create a story');
    expect(
      Theme.of(tester.element(storyTitle)).colorScheme.primary,
      AppTheme.boyCyan,
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'a moon garden');
    await tester.enterText(find.byType(TextFormField).at(1), 'kindness');
    final generateButton = find.text('Generate demo story');
    await tester.ensureVisible(generateButton);
    await tester.tap(generateButton);
    await tester.pumpAndSettle();

    expect(find.text('Page 1 of 6'), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'He stepped forward with a curious heart and a very brave smile.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Miko hero'), findsOneWidget);
    expect(find.text('Abbas hero'), findsOneWidget);
    expect(find.text("a moon garden: Abbas's Adventure"), findsNothing);
    await tester.tap(find.text('Abbas hero'));
    await tester.pumpAndSettle();
    expect(find.text("a moon garden: Abbas's Adventure"), findsWidgets);
  });
}

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
