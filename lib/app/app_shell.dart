import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Responsive navigation frame shared by the four primary destinations.
class AppShell extends StatelessWidget {
  /// Creates a shell around the currently selected routed child.
  const AppShell({required this.location, required this.child, super.key});

  /// Current URL path used to highlight navigation state.
  final String location;

  /// Routed feature content.
  final Widget child;

  @override
  /// Switches between bottom navigation and a desktop navigation rail.
  Widget build(BuildContext context) {
    final destinations = _destinations(AppLocalizations.of(context));
    final selectedIndex = _selectedIndex(location);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return _DesktopShell(
            destinations: destinations,
            selectedIndex: selectedIndex,
            child: child,
          );
        }
        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => context.go(_routeFor(index)),
            destinations: destinations,
          ),
        );
      },
    );
  }

  /// Builds localized destinations in the stable route order.
  List<NavigationDestination> _destinations(AppLocalizations text) {
    return <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_rounded),
        label: text.home,
      ),
      NavigationDestination(
        icon: const Icon(Icons.auto_awesome_rounded),
        label: text.create,
      ),
      NavigationDestination(
        icon: const Icon(Icons.menu_book_rounded),
        label: text.library,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_rounded),
        label: text.settings,
      ),
    ];
  }

  /// Maps a URL to its navigation index and treats unknown paths as home.
  int _selectedIndex(String path) {
    if (path.startsWith('/create')) return 1;
    if (path.startsWith('/library')) return 2;
    if (path.startsWith('/settings')) return 3;
    return 0;
  }

  /// Maps the selected navigation index to a stable application route.
  String _routeFor(int index) {
    return const <String>['/', '/create', '/library', '/settings'][index];
  }
}

/// Desktop shell with persistent branding and a compact navigation rail.
class _DesktopShell extends StatelessWidget {
  /// Creates the rail using already-localized destination labels.
  const _DesktopShell({
    required this.destinations,
    required this.selectedIndex,
    required this.child,
  });

  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final Widget child;

  @override
  /// Renders a side rail while leaving feature content independently scrollable.
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            width: 220,
            decoration: const BoxDecoration(
              color: Color(0xFF0F121A),
              border: Border(right: BorderSide(color: Color(0xFF262A37))),
            ),
            child: SafeArea(
              child: Column(
                children: <Widget>[
                  const _Brand(),
                  const SizedBox(height: 18),
                  Expanded(child: _rail(context)),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// Builds the extended rail and routes taps without rebuilding destination data.
  Widget _rail(BuildContext context) {
    return NavigationRail(
      backgroundColor: Colors.transparent,
      extended: true,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        context.go(
          const <String>['/', '/create', '/library', '/settings'][index],
        );
      },
      destinations: destinations
          .map((destination) => _railDestination(context, destination))
          .toList(),
    );
  }

  /// Converts a bottom destination into the equivalent rail destination.
  NavigationRailDestination _railDestination(
    BuildContext context,
    NavigationDestination destination,
  ) {
    return NavigationRailDestination(
      icon: destination.icon,
      selectedIcon: IconTheme(
        data: IconThemeData(color: Theme.of(context).colorScheme.primary),
        child: destination.icon,
      ),
      label: Text(destination.label),
    );
  }
}

/// Compact brand lockup shown on desktop navigation.
class _Brand extends StatelessWidget {
  /// Creates a code-rendered mark that needs no external brand asset.
  const _Brand();

  @override
  /// Keeps the logo recognizable without relying on an external image asset.
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[colors.primary, colors.secondary],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: Colors.black),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Iam - hero',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
