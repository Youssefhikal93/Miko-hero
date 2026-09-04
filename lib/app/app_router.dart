import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_routes.dart';
import 'package:miko_hero/app/app_shell.dart';

/// Stable route table shared by mobile deep links and Flutter web URLs.
///
/// Every route is declared once in [appRoutes]; this file only wraps them in
/// the shell, so the router and the shell can never disagree about a path.
final appRouter = GoRouter(
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[for (final route in appRoutes) route.toGoRoute()],
    ),
  ],
);
