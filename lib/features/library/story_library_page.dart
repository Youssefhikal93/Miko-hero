import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/app/app_theme.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/features/kingdom/kingdom_decorations.dart';
import 'package:miko_hero/features/library/shelf_view.dart';
import 'package:miko_hero/features/library/story_collections_dialog.dart';
import 'package:miko_hero/features/library/story_delete_actions.dart';
import 'package:miko_hero/features/library/story_illustrate_actions.dart';
import 'package:miko_hero/features/library/story_share_actions.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/story_creation/story_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/accent_choice_chip.dart';
import 'package:miko_hero/shared/app_icons.dart';
import 'package:miko_hero/shared/app_state_boundary.dart';
import 'package:miko_hero/shared/empty_state.dart';
import 'package:miko_hero/shared/hero_face.dart';
import 'package:miko_hero/shared/hero_label.dart';
import 'package:miko_hero/shared/parent_gated_action.dart';
import 'package:miko_hero/shared/screen_layout.dart';
import 'package:miko_hero/shared/story_card.dart';

/// Query parameter naming the child whose shelf the library opens on.
const String libraryChildQueryParameter = 'child';

/// Route that opens the shelf already showing the books of [profileId].
String libraryRouteForChild(String profileId) {
  return Uri(
    path: '/library',
    queryParameters: <String, String>{libraryChildQueryParameter: profileId},
  ).toString();
}

/// The shelf: every approved book, one child at a time.
class StoryLibraryPage extends ConsumerWidget {
  /// Creates the routed library destination.
  const StoryLibraryPage({this.profileId, super.key});

  /// Child the route asked for, absent when the shelf was opened plainly.
  final String? profileId;

  @override
  /// Rebuilds immediately after local generation or deletion changes a shelf.
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return AppStateBoundary(
      state: state,
      builder: (snapshot) =>
          _Shelf(state: snapshot, requestedProfileId: profileId),
    );
  }
}

/// Loaded shelf content independent from persistence state plumbing.
class _Shelf extends ConsumerStatefulWidget {
  /// Creates the shelf from one immutable application snapshot.
  const _Shelf({required this.state, required this.requestedProfileId});

  final AppState state;
  final String? requestedProfileId;

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
  String? _tappedProfileId;
  ShelfFilter _filter = const AllStories();
  String _query = '';

  @override
  /// Discards the search text with the screen.
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  /// Composes the header, the two chip rows, and the mosaic beneath them.
  ///
  /// Every question about what to show is answered once by [ShelfView.resolve];
  /// this method only lays the answer out.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    final view = ShelfView.resolve(
      profiles: widget.state.profiles,
      stories: widget.state.stories,
      filter: _filter,
      query: _query,
      requestedProfileId: widget.requestedProfileId,
      activeProfileId: widget.state.activeProfileId,
      tappedProfileId: _tappedProfileId,
    );
    final profile = view.profile;
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
              profiles: widget.state.profiles,
              selectedProfileId: profile.id,
              onSelected: (profileId) =>
                  setState(() => _tappedProfileId = profileId),
            ),
            const SizedBox(height: 12),
            _FilterChips(
              accent: Color(profile.themeColorValue),
              collections: view.collections,
              selectedFilter: view.filter,
              storyCount: view.matchingCount,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
            const SizedBox(height: 18),
            if (!view.hasBooks)
              _EmptyShelf(text: text)
            else if (view.stories.isEmpty)
              _NoMatchingStories(isSearching: _query.trim().isNotEmpty)
            else
              _ShelfMosaic(stories: view.stories),
          ],
        ],
      ),
    );
  }
}

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
                icon: const Icon(AppIcons.factCheck),
                label: Text(text.reviewDraftCount(draftCount)),
              ),
            OutlinedButton.icon(
              onPressed: () => importStoryFile(context, ref, state: state),
              icon: const Icon(AppIcons.import),
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
        prefixIcon: const Icon(AppIcons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: text.clearStorySearch,
                icon: const Icon(AppIcons.close),
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
    return AccentChoiceChip(
      key: ValueKey<String>('shelf-child-${profile.id}'),
      selected: selected,
      onSelected: onSelected,
      accent: accent,
      avatar: HeroFace(
        profile: profile,
        size: 28,
        accent: accent,
        background: accent.withValues(alpha: 0.22),
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(context.heroDisplayLabel(profile)),
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
  final ShelfFilter selectedFilter;
  final int storyCount;
  final ValueChanged<ShelfFilter> onSelected;

  @override
  /// Counts the books the All chip would show, search included.
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _chip(
          filter: const AllStories(),
          label: text.allStoriesCount(storyCount),
        ),
        _chip(
          filter: const FavoriteStories(),
          label: text.favoriteStories,
          icon: AppIcons.notFavourite,
        ),
        for (final collection in collections)
          _chip(filter: StoriesInCollection(collection), label: collection),
      ],
    );
  }

  /// Builds one filter chip in the selected child's accent.
  Widget _chip({
    required ShelfFilter filter,
    required String label,
    IconData? icon,
  }) {
    final selected = filter == selectedFilter;
    return AccentChoiceChip(
      key: ValueKey<String>('shelf-filter-${_filterKey(filter)}'),
      selected: selected,
      onSelected: () => onSelected(filter),
      accent: accent,
      avatar: icon == null
          ? null
          : Icon(icon, size: 16, color: selected ? accent : AppTheme.muted),
      label: Text(label),
    );
  }
}

/// Stable widget key for one filter chip.
///
/// Deliberately a presentation detail rather than part of [ShelfFilter]: two
/// chips can only share a key when a collection is literally named `all`,
/// `favorites`, or `collection:something`, which costs a repaint and nothing
/// else, where the encoded filter value this replaced lost the difference
/// outright and showed the wrong books.
String _filterKey(ShelfFilter filter) {
  return switch (filter) {
    AllStories() => 'all',
    FavoriteStories() => 'favorites',
    StoriesInCollection(:final name) => 'collection:$name',
  };
}

/// Columns the book at [index] covers on a shelf mosaic of [columns] columns.
///
/// The newest book takes the whole width; every other book is a full-width row
/// on a phone, where a third of the screen would leave no room for a title, and
/// one of three columns in a desktop window. The count comes from the mosaic
/// itself, so the shelf never has to guess how wide it turned out.
int shelfTileSpan(int index, int columns) {
  if (index == 0) return columns;
  return columns == 3 ? 1 : 2;
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
  /// Shapes each tile from the column count the mosaic resolved for itself.
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(aiConnectionControllerProvider).value;
    return MosaicGrid.builder(
      tiles: (columns) => <MosaicTile>[
        for (var index = 0; index < stories.length; index++)
          MosaicTile(
            span: shelfTileSpan(index, columns),
            child: StoryCard(
              story: stories[index],
              variant: index == 0
                  ? StoryCardVariant.large
                  : StoryCardVariant.wide,
              actions: _actionsFor(context, ref, stories[index], connection),
            ),
          ),
      ],
    );
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
  final messenger = ScaffoldMessenger.of(context);
  final text = AppLocalizations.of(context);
  try {
    await ref.read(storyControllerProvider).toggleFavorite(story.id);
  } on Exception {
    reportActionOutcome(messenger, text.somethingWentWrong);
  }
}

/// Requires parent access before replacing one story's collection labels.
Future<void> _manageCollections(
  BuildContext context,
  WidgetRef ref,
  StoryBook story,
) {
  return runParentGatedAction<List<String>, void>(
    context,
    ref,
    confirm: (context) =>
        showStoryCollectionsDialog(context, story.collections),
    run: (context, collections) =>
        ref.read(storyControllerProvider).setCollections(story.id, collections),
    // The labels the parent just chose are back on the card already.
    report: (text, _) => null,
  );
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
    return EmptyState(
      icon: isSearching ? AppIcons.search : AppIcons.collection,
      title: isSearching ? text.noStoriesMatchSearch : text.noStoriesInFilter,
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
    return EmptyState(
      icon: AppIcons.stories,
      title: text.emptyLibraryTitle,
      body: text.emptyLibraryBody,
      action: FilledButton(
        onPressed: () => context.go('/create'),
        child: Text(text.createFirstStory),
      ),
    );
  }
}
