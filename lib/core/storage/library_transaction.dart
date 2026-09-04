import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';
import 'package:miko_hero/core/storage/library_store.dart';

/// Supplies the store the library transaction writes through.
///
/// The device's own repository in the running app; overridden in tests that
/// need a store which refuses a write.
final libraryStoreProvider = FutureProvider<LibraryStore>((ref) {
  return ref.watch(localRepositoryProvider.future);
});

/// Supplies the one seam through which family state is changed and published.
final libraryTransactionProvider = Provider<LibraryTransaction>(
  LibraryTransaction.new,
);

/// Changes the family snapshot as one transaction: persist, then publish.
///
/// Every feature controller used to re-implement the same five steps — read the
/// loaded snapshot, compute the next list, call the matching `save`, rebuild
/// the snapshot, publish — and each copy could drift. Worse, a copy that
/// published before checking anything could leave the screen showing a library
/// that storage never accepted.
///
/// So the order here is fixed and there is only one of it: the mutation is
/// applied to the loaded snapshot, the result goes through [AppState.validated]
/// — which sorts books newest first and refuses duplicate identities, an
/// unknown active child, or a story whose child is gone — and only a snapshot
/// that survived that is written. Publication is last. A failing write
/// therefore publishes nothing and leaves the screen on the snapshot that is
/// still genuinely on the device.
class LibraryTransaction {
  /// Retains the provider scope holding the repository and the app snapshot.
  LibraryTransaction(this._ref);

  final Ref _ref;

  /// Applies one metadata change to a single book, keeping the shelf order.
  ///
  /// Reports a book another screen already deleted as an
  /// [UnknownEntityException], before anything is written, so favourite,
  /// collection, and approval surfaces can show recoverable feedback.
  Future<AppState> updateStory(
    String storyId,
    StoryBook Function(StoryBook story) update,
  ) {
    return mutateStories((stories) {
      var found = false;
      final savedStories = stories
          .map((story) {
            if (story.id != storyId) return story;
            found = true;
            return update(story);
          })
          .toList(growable: false);
      if (!found) throw const UnknownEntityException('story');
      return savedStories;
    });
  }

  /// Replaces the whole library with the list the mutation returns.
  ///
  /// The mutation may return the books in any order; newest-first is enforced
  /// here rather than trusted from the caller.
  Future<AppState> mutateStories(
    List<StoryBook> Function(List<StoryBook> stories) update,
  ) async {
    final current = _currentState;
    final nextState = AppState.validated(
      locale: current.locale,
      profiles: current.profiles,
      stories: update(current.stories),
      activeProfileId: current.activeProfileId,
    );
    final store = await _store();
    await store.saveStories(nextState.stories);
    return _publish(nextState);
  }

  /// Replaces the profile list, optionally activating one child with it.
  ///
  /// Profiles and the active identity are written together and in that order,
  /// because a device that stored an active child it no longer has a profile
  /// for fails snapshot validation on the next launch. A mutation that returns
  /// the very list it was given writes no profiles at all: activating a child
  /// must not rewrite every sibling's photo.
  ///
  /// A null [activeProfileId] keeps whichever child is active now; clearing the
  /// active child happens only through [clearFamilyData] and [replaceState].
  Future<AppState> mutateProfiles(
    List<ChildProfile> Function(List<ChildProfile> profiles) update, {
    String? activeProfileId,
  }) async {
    final current = _currentState;
    final savedProfiles = update(current.profiles);
    final nextState = AppState.validated(
      locale: current.locale,
      profiles: savedProfiles,
      stories: current.stories,
      activeProfileId: activeProfileId ?? current.activeProfileId,
    );
    final store = await _store();
    if (!identical(savedProfiles, current.profiles)) {
      await store.saveProfiles(nextState.profiles);
    }
    if (activeProfileId != null) {
      await store.saveActiveProfileId(activeProfileId);
    }
    return _publish(nextState);
  }

  /// Persists an interface locale before any localized widget rebuilds.
  Future<AppState> setLocale(Locale locale) async {
    final store = await _store();
    await store.saveLocale(locale);
    return _publish(_currentState.withLocale(locale));
  }

  /// Swaps the entire snapshot for a decoded, parent-confirmed backup.
  ///
  /// The one write that does not compute its own next state: the restored
  /// snapshot was already validated when the backup was decoded, and the
  /// repository replaces every restored key all-or-nothing.
  Future<AppState> replaceState(AppState restoredState) async {
    final store = await _store();
    await store.replaceState(restoredState);
    return _publish(restoredState);
  }

  /// Erases every child, book, and queued request, keeping the interface language.
  Future<AppState> clearFamilyData() async {
    final store = await _store();
    await store.clearAll();
    return _publish(_currentState.withoutFamilyData());
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }

  /// Opens the store this device persists its family into.
  Future<LibraryStore> _store() {
    return _ref.read(libraryStoreProvider.future);
  }

  /// Publishes a snapshot that storage has already accepted.
  AppState _publish(AppState persistedState) {
    _ref.read(appControllerProvider.notifier).commit(persistedState);
    return persistedState;
  }
}
