import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/iam_hero_app.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scenario in [
    (size: const Size(375, 812), scale: 1.0, locale: 'en', reduced: false),
    (size: const Size(768, 1024), scale: 1.0, locale: 'en', reduced: false),
    (size: const Size(1440, 900), scale: 1.0, locale: 'en', reduced: false),
    (size: const Size(1440, 900), scale: 2.0, locale: 'ar', reduced: true),
    (size: const Size(812, 375), scale: 2.0, locale: 'ar', reduced: true),
    (size: const Size(375, 812), scale: 2.0, locale: 'en', reduced: true),
  ]) {
    testWidgets('home fits and profile action works at ${scenario.size}, '
        '${scenario.locale}, text scale ${scenario.scale}', (tester) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: scenario.reduced);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      SharedPreferences.setMockInitialValues({'app_locale': scenario.locale});
      appRouter.go('/');

      await tester.pumpWidget(const ProviderScope(child: IamHeroApp()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final text = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      );
      final profileAction = find.widgetWithText(
        FilledButton,
        text.setUpProfile,
      );
      await tester.ensureVisible(profileAction);
      await tester.tap(profileAction);
      await tester.pumpAndSettle();

      expect(
        appRouter.routeInformationProvider.value.uri.path,
        '/profiles/new',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
