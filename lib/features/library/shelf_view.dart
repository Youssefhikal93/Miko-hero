import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// Which books of one child's shelf the filter chips are asking for.
///
/// A sealed value rather than the encoded string it replaces: the old grammar
/// namespaced a collection label behind a `collection:` prefix, so a label a
/// parent typed as `collection:bedtime` decoded back as the collection
/// `bedtime` and a label typed as `all` could not be told from the All chip.
/// The three cases are const, so two filters standing for the same wish
/// compare equal and the chips can hold them directly.
sealed class ShelfFilter {
  /// Lets every case be a compile-time constant.
  const ShelfFilter();
}

/// Every approved book on the selected child's shelf.
final class AllStories extends ShelfFilter {
  /// Creates the filter the shelf opens on.
  const AllStories();

  @override
  bool operator ==(Object other) => other is AllStories;

  @override
  int get hashCode => (AllStories).hashCode;
}

/// Only the books the child starred.
final class FavoriteStories extends ShelfFilter {
  /// Creates the favorites filter.
  const FavoriteStories();

  @override
  bool operator ==(Object other) => other is FavoriteStories;

  @override
  int get hashCode => (FavoriteStories).hashCode;
}

/// Only the books carrying one collection label.
final class StoriesInCollection extends ShelfFilter {
  /// Creates the filter for the collection called [name].
  const StoriesInCollection(this.name);

  /// The parent-managed label exactly as it is stored on the book.
  final String name;

  @override
  bool operator ==(Object other) {
    return other is StoriesInCollection && other.name == name;
  }

  @override
  int get hashCode => Object.hash(StoriesInCollection, name);
}

/// Everything one build of the shelf shows, decided away from the widgets.
///
/// The page keeps only the three things a tap changes — which child chip was
/// tapped, which filter is selected, and what was typed into the search — and
/// asks for this value once per build. Whose shelf is on screen, which
/// collections that shelf has, whether the selected filter still exists, and
/// which books survive both the search and the filter are decided here, where
/// they can be read in one place and asserted without pumping a widget.
class ShelfView {
  /// Groups one already-resolved shelf; built only by [ShelfView.resolve].
  const ShelfView._({
    required this.profile,
    required this.collections,
    required this.filter,
    required this.stories,
    required this.hasBooks,
    required this.matchingCount,
  });

  /// Resolves one shelf from the whole local library.
  ///
  /// [stories] is the complete library rather than one child's books: the
  /// shelf is a child-facing surface, so keeping only approved books that
  /// belong to the chosen child is one of the decisions this value owns.
  ///
  /// [tappedProfileId], [requestedProfileId], and [activeProfileId] are the
  /// three ways a child can be asked for, in order of how explicit the wish
  /// was — see [profile].
  factory ShelfView.resolve({
    required List<ChildProfile> profiles,
    required List<StoryBook> stories,
    required ShelfFilter filter,
    required String query,
    String? requestedProfileId,
    String? activeProfileId,
    String? tappedProfileId,
  }) {
    final profile = _selectedProfile(
      profiles,
      tappedProfileId: tappedProfileId,
      requestedProfileId: requestedProfileId,
      activeProfileId: activeProfileId,
    );
    final shelf = profile == null
        ? const <StoryBook>[]
        : _shelfOf(stories, profile.id);
    final searched = _searchedStories(shelf, query);
    final collections = _collectionNames(shelf);
    final resolvedFilter = _resolvedFilter(filter, collections);
    return ShelfView._(
      profile: profile,
      collections: collections,
      filter: resolvedFilter,
      stories: _filteredStories(searched, resolvedFilter),
      hasBooks: shelf.isNotEmpty,
      matchingCount: searched.length,
    );
  }

  /// Whose shelf is on screen, or null while the family has no child at all.
  ///
  /// Resolved in order of how explicit the wish was: a chip already tapped,
  /// then the child the route's `child` parameter named, then the child the
  /// family is reading as, and only then the first profile. That is what makes
  /// Home's "See all" land on the shelf it was already showing, without
  /// storing anything new. A child deleted while their shelf was open falls
  /// through to the next candidate instead of leaving the page on a missing
  /// one.
  final ChildProfile? profile;

  /// Collection labels present on that shelf, in display order.
  final List<String> collections;

  /// The filter actually in force, which is [AllStories] whenever the selected
  /// collection has left the shelf.
  final ShelfFilter filter;

  /// The books to lay out: this child's shelf after the search and the filter.
  final List<StoryBook> stories;

  /// Whether the child has any approved book at all, before search or filter.
  ///
  /// Distinct from `stories.isEmpty`, because a shelf that holds books but
  /// answers neither the search nor the filter says something different from
  /// a shelf with no books on it yet.
  final bool hasBooks;

  /// How many books the search left, which is what the All chip counts.
  final int matchingCount;

  /// Keeps the approved books belonging to one child, newest first.
  static List<StoryBook> _shelfOf(List<StoryBook> stories, String profileId) {
    return stories
        .where(
          (story) =>
              story.reviewStatus == StoryReviewStatus.approved &&
              story.content.request.profileId == profileId,
        )
        .toList(growable: false);
  }

  /// Resolves whose shelf is on screen; see [profile] for the precedence.
  static ChildProfile? _selectedProfile(
    List<ChildProfile> profiles, {
    required String? tappedProfileId,
    required String? requestedProfileId,
    required String? activeProfileId,
  }) {
    if (profiles.isEmpty) return null;
    final wanted = <String?>[
      tappedProfileId,
      requestedProfileId,
      activeProfileId,
    ];
    for (final profileId in wanted) {
      if (profileId == null) continue;
      for (final profile in profiles) {
        if (profile.id == profileId) return profile;
      }
    }
    return profiles.first;
  }

  /// Keeps the books whose title carries the searched words.
  ///
  /// Titles only, and case-insensitively: story text is never searched, so
  /// nothing a child reads is scanned to answer a search.
  static List<StoryBook> _searchedStories(
    List<StoryBook> stories,
    String query,
  ) {
    final wanted = query.trim().toLowerCase();
    if (wanted.isEmpty) return stories;
    return stories
        .where((story) => story.content.title.toLowerCase().contains(wanted))
        .toList(growable: false);
  }

  /// Returns names in deterministic case-insensitive display order.
  static List<String> _collectionNames(List<StoryBook> stories) {
    final names = stories.expand((story) => story.collections).toSet().toList();
    names.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return List<String>.unmodifiable(names);
  }

  /// Falls back to all books when the selected collection left the shelf.
  static ShelfFilter _resolvedFilter(
    ShelfFilter filter,
    List<String> collections,
  ) {
    return switch (filter) {
      AllStories() || FavoriteStories() => filter,
      StoriesInCollection(:final name) =>
        collections.contains(name) ? filter : const AllStories(),
    };
  }

  /// Filters already-searched books by the one filter still in force.
  static List<StoryBook> _filteredStories(
    List<StoryBook> stories,
    ShelfFilter filter,
  ) {
    return switch (filter) {
      AllStories() => stories,
      FavoriteStories() =>
        stories.where((story) => story.isFavorite).toList(growable: false),
      StoriesInCollection(:final name) =>
        stories
            .where((story) => story.collections.contains(name))
            .toList(growable: false),
    };
  }
}
