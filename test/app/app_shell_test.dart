import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_router.dart';
import 'package:miko_hero/app/app_routes.dart';
import 'package:miko_hero/app/app_shell.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/screen_layout.dart';

/// Verifies that the shell's header follows each route's own declaration.
///
/// The shell is pumped on its own rather than through the application, so a
/// route's header is asserted without the parent PIN, a seeded library, or the
/// page below having any say in it.
void main() {
  testWidgets('every route gets the header its declaration asked for', (
    tester,
  ) async {
    for (final route in appRoutes) {
      final location = _locationFor(route.path);
      await _pumpShell(tester, location);

      expect(
        find.byType(AppBar),
        route.paintsOwnHeader ? findsNothing : findsOneWidget,
        reason: route.paintsOwnHeader
            ? '$location declares its own header, so the shell must add none'
            : '$location declares no header of its own, so the shell adds one',
      );
    }
  });

  test('Home, the shelf, Create, Settings and the Reader head themselves', () {
    final selfHeaded = appRoutes
        .where((route) => route.paintsOwnHeader)
        .map((route) => route.path)
        .toList();

    expect(selfHeaded, <String>[
      '/',
      '/create',
      '/library',
      '/settings',
      '/settings/family',
      '/settings/reading',
      '/settings/pc',
      '/settings/safety',
      '/settings/data',
      '/settings/about',
      '/story/:storyId',
    ]);
  });

  testWidgets('a desktop window carries no shell header on any route', (
    tester,
  ) async {
    for (final route in appRoutes) {
      await _pumpShell(
        tester,
        _locationFor(route.path),
        width: desktopBreakpoint,
      );

      expect(
        find.byType(AppBar),
        findsNothing,
        reason: 'the rail replaces the bar above ${route.path}',
      );
      expect(find.byType(NavigationRail), findsOneWidget);
    }
  });

  test('no route reaches the router without a header declaration', () {
    final routed = _goRoutePathsOf(appRouter.configuration.routes).toList();
    final declared = appRoutes.map((route) => route.path).toList();

    expect(
      routed.toSet(),
      declared.toSet(),
      reason:
          'every GoRoute is built from appRoutes, so a path here that is not '
          'declared means a route was added to the router by hand and the '
          'shell has no header answer for it',
    );
    expect(routed, hasLength(declared.length));
  });
}

/// Every `GoRoute` path in the built router, shells and subtrees included.
Iterable<String> _goRoutePathsOf(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) yield route.path;
    yield* _goRoutePathsOf(route.routes);
  }
}

/// One location a family could really be at, for a possibly patterned path.
String _locationFor(String path) {
  return path
      .split('/')
      .map((segment) => segment.startsWith(':') ? 'sample-id' : segment)
      .join('/');
}

/// Places the shell at [location] in a window of the requested width.
///
/// The routed child is empty on purpose: the only header a test can then find
/// is the one the shell itself decided to draw.
Future<void> _pumpShell(
  WidgetTester tester,
  String location, {
  double width = 400,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AppShell(location: location, child: const SizedBox.shrink()),
    ),
  );
  await tester.pumpAndSettle();
}
