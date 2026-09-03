import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/l10n/app_localizations.dart';

/// Responsive navigation frame retained around every application route.
class AppShell extends StatelessWidget {
  /// Creates a shell around the currently selected routed child.
  const AppShell({required this.location, required this.child, super.key});

  /// Current URL path used to highlight navigation state.
  final String location;

  /// Routed feature content.
  final Widget child;

  @override
  /// Keeps a drawer and bottom navigation on mobile or a rail on desktop.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final destinations = _destinations(text);
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
        return _MobileShell(
          location: location,
          destinations: destinations,
          selectedIndex: selectedIndex,
          child: child,
        );
      },
    );
  }

  /// Builds the five localized destinations in their stable route order.
  List<_NavigationDestination> _destinations(AppLocalizations text) {
    return <_NavigationDestination>[
      _NavigationDestination(
        icon: Icons.home_rounded,
        label: text.home,
        route: '/',
      ),
      _NavigationDestination(
        icon: Icons.auto_awesome_rounded,
        label: text.create,
        route: '/create',
      ),
      _NavigationDestination(
        icon: Icons.menu_book_rounded,
        label: text.library,
        route: '/library',
      ),
      _NavigationDestination(
        icon: Icons.castle_rounded,
        label: text.myKingdom,
        route: '/kingdom',
      ),
      _NavigationDestination(
        icon: Icons.settings_rounded,
        label: text.settings,
        route: '/settings',
      ),
    ];
  }

  /// Highlights the parent destination for detail and editor routes.
  int _selectedIndex(String path) {
    if (path.startsWith('/create') || path.startsWith('/generation')) return 1;
    if (path.startsWith('/library') ||
        path.startsWith('/story/') ||
        path.startsWith('/review')) {
      return 2;
    }
    if (path.startsWith('/kingdom') || path.startsWith('/profile')) return 3;
    if (path.startsWith('/settings')) return 4;
    return 0;
  }
}

/// Immutable navigation label, icon, and route shared by every breakpoint.
class _NavigationDestination {
  /// Keeps drawer, rail, and bottom navigation route knowledge in one place.
  const _NavigationDestination({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

/// Mobile frame with both an always-available drawer and compact bottom routes.
class _MobileShell extends StatelessWidget {
  /// Creates the mobile frame around any primary or detail route.
  const _MobileShell({
    required this.location,
    required this.destinations,
    required this.selectedIndex,
    required this.child,
  });

  final String location;
  final List<_NavigationDestination> destinations;
  final int selectedIndex;
  final Widget child;

  @override
  /// Keeps the menu button visible inside profile editors and story readers.
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iam - hero'),
        actions: _readerActions(context),
      ),
      drawer: _AppDrawer(
        destinations: destinations,
        selectedIndex: selectedIndex,
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (index) {
          context.go(destinations[index].route);
        },
        destinations: destinations.map(_bottomDestination).toList(),
      ),
    );
  }

  /// Adds a library exit while the global drawer remains the leading action.
  List<Widget> _readerActions(BuildContext context) {
    if (!location.startsWith('/story/')) return const <Widget>[];
    return <Widget>[
      IconButton(
        tooltip: AppLocalizations.of(context).library,
        onPressed: () => context.go('/library'),
        icon: const Icon(Icons.close_rounded),
      ),
    ];
  }

  /// Adapts shared route data to Material's compact navigation destination.
  NavigationDestination _bottomDestination(_NavigationDestination destination) {
    return NavigationDestination(
      icon: Icon(destination.icon),
      label: destination.label,
    );
  }
}

/// Drawer opened by the persistent mobile app-bar menu button.
class _AppDrawer extends StatelessWidget {
  /// Creates a drawer from the same destinations used by the bottom bar.
  const _AppDrawer({required this.destinations, required this.selectedIndex});

  final List<_NavigationDestination> destinations;
  final int selectedIndex;

  @override
  /// Closes before routing so the next screen never inherits an open drawer.
  Widget build(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(destinations[index].route);
      },
      children: <Widget>[
        const SafeArea(bottom: false, child: _Brand()),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(),
        ),
        ...destinations.map((destination) {
          return NavigationDrawerDestination(
            icon: Icon(destination.icon),
            label: Text(destination.label),
          );
        }),
      ],
    );
  }
}

/// Desktop shell with persistent branding and an extended navigation rail.
class _DesktopShell extends StatelessWidget {
  /// Creates the rail using already-localized destination labels.
  const _DesktopShell({
    required this.destinations,
    required this.selectedIndex,
    required this.child,
  });

  final List<_NavigationDestination> destinations;
  final int selectedIndex;
  final Widget child;

  @override
  /// Retains navigation while content scrolls or opens a detail route.
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          Container(
            width: 270,
            decoration: const BoxDecoration(
              color: AppTheme.sunken,
              border: Border(right: BorderSide(color: AppTheme.hairline)),
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

  /// Routes selections using the same stable destinations as mobile navigation.
  Widget _rail(BuildContext context) {
    return NavigationRail(
      backgroundColor: Colors.transparent,
      extended: true,
      minExtendedWidth: 270,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        context.go(destinations[index].route);
      },
      destinations: destinations.map((destination) {
        return NavigationRailDestination(
          icon: Icon(destination.icon),
          selectedIcon: Icon(
            destination.icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          label: Text(destination.label),
        );
      }).toList(),
    );
  }
}

/// Compact brand lockup rendered without external image assets.
class _Brand extends StatelessWidget {
  /// Creates the shared drawer and rail header.
  const _Brand();

  @override
  /// Uses the current child's palette while keeping the app name stable.
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
