import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/l10n/somali_platform_localizations.dart';

/// Root widget that binds persisted locale state to the routed application.
class IamHeroApp extends ConsumerStatefulWidget {
  /// Creates the immutable application root.
  const IamHeroApp({super.key});

  @override
  /// Holds nothing but the one-shot start-up synchronization request.
  ConsumerState<IamHeroApp> createState() => _IamHeroAppState();
}

/// Application root that asks for one synchronization after every start.
class _IamHeroAppState extends ConsumerState<IamHeroApp> {
  @override
  /// Requests the automatic sync a Local AI family expects after a start.
  ///
  /// The controller decides whether anything happens: it returns immediately
  /// unless this device is paired and set to Local AI, and it never throws
  /// into the widget tree, because no screen is waiting on the result.
  void initState() {
    super.initState();
    unawaited(
      ref.read(librarySyncControllerProvider.notifier).syncAfterAppStart(),
    );
  }

  @override
  /// Renders routed features while local state loads in their own boundaries.
  Widget build(BuildContext context) {
    final appState = ref.watch(appControllerProvider);
    final activeProfile = appState.value?.activeProfile;
    final locale = appState.value?.locale;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Iam - hero',
      theme: AppTheme.dark(activeProfile, locale: locale),
      routerConfig: appRouter,
      locale: locale,
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
