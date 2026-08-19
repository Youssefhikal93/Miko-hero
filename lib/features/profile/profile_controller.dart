import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miko_hero/app/app_controller.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_reading_settings.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/models/kingdom_theme.dart';
import 'package:miko_hero/core/models/reading_badge.dart';
import 'package:miko_hero/core/models/unknown_entity_exception.dart';

/// Supplies profile commands without exposing persistence details to widgets.
final profileControllerProvider = Provider<ProfileController>(
  ProfileController.new,
);

/// Owns child identity, active profile, gender, and per-child theme commands.
class ProfileController {
  /// Retains the provider scope used to access the shared state and repository.
  ProfileController(this._ref);

  final Ref _ref;

  /// Adds a child or updates one while preserving an explicitly chosen color.
  Future<void> saveProfile({
    required String? profileId,
    required ChildProfileDraft draft,
  }) async {
    if (!draft.gender.isSpecified) {
      throw ArgumentError.value(draft.gender, 'gender');
    }
    final current = _currentState;
    final savedProfile = _profileFromDraft(current, profileId, draft);
    final savedProfiles = _upsertProfile(current.profiles, savedProfile);
    await _persistProfiles(current, savedProfiles, savedProfile.id);
  }

  /// Makes one existing child active without modifying their saved settings.
  Future<void> activateProfile(String profileId) async {
    final current = _currentState;
    _requireProfile(current, profileId);
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.saveActiveProfileId(profileId);
    _commit(
      current.withProfiles(current.profiles, savedActiveProfileId: profileId),
    );
  }

  /// Saves an opaque application color only for the identified child.
  Future<void> setThemeColor(String profileId, int themeColorValue) async {
    if (!isValidProfileThemeColorValue(themeColorValue)) {
      throw ArgumentError.value(themeColorValue, 'themeColorValue');
    }
    final current = _currentState;
    final profile = _requireProfile(current, profileId);
    await _saveProfile(current, profile.withThemeColor(themeColorValue));
  }

  /// Saves story defaults and safety boundaries only for one child profile.
  Future<void> setStoryPreferences(
    String profileId,
    ChildStoryPreferences preferences,
  ) async {
    final current = _currentState;
    final profile = _requireProfile(current, profileId);
    final validatedPreferences = ChildStoryPreferences.fromJson(
      preferences.toJson(),
    );
    await _saveProfile(
      current,
      profile.withStoryPreferences(validatedPreferences),
    );
  }

  /// Saves the prose size and easy-reading font of one child's reader.
  Future<void> setReadingSettings(
    String profileId,
    ChildReadingSettings settings,
  ) async {
    final current = _currentState;
    final profile = _requireProfile(current, profileId);
    final validatedSettings = ChildReadingSettings.fromJson(settings.toJson());
    await _saveProfile(current, profile.withReadingSettings(validatedSettings));
  }

  /// Counts one story as finished and reports a badge earned by doing so.
  ///
  /// Returns the badge the child just reached, or null when the story was
  /// already counted or no threshold was crossed, so the reader can celebrate
  /// exactly once. Distinct stories only: re-reading changes nothing.
  Future<ReadingBadge?> recordFinishedStory(
    String profileId,
    String storyId,
  ) async {
    final current = _currentState;
    final profile = _requireProfile(current, profileId);
    final savedProfile = profile.withFinishedStory(storyId);
    if (savedProfile.finishedStoryCount == profile.finishedStoryCount) {
      return null;
    }
    await _saveProfile(current, savedProfile);
    return ReadingBadge.reachedAt(savedProfile.finishedStoryCount);
  }

  /// Drops one story from every child's reward history after it is deleted.
  ///
  /// Keeps badges honest: a story that no longer exists on this device stops
  /// counting for every profile that had finished it.
  Future<void> forgetFinishedStory(String storyId) async {
    final current = _currentState;
    var changed = false;
    final savedProfiles = current.profiles
        .map((profile) {
          final savedProfile = profile.withoutFinishedStory(storyId);
          if (!identical(savedProfile, profile)) changed = true;
          return savedProfile;
        })
        .toList(growable: false);
    if (!changed) return;
    await _persistProfileList(
      current,
      List<ChildProfile>.unmodifiable(savedProfiles),
    );
  }

  /// Saves the castle, frame, backdrop, and symbol of one child's kingdom.
  Future<void> setKingdomTheme(String profileId, KingdomTheme theme) async {
    final current = _currentState;
    final profile = _requireProfile(current, profileId);
    final validatedTheme = KingdomTheme.fromJson(theme.toJson());
    await _saveProfile(current, profile.withKingdomTheme(validatedTheme));
  }

  /// Persists a Girl/Boy choice and activates the selected story hero.
  Future<void> selectProfile(String profileId, ChildGender gender) async {
    if (!gender.isSpecified) throw ArgumentError.value(gender, 'gender');
    final current = _currentState;
    final profile = _requireProfile(current, profileId);
    final savedProfiles = profile.gender == gender
        ? current.profiles
        : _upsertProfile(current.profiles, profile.withGender(gender));
    await _persistProfileSelection(current, savedProfiles, profileId);
  }

  /// Reads the loaded snapshot or preserves the provider's loading error.
  AppState get _currentState {
    return _ref.read(appControllerProvider).requireValue;
  }

  /// Rebuilds a profile from validated form input and its existing palette.
  ChildProfile _profileFromDraft(
    AppState current,
    String? profileId,
    ChildProfileDraft draft,
  ) {
    final existingProfile = profileId == null
        ? null
        : current.profileById(profileId);
    final customTheme = existingProfile?.hasCustomThemeColor ?? false;
    final age = _validatedAge(draft, existingProfile);
    return ChildProfile(
      id: profileId ?? _newProfileId(current.profiles),
      name: draft.name,
      legacyAge: age.years,
      birthDate: age.birthDate,
      photoBase64: draft.photoBase64,
      gender: draft.gender,
      themeColorValue: customTheme
          ? existingProfile!.themeColorValue
          : defaultProfileThemeColorValue(draft.gender),
      hasCustomThemeColor: customTheme,
      storyPreferences:
          existingProfile?.storyPreferences ??
          ChildStoryPreferences(
            defaultLanguage: AppLanguage.fromCode(current.locale.languageCode),
          ),
      kingdomTheme: existingProfile?.kingdomTheme ?? const KingdomTheme(),
    );
  }

  /// Resolves the saved birth date and its current age snapshot.
  ///
  /// A new profile must carry a birth date. Editing a profile stored before
  /// birth dates existed may keep the legacy age until the parent picks one.
  /// Rejects any resolved age outside the supported child range.
  ({DateTime? birthDate, int years}) _validatedAge(
    ChildProfileDraft draft,
    ChildProfile? existingProfile,
  ) {
    final birthDate = draft.birthDate == null
        ? existingProfile?.birthDate
        : childCalendarDay(draft.birthDate!);
    if (birthDate == null) {
      final legacyAge = existingProfile?.legacyAge;
      if (legacyAge == null || !isValidChildAge(legacyAge)) {
        throw ArgumentError.value(draft.birthDate, 'birthDate');
      }
      return (birthDate: null, years: legacyAge);
    }
    final years = childAgeOn(birthDate, DateTime.now());
    if (!isValidChildAge(years)) {
      throw ArgumentError.value(draft.birthDate, 'birthDate');
    }
    return (birthDate: birthDate, years: years);
  }

  /// Persists one changed profile while keeping the active child unchanged.
  Future<void> _saveProfile(AppState current, ChildProfile savedProfile) {
    return _persistProfileList(
      current,
      _upsertProfile(current.profiles, savedProfile),
    );
  }

  /// Persists a complete profile list and publishes it only once stored.
  Future<void> _persistProfileList(
    AppState current,
    List<ChildProfile> savedProfiles,
  ) async {
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.saveProfiles(savedProfiles);
    _commit(
      current.withProfiles(
        savedProfiles,
        savedActiveProfileId: current.activeProfileId,
      ),
    );
  }

  /// Persists profile content and active identity before publishing both.
  Future<void> _persistProfiles(
    AppState current,
    List<ChildProfile> savedProfiles,
    String activeProfileId,
  ) async {
    final repository = await _ref.read(localRepositoryProvider.future);
    await repository.saveProfiles(savedProfiles);
    await repository.saveActiveProfileId(activeProfileId);
    _commit(
      current.withProfiles(
        savedProfiles,
        savedActiveProfileId: activeProfileId,
      ),
    );
  }

  /// Avoids rewriting unchanged profiles while still persisting activation.
  Future<void> _persistProfileSelection(
    AppState current,
    List<ChildProfile> savedProfiles,
    String activeProfileId,
  ) async {
    final repository = await _ref.read(localRepositoryProvider.future);
    if (!identical(savedProfiles, current.profiles)) {
      await repository.saveProfiles(savedProfiles);
    }
    await repository.saveActiveProfileId(activeProfileId);
    _commit(
      current.withProfiles(
        savedProfiles,
        savedActiveProfileId: activeProfileId,
      ),
    );
  }

  /// Rejects commands that reference a profile outside the loaded family.
  ///
  /// Recoverable because a parent can reach it, for example by saving an
  /// editor that was opened before the same profile was deleted.
  ChildProfile _requireProfile(AppState current, String profileId) {
    final profile = current.profileById(profileId);
    if (profile == null) throw const UnknownEntityException('child profile');
    return profile;
  }

  /// Replaces a matching identity or appends a newly created profile.
  List<ChildProfile> _upsertProfile(
    List<ChildProfile> profiles,
    ChildProfile savedProfile,
  ) {
    final savedProfiles = profiles
        .map(
          (profile) => profile.id == savedProfile.id ? savedProfile : profile,
        )
        .toList();
    if (!profiles.any((profile) => profile.id == savedProfile.id)) {
      savedProfiles.add(savedProfile);
    }
    return List<ChildProfile>.unmodifiable(savedProfiles);
  }

  /// Creates a collision-free device-local identity at explicit profile save.
  String _newProfileId(List<ChildProfile> profiles) {
    final timePart = DateTime.now().toUtc().microsecondsSinceEpoch;
    final baseId = 'profile-$timePart';
    var candidateId = baseId;
    var suffix = 1;
    while (profiles.any((profile) => profile.id == candidateId)) {
      candidateId = '$baseId-${suffix++}';
    }
    return candidateId;
  }

  /// Publishes only snapshots whose storage operations have completed.
  void _commit(AppState persistedState) {
    _ref.read(appControllerProvider.notifier).commit(persistedState);
  }
}
