import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/home/home_greeting.dart';
import 'package:miko_hero/features/home/home_hero_switcher.dart';
import 'package:miko_hero/features/home/home_tiles.dart';
import 'package:miko_hero/features/library/story_library_page.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// The family's first screen: who is reading, what to read next, what is new.
class HomePage extends ConsumerWidget {
  /// Creates the routed home destination.
  const HomePage({super.key});

  @override
  /// Observes persisted state and delegates transient states to one boundary.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _HomeContent(state: snapshot),
    );
  }
}

/// Loaded home content kept independent from asynchronous state plumbing.
class _HomeContent extends StatelessWidget {
  /// Creates the dashboard from one immutable state snapshot.
  const _HomeContent({required this.state});

  final AppState state;

  /// Covers the shelf strip shows before the library takes over.
  static const _shelfStripLength = 6;

  @override
  /// Puts the profile prompt before everything else for a family with none.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    if (state.profiles.isEmpty) {
      return ScreenLayout(child: _ProfileSetupPrompt(text: text));
    }
    final activeProfile = state.activeProfile;
    final keepReading = keepReadingStory(state, activeProfile);
    final draftCount = state.draftStories.length;
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HomeHeroHeader(
            profiles: state.profiles,
            activeProfile: activeProfile,
          ),
          const SizedBox(height: 20),
          _Greeting(
            greeting: homeGreeting(text, homeTimeOfDay(DateTime.now())),
            line: homeGreetingLine(
              text,
              keepReading: keepReading,
              hasDrafts: draftCount > 0,
            ),
          ),
          const SizedBox(height: 18),
          MosaicGrid(
            tiles: _tiles(
              activeProfile: activeProfile,
              keepReading: keepReading,
              draftCount: draftCount,
            ),
          ),
          ..._shelf(context, text, activeProfile, keepReading),
        ],
      ),
    );
  }

  /// Builds only the tiles this family's real state has something to say with.
  ///
  /// Home offers no secondary command on a book, so no tile here carries an
  /// overflow control: favourites, sharing, and deletion stay on the shelf and
  /// in the parent surfaces that own them.
  List<MosaicTile> _tiles({
    required ChildProfile? activeProfile,
    required StoryBook? keepReading,
    required int draftCount,
  }) {
    return <MosaicTile>[
      if (keepReading != null)
        MosaicTile(span: 2, child: HomeKeepReadingTile(story: keepReading)),
      const MosaicTile(child: HomeNewStoryTile()),
      if (activeProfile != null)
        MosaicTile(child: HomeReadingBadgesTile(profile: activeProfile)),
      if (draftCount > 0)
        MosaicTile(span: 2, child: HomeDraftsRow(draftCount: draftCount)),
    ];
  }

  /// Adds the shelf strip only when the active child has covers left to show.
  ///
  /// The book already featured on the keep-reading tile is left out, so the
  /// strip is the rest of the shelf rather than a second look at the same
  /// cover.
  List<Widget> _shelf(
    BuildContext context,
    AppLocalizations text,
    ChildProfile? activeProfile,
    StoryBook? keepReading,
  ) {
    if (activeProfile == null) return const <Widget>[];
    final covers = state
        .storiesForProfile(activeProfile.id)
        .where((story) => story.id != keepReading?.id)
        .take(_shelfStripLength)
        .toList(growable: false);
    if (covers.isEmpty) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: 24),
      _ShelfHeading(text: text, profileId: activeProfile.id),
      const SizedBox(height: 12),
      _ShelfStrip(covers: covers),
    ];
  }
}

/// Setup prompt shown only before a private profile exists.
class _ProfileSetupPrompt extends StatelessWidget {
  /// Creates localized setup guidance.
  const _ProfileSetupPrompt({required this.text});

  final AppLocalizations text;

  @override
  /// Presents the single blocking requirement without adding onboarding steps.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.face_retouching_natural_rounded,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              text.profileIncompleteTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(text.profileIncompleteBody),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.go('/profiles/new'),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(text.setUpProfile),
            ),
          ],
        ),
      ),
    );
  }
}

/// Greeting by time of day over one line about what is actually waiting.
class _Greeting extends StatelessWidget {
  /// Creates the two-line greeting from already-localized copy.
  const _Greeting({required this.greeting, required this.line});

  final String greeting;
  final String line;

  @override
  /// Keeps both lines in one paragraph so they wrap as a single sentence pair.
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineMedium;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '$greeting\n'),
          TextSpan(
            text: line,
            style: const TextStyle(color: AppTheme.mutedDeep),
          ),
        ],
      ),
      style: style?.copyWith(height: 1.2),
    );
  }
}

/// "On the shelf" over the link that hands the rest to the library.
class _ShelfHeading extends StatelessWidget {
  /// Creates the strip heading and its library link.
  const _ShelfHeading({required this.text, required this.profileId});

  final AppLocalizations text;

  /// Child whose shelf the strip is showing, named in the library route.
  final String profileId;

  @override
  /// Sends the family to the shelf they were already looking at.
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(
            text.onTheShelf.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: AppTheme.mutedDeep,
            ),
          ),
        ),
        TextButton(
          key: const ValueKey<String>('home-see-all'),
          onPressed: () => context.go(libraryRouteForChild(profileId)),
          child: Text(text.seeAll),
        ),
      ],
    );
  }
}

/// Horizontal run of the active child's most recent approved covers.
class _ShelfStrip extends StatelessWidget {
  /// Creates the strip from covers already filtered to one child.
  const _ShelfStrip({required this.covers});

  final List<StoryBook> covers;

  /// Width of one cover in the strip.
  static const _coverWidth = 148.0;

  @override
  /// Scrolls sideways so a long shelf never pushes the page down.
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final story in covers)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: SizedBox(
                width: _coverWidth,
                child: StoryCard(
                  story: story,
                  variant: StoryCardVariant.small,
                  actions: StoryCardActions(
                    open: () => context.go('/story/${story.id}'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
