import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// Complete local bookshelf grouped by the child who stars in each story.
class StoryLibraryPage extends ConsumerWidget {
  /// Creates the routed library destination.
  const StoryLibraryPage({super.key});

  @override
  /// Rebuilds immediately after local generation or deletion changes a shelf.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _LibraryContent(state: snapshot),
    );
  }
}

/// Loaded library content independent from persistence state plumbing.
class _LibraryContent extends StatelessWidget {
  /// Creates all profile shelves from one immutable application snapshot.
  const _LibraryContent({required this.state});

  final AppState state;

  @override
  /// Adds child tabs only when more than one profile needs a separate shelf.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeading(
            title: text.libraryTitle,
            subtitle: text.librarySubtitle,
          ),
          const SizedBox(height: 24),
          if (state.profiles.isEmpty)
            _EmptyShelf(text: text)
          else if (state.profiles.length == 1)
            _SingleProfileShelf(
              profile: state.profiles.single,
              stories: state.storiesForProfile(state.profiles.single.id),
            )
          else
            _TabbedProfileShelves(state: state),
        ],
      ),
    );
  }
}

/// Named shelf used when tabs would add no value for a single child.
class _SingleProfileShelf extends StatelessWidget {
  /// Creates one personalized shelf and its visible hero heading.
  const _SingleProfileShelf({required this.profile, required this.stories});

  final ChildProfile profile;
  final List<StoryBook> stories;

  @override
  /// Keeps single-profile behavior compact while retaining personalization.
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(profile.heroName, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _ProfileShelf(stories: stories),
      ],
    );
  }
}

/// Stateful tab selection that swaps visible shelves without losing local state.
class _TabbedProfileShelves extends StatefulWidget {
  /// Creates one tab for every profile in stable persistence order.
  const _TabbedProfileShelves({required this.state});

  final AppState state;

  @override
  /// Retains the selected child's shelf across story deletion rebuilds.
  State<_TabbedProfileShelves> createState() => _TabbedProfileShelvesState();
}

/// Current tab position for a multi-profile library.
class _TabbedProfileShelvesState extends State<_TabbedProfileShelves> {
  int _selectedIndex = 0;

  @override
  /// Renders profile names as tabs and only the selected child's stories below.
  Widget build(BuildContext context) {
    final profiles = widget.state.profiles;
    final selectedProfile = profiles[_selectedIndex];
    return DefaultTabController(
      length: profiles.length,
      initialIndex: _selectedIndex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            onTap: (index) => setState(() => _selectedIndex = index),
            tabs: profiles
                .map((profile) => Tab(text: profile.heroName))
                .toList(),
          ),
          const SizedBox(height: 20),
          _ProfileShelf(
            stories: widget.state.storiesForProfile(selectedProfile.id),
          ),
        ],
      ),
    );
  }
}

/// One child's adaptive story grid with permanent story deletion controls.
class _ProfileShelf extends ConsumerWidget {
  /// Creates a shelf from stories already filtered by profile identity.
  const _ProfileShelf({required this.stories});

  final List<StoryBook> stories;

  @override
  /// Shows a profile-specific invitation or an adaptive card grid.
  Widget build(BuildContext context, WidgetRef ref) {
    if (stories.isEmpty) {
      return _EmptyShelf(text: AppLocalizations.of(context));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - (columns - 1) * 16) / columns;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: stories.map((story) {
            return SizedBox(
              width: cardWidth,
              child: StoryCard(
                story: story,
                onOpen: () => context.go('/story/${story.id}'),
                onDelete: () => _confirmDelete(context, ref, story),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Requires explicit confirmation before permanent local story deletion.
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    StoryBook story,
  ) async {
    final text = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.deleteStoryTitle),
        content: Text(text.deleteStoryBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: Text(text.confirmDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(storyControllerProvider).deleteStory(story.id);
    }
  }
}

/// Empty profile shelf with a direct story-creation action.
class _EmptyShelf extends StatelessWidget {
  /// Creates the empty state from localized copy.
  const _EmptyShelf({required this.text});

  final AppLocalizations text;

  @override
  /// Makes the no-content state useful without inventing sample books.
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: <Widget>[
              const Icon(Icons.auto_stories_outlined, size: 54),
              const SizedBox(height: 16),
              Text(
                text.emptyLibraryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(text.emptyLibraryBody, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.go('/create'),
                child: Text(text.createFirstStory),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
