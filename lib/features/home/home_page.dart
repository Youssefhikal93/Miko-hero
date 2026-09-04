import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/home/home_hero_switcher.dart';
import 'package:miko_hero/features/home/home_tiles.dart';
import 'package:miko_hero/features/home/home_view.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_icons.dart';
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

  @override
  /// Puts the profile prompt before everything else for a family with none.
  ///
  /// Everything below it is laid out from one [HomeView]: this widget decides
  /// nothing about which book, which line, or which shelf is Home's.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    if (state.profiles.isEmpty) {
      return ScreenLayout(child: _ProfileSetupPrompt(text: text));
    }
    final view = HomeView.of(state, now: DateTime.now());
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          HomeHeroHeader(
            profiles: state.profiles,
            activeProfile: view.activeProfile,
          ),
          const SizedBox(height: 20),
          _Greeting(view: view),
          const SizedBox(height: 18),
          MosaicGrid(tiles: _tiles(view)),
          ..._shelf(text, view),
        ],
      ),
    );
  }

  /// Lays out only the tiles this family's real state has something to say with.
  ///
  /// Home offers no secondary command on a book, so no tile here carries an
  /// overflow control: favourites, sharing, and deletion stay on the shelf and
  /// in the parent surfaces that own them.
  List<MosaicTile> _tiles(HomeView view) {
    final keepReading = view.keepReading;
    final activeProfile = view.activeProfile;
    return <MosaicTile>[
      if (keepReading != null)
        MosaicTile(span: 2, child: HomeKeepReadingTile(story: keepReading)),
      const MosaicTile(child: HomeNewStoryTile()),
      if (activeProfile != null)
        MosaicTile(child: HomeReadingBadgesTile(profile: activeProfile)),
      if (view.draftCount > 0)
        MosaicTile(span: 2, child: HomeDraftsRow(draftCount: view.draftCount)),
    ];
  }

  /// Adds the shelf strip only when there are covers left to show.
  List<Widget> _shelf(AppLocalizations text, HomeView view) {
    final route = view.shelfRoute;
    if (route == null) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: 24),
      _ShelfHeading(text: text, route: route),
      const SizedBox(height: 12),
      _ShelfStrip(covers: view.shelfStrip),
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
              AppIcons.heroPortrait,
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
              icon: const Icon(AppIcons.addHero),
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
  /// Creates the two-line greeting over the screen Home already resolved.
  const _Greeting({required this.view});

  final HomeView view;

  @override
  /// Keeps both lines in one paragraph so they wrap as a single sentence pair.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final style = Theme.of(context).textTheme.headlineMedium;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(text: '${_greeting(text)}\n'),
          TextSpan(
            text: _line(text),
            style: const TextStyle(color: AppTheme.mutedDeep),
          ),
        ],
      ),
      style: style?.copyWith(height: 1.2),
    );
  }

  /// Localized greeting for the part of the day Home was opened in.
  String _greeting(AppLocalizations text) {
    return switch (view.timeOfDay) {
      HomeTimeOfDay.morning => text.greetingMorning,
      HomeTimeOfDay.afternoon => text.greetingAfternoon,
      HomeTimeOfDay.evening => text.greetingEvening,
      HomeTimeOfDay.night => text.greetingNight,
    };
  }

  /// Localized wording of the line [HomeView] already chose.
  ///
  /// Which of the three is true is not decided here. The last arm exists only
  /// so the book naming its own line is read without a bang: a
  /// [HomeGreetingLine.continueReading] with no book cannot be resolved.
  String _line(AppLocalizations text) {
    final keepReading = view.keepReading;
    return switch (view.greetingLine) {
      HomeGreetingLine.continueReading when keepReading != null =>
        text.greetingContinueStory(keepReading.content.title),
      HomeGreetingLine.draftsWaiting => text.greetingDraftsWaiting,
      HomeGreetingLine.continueReading ||
      HomeGreetingLine.invitation => text.greetingCreateStory,
    };
  }
}

/// "On the shelf" over the link that hands the rest to the library.
class _ShelfHeading extends StatelessWidget {
  /// Creates the strip heading and its library link.
  const _ShelfHeading({required this.text, required this.route});

  final AppLocalizations text;

  /// Library route naming the child whose shelf the strip is showing.
  final String route;

  @override
  /// Sends the family to the shelf they were already looking at.
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Text(text.onTheShelf.toUpperCase(), style: AppTheme.overline),
        ),
        TextButton(
          key: const ValueKey<String>('home-see-all'),
          onPressed: () => context.go(route),
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
