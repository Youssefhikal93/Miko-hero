import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/kingdom/kingdom_decorations.dart';
import 'package:miko_hero/features/library/story_collections_dialog.dart';
import 'package:miko_hero/features/library/story_delete_actions.dart';
import 'package:miko_hero/features/library/story_illustrate_actions.dart';
import 'package:miko_hero/features/library/story_share_actions.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/parent_access_gate.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// The shelf: every approved book, one child at a time.
class StoryLibraryPage extends ConsumerWidget {
  /// Creates the routed library destination.
  const StoryLibraryPage({super.key});

  @override
  /// Rebuilds immediately after local generation or deletion changes a shelf.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) => _Shelf(state: snapshot),
    );
  }
}

/// Loaded shelf content independent from persistence state plumbing.
class _Shelf extends ConsumerStatefulWidget {
  /// Creates the shelf from one immutable application snapshot.
  const _Shelf({required this.state});

  final AppState state;

  @override
  /// Keeps the chosen child, filter, and search across library rebuilds.
  ConsumerState<_Shelf> createState() => _ShelfState();
}

/// Which child, which filter, and which title search the shelf is showing.
///
/// All three are view state only: nothing here is persisted, and none of it
/// survives leaving the destination, exactly as the tab selection it replaces.
class _ShelfState extends ConsumerState<_Shelf> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedProfileId;
  String _selectedFilter = _allFilter;
  String _query = '';

  @override
  /// Discards the search text with the screen.
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  /// Composes the header, the two chip rows, and the mosaic beneath them.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final profiles = widget.state.profiles;
    final profile = _selectedProfile(profiles);
    final shelf = profile == null
        ? const <StoryBook>[]
        : widget.state.storiesForProfile(profile.id);
    final found = _searchedStories(shelf);
    final collections = _collectionNames(shelf);
    final filter = _resolvedFilter(collections);
    final visible = _filteredStories(found, filter);
    return ScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _ShelfHeader(
            state: widget.state,
            controller: _searchController,
            onQueryChanged: (query) => setState(() => _query = query),
          ),
          const SizedBox(height: 20),
          if (profile == null)
            _EmptyShelf(text: text)
          else ...<Widget>[
            _ChildChips(
              profiles: profiles,
              selectedProfileId: profile.id,
              onSelected: (profileId) =>
                  setState(() => _selectedProfileId = profileId),
            ),
            const SizedBox(height: 12),
            _FilterChips(
              accent: Color(profile.themeColorValue),
              collections: collections,
              selectedFilter: filter,
              storyCount: found.length,
              onSelected: (value) => setState(() => _selectedFilter = value),
            ),
            const SizedBox(height: 18),
            if (shelf.isEmpty)
              _EmptyShelf(text: text)
            else if (visible.isEmpty)
              _NoMatchingStories(isSearching: _query.trim().isNotEmpty)
            else
              _ShelfMosaic(stories: visible),
          ],
        ],
      ),
    );
  }

  /// Resolves the chosen child, falling back to the first shelf in the family.
  ///
  /// A child deleted while their shelf was open simply hands the selection
  /// back to the first profile instead of leaving the page on a missing one.
  ChildProfile? _selectedProfile(List<ChildProfile> profiles) {
    if (profiles.isEmpty) return null;
    for (final profile in profiles) {
      if (profile.id == _selectedProfileId) return profile;
    }
    return profiles.first;
  }

  /// Keeps the books whose title carries the searched words.
  ///
  /// Titles only: story text is never searched, so nothing a child reads is
  /// scanned to answer a search.
  List<StoryBook> _searchedStories(List<StoryBook> stories) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return stories;
    return stories
        .where((story) => story.content.title.toLowerCase().contains(query))
        .toList(growable: false);
  }

  /// Falls back to all books when the selected collection left the shelf.
  String _resolvedFilter(List<String> collections) {
    final available = <String>{
      _allFilter,
      _favoritesFilter,
      ...collections.map(_collectionFilter),
    };
    return available.contains(_selectedFilter) ? _selectedFilter : _allFilter;
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
    final collection = filter.substring(_collectionPrefix.length);
    return stories
        .where((story) => story.collections.contains(collection))
        .toList(growable: false);
  }
}

/// Filter value that keeps every book on the selected shelf.
const _allFilter = 'all';

/// Filter value that keeps only the books a child starred.
const _favoritesFilter = 'favorites';

/// Prefix keeping a collection label away from the two special filter values.
const _collectionPrefix = 'collection:';

/// Namespaces one collection label into a filter value.
String _collectionFilter(String name) => '$_collectionPrefix$name';

/// Shelf name, where the books live, and the actions that reach the whole page.
class _ShelfHeader extends ConsumerWidget {
  /// Creates the header around the shared title search field.
  const _ShelfHeader({
    required this.state,
    required this.controller,
    required this.onQueryChanged,
  });

  final AppState state;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  @override
  /// Keeps the review and import actions responsive beside or below the name.
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AppLocalizations.of(context);
    final draftCount = state.draftStories.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 18,
          runSpacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 560,
              child: SectionHeading(
                title: text.libraryTitle,
                subtitle: _whereStoriesLive(text, ref),
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
        ),
        const SizedBox(height: 16),
        _TitleSearchField(
          controller: controller,
          onQueryChanged: onQueryChanged,
        ),
      ],
    );
  }

  /// Says where these books actually are, from the connection this device has.
  ///
  /// A device is only kept in step with the PC while it is both set to Local
  /// AI and paired, which is exactly what the automatic synchronization asks
  /// for, so the sentence never promises a copy the PC would not send.
  String _whereStoriesLive(AppLocalizations text, WidgetRef ref) {
    final connection = ref.watch(aiConnectionControllerProvider).value;
    final synced =
        connection != null && connection.usesLocalAi && connection.isPaired;
    return synced ? text.libraryStoredWithPc : text.librarySubtitle;
  }
}

/// Search field that narrows the visible shelf to matching book titles.
class _TitleSearchField extends StatelessWidget {
  /// Creates the field over the search text the shelf already holds.
  const _TitleSearchField({
    required this.controller,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  @override
  /// Offers a clear control only while there is something to clear.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return TextField(
      key: const ValueKey<String>('shelf-search'),
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onQueryChanged,
      decoration: InputDecoration(
        labelText: text.searchStoryTitles,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: text.clearStorySearch,
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  controller.clear();
                  onQueryChanged('');
                },
              ),
      ),
    );
  }
}

/// One tappable chip per child, selecting whose shelf is on screen.
class _ChildChips extends StatelessWidget {
  /// Creates the chip row in stable persistence order.
  const _ChildChips({
    required this.profiles,
    required this.selectedProfileId,
    required this.onSelected,
  });

  final List<ChildProfile> profiles;
  final String selectedProfileId;
  final ValueChanged<String> onSelected;

  @override
  /// Wraps onto a second line rather than scrolling away on a narrow phone.
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final profile in profiles)
          _ChildChip(
            profile: profile,
            selected: profile.id == selectedProfileId,
            showSymbol: profiles.length > 1,
            onSelected: () => onSelected(profile.id),
          ),
      ],
    );
  }
}

/// One child's chip: their initial, their hero name, and their own accent.
class _ChildChip extends StatelessWidget {
  /// Creates the chip for one child profile.
  const _ChildChip({
    required this.profile,
    required this.selected,
    required this.showSymbol,
    required this.onSelected,
  });

  final ChildProfile profile;
  final bool selected;
  final bool showSymbol;
  final VoidCallback onSelected;

  @override
  /// Carries this child's saved color rather than the active child's accent.
  Widget build(BuildContext context) {
    final accent = Color(profile.themeColorValue);
    return ChoiceChip(
      key: ValueKey<String>('shelf-child-${profile.id}'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      selectedColor: accent.withValues(alpha: 0.18),
      side: BorderSide(color: selected ? accent : AppTheme.hairline),
      avatar: _ChildInitial(profile: profile, accent: accent),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(profile.heroName),
          if (showSymbol) ...<Widget>[
            const SizedBox(width: 6),
            Icon(
              kingdomSymbolIcon(profile.kingdomTheme.symbol),
              size: 16,
              color: accent,
            ),
          ],
        ],
      ),
    );
  }
}

/// The first letter of a child's name on a disc in their own color.
///
/// A letter rather than the saved reference photo, which the kingdom avatar
/// already shows at a size worth decoding: a chip avatar is 32 px, and an
/// initial names the shelf's owner at that size without any image work.
class _ChildInitial extends StatelessWidget {
  /// Creates the initial disc for one child profile.
  const _ChildInitial({required this.profile, required this.accent});

  final ChildProfile profile;
  final Color accent;

  @override
  /// Prints the initial in the child's accent on a wash of the same color.
  Widget build(BuildContext context) {
    return CircleAvatar(
      backgroundColor: accent.withValues(alpha: 0.22),
      child: Text(
        _initial,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: accent,
        ),
      ),
    );
  }

  /// Reads one whole first character, so an emoji name keeps its glyph.
  String get _initial {
    final name = profile.name.trim();
    if (name.isEmpty) return '·';
    return String.fromCharCode(name.runes.first).toUpperCase();
  }
}

/// All, favorites, and one chip per collection label on the selected shelf.
class _FilterChips extends StatelessWidget {
  /// Creates the filter row for one child's shelf.
  const _FilterChips({
    required this.accent,
    required this.collections,
    required this.selectedFilter,
    required this.storyCount,
    required this.onSelected,
  });

  final Color accent;
  final List<String> collections;
  final String selectedFilter;
  final int storyCount;
  final ValueChanged<String> onSelected;

  @override
  /// Counts the books the All chip would show, search included.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _chip(value: _allFilter, label: text.allStoriesCount(storyCount)),
        _chip(
          value: _favoritesFilter,
          label: text.favoriteStories,
          icon: Icons.favorite_border_rounded,
        ),
        for (final collection in collections)
          _chip(value: _collectionFilter(collection), label: collection),
      ],
    );
  }

  /// Builds one filter chip in the selected child's accent.
  Widget _chip({required String value, required String label, IconData? icon}) {
    final selected = value == selectedFilter;
    return ChoiceChip(
      key: ValueKey<String>('shelf-filter-$value'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(value),
      selectedColor: accent.withValues(alpha: 0.18),
      side: BorderSide(color: selected ? accent : AppTheme.hairline),
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? accent : AppTheme.muted),
      label: Text(label),
    );
  }
}

/// The visible books, laid out on the shared mosaic.
///
/// One column on a phone — the newest book on a cover tile and every other
/// book on a full-width row, both large enough to tap at 360 px — and three
/// columns from the desktop breakpoint, where the rows sit three abreast under
/// a full-width cover.
///
/// The one-column cover tile is deliberately not among the shapes used here:
/// it carries no overflow control, so a book placed on one would silently lose
/// favouriting, collections, sharing, illustrating, and both kinds of
/// deletion. Every shape the shelf does use carries that control.
class _ShelfMosaic extends ConsumerWidget {
  /// Creates the mosaic from stories already filtered and searched.
  const _ShelfMosaic({required this.stories});

  final List<StoryBook> stories;

  @override
  /// Chooses each tile's span from the width the shelf actually has.
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(aiConnectionControllerProvider).value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= desktopBreakpoint ? 3 : 2;
        return MosaicGrid(
          tiles: <MosaicTile>[
            for (var index = 0; index < stories.length; index++)
              MosaicTile(
                span: _spanFor(index, columns),
                child: StoryCard(
                  story: stories[index],
                  variant: index == 0
                      ? StoryCardVariant.large
                      : StoryCardVariant.wide,
                  actions: _actionsFor(
                    context,
                    ref,
                    stories[index],
                    connection,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Gives the newest book the whole width and fits the rows to the grid.
  ///
  /// A row is a full-width tile on a phone, where a third of the screen would
  /// leave no room for a title, and one of three columns on a desktop window.
  int _spanFor(int index, int columns) {
    if (index == 0) return columns;
    return columns == 3 ? 1 : 2;
  }

  /// Hands the tile the same commands and the same parent gates as before.
  ///
  /// The picture-making action appears only on books the paired PC actually
  /// holds, so a demo story and an unpaired device simply never show it.
  StoryCardActions _actionsFor(
    BuildContext context,
    WidgetRef ref,
    StoryBook story,
    AiConnectionState? connection,
  ) {
    return StoryCardActions(
      open: () => context.go('/story/${story.id}'),
      delete: () => deleteStoryWithParentGate(context, ref, story),
      favorite: () => _toggleFavorite(context, ref, story),
      collections: () => _manageCollections(context, ref, story),
      share: () => exportStoryFile(context, ref, story),
      illustrate: canIllustrateStory(story, connection)
          ? () => illustrateStoryWithParentGate(context, ref, story)
          : null,
    );
  }
}

/// Toggles one favorite marker and reports a recoverable storage failure.
Future<void> _toggleFavorite(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) async {
  try {
    await ref.read(storyControllerProvider).toggleFavorite(story.id);
  } on Exception {
    if (context.mounted) _showStorageError(context);
  }
}

/// Requires parent access before replacing one story's collection labels.
Future<void> _manageCollections(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) async {
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
    if (context.mounted) _showStorageError(context);
  }
}

/// Shows generic local persistence feedback without exposing family data.
void _showStorageError(BuildContext context) {
  final text = AppLocalizations.of(context);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(text.somethingWentWrong)));
}

/// Empty result for a search or a filter that no book on the shelf answers.
class _NoMatchingStories extends StatelessWidget {
  /// Creates the compact empty state for a shelf that does hold books.
  const _NoMatchingStories({required this.isSearching});

  /// Whether a title search, rather than a filter chip, emptied the shelf.
  final bool isSearching;

  @override
  /// Keeps a fruitless search distinct from a filter with nothing in it.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isSearching ? text.noStoriesMatchSearch : text.noStoriesInFilter,
          textAlign: TextAlign.center,
        ),
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
