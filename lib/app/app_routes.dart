import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/features/home/home_page.dart';
import 'package:miko_hero/features/kingdom/my_kingdom_page.dart';
import 'package:miko_hero/features/library/story_library_page.dart';
import 'package:miko_hero/features/profile/profile_page.dart';
import 'package:miko_hero/features/reader/story_reader_page.dart';
import 'package:miko_hero/features/review/story_review_page.dart';
import 'package:miko_hero/features/settings/about_settings_page.dart';
import 'package:miko_hero/features/settings/data_settings_page.dart';
import 'package:miko_hero/features/settings/family_settings_page.dart';
import 'package:miko_hero/features/settings/pc_settings_page.dart';
import 'package:miko_hero/features/settings/reading_settings_page.dart';
import 'package:miko_hero/features/settings/safety_settings_page.dart';
import 'package:miko_hero/features/settings/settings_page.dart';
import 'package:miko_hero/features/story_creation/generation_center_page.dart';
import 'package:miko_hero/features/story_creation/story_creation_page.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

/// One declared route: its path, the page it builds, and who paints its header.
///
/// The header question is answered here, beside the route, and nowhere else.
/// `appRouter` builds its `GoRoute`s from [appRoutes] and the app shell reads
/// the same declarations back through [appRouteFor], so a new screen that opens
/// with its own title row is one flag on one line rather than a path the shell
/// has to be taught to recognise.
@immutable
class AppRoute {
  /// Declares a route that builds a page.
  const AppRoute({
    required this.path,
    required GoRouterWidgetBuilder this.builder,
    this.paintsOwnHeader = false,
  }) : redirect = null;

  /// Declares a path that only forwards to another one and builds no page.
  ///
  /// Nothing is ever drawn at such a path, so it can hold no header of its own.
  const AppRoute.forwarding({
    required this.path,
    required GoRouterRedirect this.redirect,
  }) : builder = null,
       paintsOwnHeader = false;

  /// URL path, in go_router's own syntax, `:name` segments included.
  final String path;

  /// Builds the routed feature, or null when this path only forwards.
  final GoRouterWidgetBuilder? builder;

  /// Sends the family somewhere else, or null when this path builds a page.
  final GoRouterRedirect? redirect;

  /// Whether the page opens with its own title row, leaving the shell none.
  ///
  /// True on the screens the redesign gave a header of their own — Home, the
  /// shelf, Create, the reader, and every Settings page: a shell bar above one
  /// of those would be a second header on a phone. False everywhere else, which
  /// keeps the shell bar and the menu button it carries.
  final bool paintsOwnHeader;

  /// Hands this declaration to go_router unchanged.
  GoRoute toGoRoute() {
    return GoRoute(path: path, builder: builder, redirect: redirect);
  }

  /// Whether [location] is this route, reading `:name` segments as wildcards.
  ///
  /// Only the path is compared: a query string names which shelf to open on,
  /// never which screen was reached.
  bool matches(String location) {
    final declared = _segmentsOf(path);
    final reached = _segmentsOf(location);
    if (declared.length != reached.length) return false;
    for (var index = 0; index < declared.length; index++) {
      final segment = declared[index];
      if (segment.startsWith(':')) continue;
      if (segment != reached[index]) return false;
    }
    return true;
  }

  static List<String> _segmentsOf(String path) {
    return path.split('/').where((segment) => segment.isNotEmpty).toList();
  }
}

/// Every route in the application, in the order go_router matches them.
///
/// Literal paths stand before the `:name` paths they would otherwise be
/// swallowed by, so `/profiles/new` stays the editor for a new child.
final List<AppRoute> appRoutes = <AppRoute>[
  AppRoute(
    path: '/',
    paintsOwnHeader: true,
    builder: (context, state) => const HomePage(),
  ),
  AppRoute(
    path: '/create',
    paintsOwnHeader: true,
    builder: (context, state) => const StoryCreationPage(),
  ),
  AppRoute(
    path: '/generation',
    builder: (context, state) {
      return const ParentAccessGate(child: GenerationCenterPage());
    },
  ),
  AppRoute(
    path: '/library',
    paintsOwnHeader: true,
    builder: (context, state) {
      return StoryLibraryPage(
        profileId: state.uri.queryParameters[libraryChildQueryParameter],
      );
    },
  ),
  // Settings is one root list of groups over one page per group. Every one of
  // them opens with its own title row, and all of them sit behind the same
  // parent gate: a group page is reachable by URL, so the gate has to be on
  // each of them rather than only on the list that links to them.
  AppRoute(
    path: '/settings',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: SettingsPage());
    },
  ),
  AppRoute(
    path: '/settings/family',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: FamilySettingsPage());
    },
  ),
  AppRoute(
    path: '/settings/reading',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: ReadingSettingsPage());
    },
  ),
  AppRoute(
    path: '/settings/pc',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: PcSettingsPage());
    },
  ),
  AppRoute(
    path: '/settings/safety',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: SafetySettingsPage());
    },
  ),
  AppRoute(
    path: '/settings/data',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: DataSettingsPage());
    },
  ),
  AppRoute(
    path: '/settings/about',
    paintsOwnHeader: true,
    builder: (context, state) {
      return const ParentAccessGate(child: AboutSettingsPage());
    },
  ),
  AppRoute(
    path: '/kingdom',
    builder: (context, state) {
      return const ParentAccessGate(child: MyKingdomPage());
    },
  ),
  AppRoute(
    path: '/profiles',
    builder: (context, state) {
      return const ParentAccessGate(child: ProfilePage());
    },
  ),
  AppRoute(
    path: '/profiles/new',
    builder: (context, state) {
      return const ParentAccessGate(child: ProfileEditorPage());
    },
  ),
  AppRoute(
    path: '/profiles/:profileId',
    builder: (context, state) {
      return ParentAccessGate(
        child: ProfileEditorPage(profileId: state.pathParameters['profileId']),
      );
    },
  ),
  AppRoute.forwarding(
    path: '/profile',
    redirect: (context, state) => '/profiles',
  ),
  AppRoute(
    path: '/review',
    builder: (context, state) {
      return const ParentAccessGate(child: StoryReviewQueuePage());
    },
  ),
  AppRoute(
    path: '/review/:storyId',
    builder: (context, state) {
      return ParentAccessGate(
        child: StoryReviewPage(storyId: state.pathParameters['storyId']!),
      );
    },
  ),
  AppRoute(
    path: '/story/:storyId',
    paintsOwnHeader: true,
    builder: (context, state) {
      return StoryReaderPage(storyId: state.pathParameters['storyId']!);
    },
  ),
];

/// The declaration [location] reached, or null when no route claims it.
///
/// A location nothing claims is not a screen the family can be looking at, so
/// the shell treats it like any undeclared route and keeps its own header.
AppRoute? appRouteFor(String location) {
  for (final route in appRoutes) {
    if (route.matches(location)) return route;
  }
  return null;
}
