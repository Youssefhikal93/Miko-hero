import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/core/generation/demo_story_generator.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
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

    expect(find.text('Iam - hero'), findsWidgets);
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

    final prompt = find.text('أضف ملف بطل');
    expect(prompt, findsOneWidget);
    expect(Directionality.of(tester.element(prompt)), TextDirection.rtl);
  });

  testWidgets('Somali selection keeps localized Material controls available', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bridgeCredentialStorageProvider.overrideWithValue(
            InMemoryBridgeCredentialStorage(),
          ),
        ],
        child: const IamHeroApp(),
      ),
    );
    await tester.pumpAndSettle();
    appRouter.go('/settings');
    await tester.pumpAndSettle();

    final languageSelector = find.byKey(
      const ValueKey<String>('app-language-en'),
    );
    await tester.tap(languageSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Somali').last);
    await tester.pumpAndSettle();

    final somaliTitle = find.text('Dejinta iyo gaar ahaanshaha');
    expect(somaliTitle, findsOneWidget);
    expect(MaterialLocalizations.of(tester.element(somaliTitle)), isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile editor keeps the family drawer available', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();
    appRouter.go('/profiles/new');
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.text('My Kingdom'), findsWidgets);
    await tester.tap(find.text('My Kingdom').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Choose a hero, update their profile, and give each child their own app color.',
      ),
      findsOneWidget,
    );
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the bottom bar shows icons the family can still name', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_profile_id': 'miko',
      'child_profiles': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'miko',
          'name': 'Miko',
          'age': 7,
          'photoBase64': _transparentPixel,
          'gender': 'girl',
          'themeColorValue': AppTheme.girlPink.toARGB32(),
        },
      ]),
    });
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bridgeCredentialStorageProvider.overrideWithValue(
            InMemoryBridgeCredentialStorage(),
          ),
        ],
        child: const IamHeroApp(),
      ),
    );
    await tester.pumpAndSettle();

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    for (final label in _destinationLabels.values) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsNothing,
      );
    }
    _expectActiveDot(tester, '/', accent: AppTheme.girlPink);

    for (final route in <String>[
      '/create',
      '/library',
      '/kingdom',
      '/settings',
      '/',
    ]) {
      await tester.tap(
        find.descendant(
          of: bar,
          matching: find.bySemanticsLabel(
            RegExp('^${_destinationLabels[route]}'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      _expectActiveDot(tester, route, accent: AppTheme.girlPink);
    }
    semantics.dispose();
  });

  testWidgets('each hero restores the custom color saved in My Kingdom', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_profile_id': 'miko',
      'child_profiles': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'miko',
          'name': 'Miko',
          'age': 7,
          'photoBase64': _transparentPixel,
          'gender': 'girl',
          'themeColorValue': AppTheme.girlPink.toARGB32(),
        },
        <String, Object>{
          'id': 'abbas',
          'name': 'Abbas',
          'age': 9,
          'photoBase64': _transparentPixel,
          'gender': 'boy',
          'themeColorValue': AppTheme.boyCyan.toARGB32(),
        },
      ]),
    });
    appRouter.go('/kingdom');
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    final themeTitle = find.text('Kingdom color');
    expect(
      Theme.of(tester.element(themeTitle)).colorScheme.primary,
      AppTheme.girlPink,
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('kingdom-profile-abbas')),
    );
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(themeTitle)).colorScheme.primary,
      AppTheme.boyCyan,
    );

    final customColorButton = find.text('Custom color');
    await tester.ensureVisible(customColorButton);
    await tester.tap(customColorButton);
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(3));
    await tester.drag(find.byType(Slider).first, const Offset(90, 0));
    await tester.pump();
    await tester.tap(find.text('Use this color'));
    await tester.pumpAndSettle();
    final customColor = Theme.of(
      tester.element(themeTitle),
    ).colorScheme.primary;
    expect(customColor, isNot(AppTheme.boyCyan));

    final mikoProfile = find.byKey(
      const ValueKey<String>('kingdom-profile-miko'),
    );
    await tester.ensureVisible(mikoProfile);
    await tester.tap(mikoProfile);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(themeTitle)).colorScheme.primary,
      AppTheme.girlPink,
    );
    final abbasProfile = find.byKey(
      const ValueKey<String>('kingdom-profile-abbas'),
    );
    await tester.ensureVisible(abbasProfile);
    await tester.tap(abbasProfile);
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(themeTitle)).colorScheme.primary,
      customColor,
    );

    await tester.tap(find.text('Edit name and profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Abbas New');
    final saveProfileButton = find.text('Save profile');
    await tester.ensureVisible(saveProfileButton);
    await tester.tap(saveProfileButton);
    await tester.pumpAndSettle();
    expect(find.text('Abbas New hero'), findsWidgets);
    expect(
      Theme.of(tester.element(find.text('Kingdom color'))).colorScheme.primary,
      customColor,
    );
  });

  testWidgets('a legacy profile keeps its age until a birth date is chosen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'active_profile_id': 'miko',
      'child_profiles': jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'miko',
          'name': 'Miko',
          'age': 7,
          'photoBase64': _transparentPixel,
          'gender': 'girl',
        },
      ]),
    });
    appRouter.go('/profiles/miko');
    await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
    await tester.pumpAndSettle();

    expect(find.text('Age'), findsNothing);
    expect(
      find.text('Saved age: 7. Choose a birth date so it stays correct.'),
      findsOneWidget,
    );

    final pickBirthDateButton = find.text('Choose birth date').last;
    await tester.ensureVisible(pickBirthDateButton);
    await tester.pumpAndSettle();
    await tester.tap(pickBirthDateButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('7 years old'), findsOneWidget);
    final saveProfileButton = find.text('Save profile');
    await tester.ensureVisible(saveProfileButton);
    await tester.tap(saveProfileButton);
    await tester.pumpAndSettle();

    expect(find.text('7 years old'), findsOneWidget);
    expect(find.text('Miko hero'), findsWidgets);
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
          bridgeCredentialStorageProvider.overrideWithValue(
            InMemoryBridgeCredentialStorage(),
          ),
        ],
        child: const IamHeroApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New story'));
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

    expect(find.text('Review this story'), findsOneWidget);
    expect(find.text('Approve story'), findsOneWidget);
    final approveButton = find.text('Approve story');
    await tester.ensureVisible(approveButton);
    await tester.tap(approveButton);
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

/// English name every bottom destination keeps for accessibility tooling.
const _destinationLabels = <String, String>{
  '/': 'Home',
  '/create': 'Create',
  '/library': 'Library',
  '/kingdom': 'My Kingdom',
  '/settings': 'Settings',
};

/// Fails unless the dot marks [route] alone, drawn in the child's [accent].
void _expectActiveDot(
  WidgetTester tester,
  String route, {
  required Color accent,
}) {
  for (final candidate in _destinationLabels.keys) {
    final dot = find.byKey(ValueKey<String>('nav-dot-$candidate'));
    if (candidate != route) {
      expect(dot, findsNothing);
      continue;
    }
    expect(dot, findsOneWidget);
    final decoration = tester.widget<Container>(dot).decoration;
    expect((decoration! as BoxDecoration).color, accent);
    expect(Theme.of(tester.element(dot)).colorScheme.primary, accent);
  }
}

const _transparentPixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
