import 'dart:ui';

import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';

/// The writes one library transaction performs, and nothing else.
///
/// `LocalRepository` implements this in the running app. The port exists so the
/// transaction's own guarantee — nothing is published unless storage accepted
/// it — can be tested against a store that refuses a write, which a real
/// preferences file on a healthy machine never does.
abstract interface class LibraryStore {
  /// Saves the selected interface locale.
  Future<void> saveLocale(Locale locale);

  /// Saves the complete ordered profile list.
  Future<void> saveProfiles(List<ChildProfile> profiles);

  /// Saves the complete newest-first library.
  Future<void> saveStories(List<StoryBook> stories);

  /// Saves the profile currently controlling the application palette.
  Future<void> saveActiveProfileId(String profileId);

  /// Replaces every restore-owned value as one all-or-nothing group.
  Future<void> replaceState(AppState restoredState);

  /// Removes every family value from this device.
  Future<void> clearAll();
}
