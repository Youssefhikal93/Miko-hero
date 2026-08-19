import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_shell.dart';
import 'package:miko_hero/features/home/home_page.dart';
import 'package:miko_hero/features/kingdom/my_kingdom_page.dart';
import 'package:miko_hero/features/library/story_library_page.dart';
import 'package:miko_hero/features/profile/profile_page.dart';
import 'package:miko_hero/features/reader/story_reader_page.dart';
import 'package:miko_hero/features/review/story_review_page.dart';
import 'package:miko_hero/features/settings/settings_page.dart';
import 'package:miko_hero/features/story_creation/generation_center_page.dart';
import 'package:miko_hero/features/story_creation/story_creation_page.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';

/// Stable route table shared by mobile deep links and Flutter web URLs.
final appRouter = GoRouter(
  routes: <RouteBase>[
    ShellRoute(
      builder: (context, state, child) {
        return AppShell(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/create',
          builder: (context, state) => const StoryCreationPage(),
        ),
        GoRoute(
          path: '/generation',
          builder: (context, state) {
            return const ParentAccessGate(child: GenerationCenterPage());
          },
        ),
        GoRoute(
          path: '/library',
          builder: (context, state) => const StoryLibraryPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            return const ParentAccessGate(child: SettingsPage());
          },
        ),
        GoRoute(
          path: '/kingdom',
          builder: (context, state) {
            return const ParentAccessGate(child: MyKingdomPage());
          },
        ),
        GoRoute(
          path: '/profiles',
          builder: (context, state) {
            return const ParentAccessGate(child: ProfilePage());
          },
        ),
        GoRoute(
          path: '/profiles/new',
          builder: (context, state) {
            return const ParentAccessGate(child: ProfileEditorPage());
          },
        ),
        GoRoute(
          path: '/profiles/:profileId',
          builder: (context, state) {
            return ParentAccessGate(
              child: ProfileEditorPage(
                profileId: state.pathParameters['profileId'],
              ),
            );
          },
        ),
        GoRoute(path: '/profile', redirect: (context, state) => '/profiles'),
        GoRoute(
          path: '/review',
          builder: (context, state) {
            return const ParentAccessGate(child: StoryReviewQueuePage());
          },
        ),
        GoRoute(
          path: '/review/:storyId',
          builder: (context, state) {
            return ParentAccessGate(
              child: StoryReviewPage(storyId: state.pathParameters['storyId']!),
            );
          },
        ),
        GoRoute(
          path: '/story/:storyId',
          builder: (context, state) {
            return StoryReaderPage(storyId: state.pathParameters['storyId']!);
          },
        ),
      ],
    ),
  ],
);
