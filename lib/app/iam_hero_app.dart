import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/l10n/somali_platform_localizations.dart';

/// Root widget that binds persisted locale state to the routed application.
class IamHeroApp extends ConsumerWidget {
  /// Creates the immutable application root.
  const IamHeroApp({super.key});

  @override
  /// Renders routed features while local state loads in their own boundaries.
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appControllerProvider);
    final activeProfile = appState.value?.activeProfile;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Iam - hero',
      theme: AppTheme.dark(activeProfile),
      routerConfig: appRouter,
      locale: appState.value?.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        SomaliMaterialLocalizationsDelegate(),
        SomaliCupertinoLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
    );
  }
}
