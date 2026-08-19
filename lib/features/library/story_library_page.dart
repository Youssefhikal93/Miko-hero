import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/kingdom/kingdom_decorations.dart';
import 'package:miko_hero/features/library/story_collections_dialog.dart';
import 'package:miko_hero/features/library/story_share_actions.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';
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
          _LibraryHeader(state: state, text: text),
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

/// Library heading with a parent-only route when drafts need decisions.
class _LibraryHeader extends ConsumerWidget {
  /// Creates a header from loaded state and current localized copy.
  const _LibraryHeader({required this.state, required this.text});

  final AppState state;
  final AppLocalizations text;

  @override
  /// Keeps the review and import actions responsive beside or below the heading.
  Widget build(BuildContext context, WidgetRef ref) {
    final draftCount = state.draftStories.length;
    return Wrap(
      spacing: 18,
      runSpacing: 14,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 560,
          child: SectionHeading(
            title: text.libraryTitle,
            subtitle: text.librarySubtitle,
          ),
        ),
        if (draftCount > 0)
          FilledButton.tonalIcon(
            onPressed: () => context.go('/review'),
            icon: const Icon(Icons.fact_check_rounded),
            label: Text(text.reviewDraftCount(draftCount)),
          ),
        OutlinedButton.icon(
          onPressed: () => importStoryFile(context, ref, state: state),
          icon: const Icon(Icons.file_open_rounded),
          label: Text(text.importStoryFile),
        ),
      ],
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
        _HeroLabel(
          profile: profile,
          style: Theme.of(context).textTheme.titleLarge,
        ),
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
                .map((profile) => Tab(child: _HeroLabel(profile: profile)))
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

/// Hero name preceded by the favourite symbol chosen in My Kingdom.
class _HeroLabel extends StatelessWidget {
  /// Creates a shelf label from one child's saved personalization.
  const _HeroLabel({required this.profile, this.style});

  final ChildProfile profile;
  final TextStyle? style;

  @override
  /// Keeps the label compact enough for a scrollable tab bar.
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          kingdomSymbolIcon(profile.kingdomTheme.symbol),
          size: 18,
          color: Color(profile.themeColorValue),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(profile.heroName, style: style)),
      ],
    );
  }
}

/// One child's adaptive story grid with permanent story deletion controls.
class _ProfileShelf extends ConsumerStatefulWidget {
  /// Creates a shelf from stories already filtered by profile identity.
  const _ProfileShelf({required this.stories});

  final List<StoryBook> stories;

  @override
  /// Creates retained filtering state for one profile shelf.
  ConsumerState<_ProfileShelf> createState() => _ProfileShelfState();
}

/// Favorite and collection filter state for one approved story shelf.
class _ProfileShelfState extends ConsumerState<_ProfileShelf> {
  static const _allFilter = 'all';
  static const _favoritesFilter = 'favorites';

  String _selectedFilter = _allFilter;

  @override
  /// Shows profile books through the selected favorite or collection filter.
  Widget build(BuildContext context) {
    final stories = widget.stories;
    if (stories.isEmpty) {
      return _EmptyShelf(text: AppLocalizations.of(context));
    }
    final collections = _collectionNames(stories);
    final validFilters = <String>{
      _allFilter,
      _favoritesFilter,
      ...collections.map(_collectionFilter),
    };
    final filter = validFilters.contains(_selectedFilter)
        ? _selectedFilter
        : _allFilter;
    final visibleStories = _filteredStories(stories, filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _filterField(collections, filter),
        const SizedBox(height: 18),
        if (visibleStories.isEmpty)
          const _FilteredShelfEmpty()
        else
          _storyGrid(visibleStories),
      ],
    );
  }

  /// Builds the adaptive approved-story card grid for the active filter.
  Widget _storyGrid(List<StoryBook> stories) {
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
                actions: StoryCardActions(
                  open: () => context.go('/story/${story.id}'),
                  delete: () => _confirmDelete(context, story),
                  favorite: () => _toggleFavorite(story),
                  collections: () => _manageCollections(context, story),
                  share: () => exportStoryFile(context, ref, story),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Creates a localized selector for all, favorite, and collection views.
  Widget _filterField(List<String> collections, String filter) {
    final text = AppLocalizations.of(context);
    return DropdownButtonFormField<String>(
      key: ValueKey<String>('story-filter-$filter'),
      initialValue: filter,
      decoration: InputDecoration(labelText: text.filterStories),
      items: <DropdownMenuItem<String>>[
        DropdownMenuItem(value: _allFilter, child: Text(text.allStories)),
        DropdownMenuItem(
          value: _favoritesFilter,
          child: Text(text.favoriteStories),
        ),
        ...collections.map(
          (name) => DropdownMenuItem(
            value: _collectionFilter(name),
            child: Text(name),
          ),
        ),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _selectedFilter = value);
      },
    );
  }

  /// Toggles one favorite marker and reports a recoverable storage failure.
  Future<void> _toggleFavorite(StoryBook story) async {
    try {
      await ref.read(storyControllerProvider).toggleFavorite(story.id);
    } on Exception {
      if (mounted) _showError();
    }
  }

  /// Requires parent access before replacing one story's collection labels.
  Future<void> _manageCollections(BuildContext context, StoryBook story) async {
    final hasAccess = await requestParentAccess(context, ref);
    if (!hasAccess || !context.mounted) return;
    final collections = await showStoryCollectionsDialog(
      context,
      story.collections,
    );
    if (collections == null || !context.mounted) return;
    try {
      await ref
          .read(storyControllerProvider)
          .setCollections(story.id, collections);
    } on Exception {
      if (mounted) _showError();
    }
  }

  /// Requires explicit confirmation before permanent local story deletion.
  Future<void> _confirmDelete(BuildContext context, StoryBook story) async {
    final hasAccess = await requestParentAccess(context, ref);
    if (!hasAccess || !context.mounted) return;
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

  /// Shows generic local persistence feedback without exposing family data.
  void _showError() {
    final text = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
  }

  /// Returns names in deterministic case-insensitive display order.
  List<String> _collectionNames(List<StoryBook> stories) {
    final names = stories.expand((story) => story.collections).toSet().toList();
    names.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return names;
  }

  /// Filters approved stories by one special or collection selector value.
  List<StoryBook> _filteredStories(List<StoryBook> stories, String filter) {
    if (filter == _allFilter) return stories;
    if (filter == _favoritesFilter) {
      return stories.where((story) => story.isFavorite).toList(growable: false);
    }
    final collection = filter.substring('collection:'.length);
    return stories
        .where((story) => story.collections.contains(collection))
        .toList(growable: false);
  }

  /// Namespaces a collection label away from the two special filter values.
  String _collectionFilter(String name) => 'collection:$name';
}

/// Empty result for a favorite or collection filter without approved stories.
class _FilteredShelfEmpty extends StatelessWidget {
  /// Creates a compact filtered empty state.
  const _FilteredShelfEmpty();

  @override
  /// Keeps filtering emptiness distinct from a profile with no stories.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text.noStoriesInFilter, textAlign: TextAlign.center),
      ),
    );
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
