import 'dart:convert';
import 'dart:ui';

import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reports corrupt device state without silently overwriting family content.
class LocalDataFormatException implements Exception {
  /// Creates an error that retains the precise parsing failure for diagnostics.
  const LocalDataFormatException(this.cause);

  /// Parsing error raised while decoding local JSON.
  final FormatException cause;

  /// Keeps diagnostics concise without exposing stored family content.
  @override
  String toString() => 'Local data is malformed: ${cause.message}';
}

/// Persists private profiles, the interface locale, and story libraries locally.
class LocalRepository {
  /// Wraps one opened preferences instance for atomic repository operations.
  LocalRepository._(this._preferences);

  static const _localeKey = 'app_locale';
  static const _legacyProfileKey = 'daughter_profile';
  static const _profilesKey = 'child_profiles';
  static const _storiesKey = 'story_library';
  static const _activeProfileKey = 'active_profile_id';

  final SharedPreferences _preferences;

  /// Opens the platform-backed preferences store used by this device.
  static Future<LocalRepository> open() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalRepository._(preferences);
  }

  /// Reads and validates a complete application snapshot from local storage.
  Future<AppState> readState() async {
    try {
      final profiles = _readProfiles();
      final fallbackProfileId = _legacyStoryProfileId(profiles);
      final fallbackGender = fallbackProfileId == null
          ? null
          : profiles.single.gender;
      final activeProfileId = _readActiveProfileId(
        profiles,
        legacyProfileId: fallbackProfileId,
      );
      final state = AppState(
        locale: _readLocale(),
        profiles: profiles,
        stories: _readStories(
          fallbackProfileId: fallbackProfileId,
          fallbackGender: fallbackGender,
        ),
        activeProfileId: activeProfileId,
      );
      _validateStoryProfiles(state);
      if (fallbackProfileId != null) {
        await _finishLegacyProfileMigration(
          profiles,
          state.stories,
          activeProfileId,
        );
      }
      return state;
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Saves the selected interface locale before the UI commits the change.
  Future<void> saveLocale(Locale locale) async {
    await _preferences.setString(_localeKey, locale.languageCode);
  }

  /// Persists the complete ordered profile list as one preference value.
  Future<void> saveProfiles(List<ChildProfile> profiles) async {
    final encodedProfiles = profiles
        .map((profile) => profile.toJson())
        .toList();
    await _preferences.setString(_profilesKey, jsonEncode(encodedProfiles));
  }

  /// Persists the complete ordered library as one atomic preference value.
  Future<void> saveStories(List<StoryBook> stories) async {
    final encodedStories = stories.map((story) => story.toJson()).toList();
    await _preferences.setString(_storiesKey, jsonEncode(encodedStories));
  }

  /// Persists the profile currently controlling the application color palette.
  Future<void> saveActiveProfileId(String profileId) async {
    await _preferences.setString(_activeProfileKey, profileId);
  }

  /// Permanently removes every Iam - hero family value from this device.
  Future<void> clearAll() async {
    await Future.wait(<Future<bool>>[
      _preferences.remove(_legacyProfileKey),
      _preferences.remove(_profilesKey),
      _preferences.remove(_storiesKey),
      _preferences.remove(_activeProfileKey),
    ]);
  }

  /// Resolves the saved locale and safely defaults first launch to English.
  Locale _readLocale() {
    final language = AppLanguage.fromCode(_preferences.getString(_localeKey));
    return language.locale;
  }

  /// Decodes current profiles or converts the original singleton payload.
  List<ChildProfile> _readProfiles() {
    final encodedProfiles = _preferences.getString(_profilesKey);
    if (encodedProfiles != null) {
      final decodedProfiles = jsonDecode(encodedProfiles);
      if (decodedProfiles is! List) {
        throw const FormatException('Child profiles must be a list.');
      }
      final profiles = decodedProfiles.map(_decodeChildProfile).toList();
      final uniqueIds = profiles.map((profile) => profile.id).toSet();
      if (uniqueIds.length != profiles.length) {
        throw const FormatException('Child profile identities must be unique.');
      }
      return List<ChildProfile>.unmodifiable(profiles);
    }
    final encodedLegacyProfile = _preferences.getString(_legacyProfileKey);
    if (encodedLegacyProfile == null) return const <ChildProfile>[];
    return <ChildProfile>[
      ChildProfile.fromLegacyJson(_jsonObject(encodedLegacyProfile)),
    ];
  }

  /// Decodes books and returns them newest first for deterministic rendering.
  List<StoryBook> _readStories({
    String? fallbackProfileId,
    ChildGender? fallbackGender,
  }) {
    final encodedStories = _preferences.getString(_storiesKey);
    if (encodedStories == null) {
      return const <StoryBook>[];
    }
    final decodedStories = jsonDecode(encodedStories);
    if (decodedStories is! List) {
      throw const FormatException('Story library must be a list.');
    }
    final stories = decodedStories
        .map(
          (encodedStory) => _decodeStoryBook(
            encodedStory,
            fallbackProfileId: fallbackProfileId,
            fallbackGender: fallbackGender,
          ),
        )
        .toList();
    stories.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return List<StoryBook>.unmodifiable(stories);
  }

  /// Requires decoded JSON to contain an object with string keys.
  Map<String, Object?> _jsonObject(String encodedObject) {
    final decodedObject = jsonDecode(encodedObject);
    if (decodedObject is! Map<String, Object?>) {
      throw const FormatException('Expected a JSON object.');
    }
    return decodedObject;
  }

  /// Validates each library entry before constructing a real story model.
  StoryBook _decodeStoryBook(
    Object? encodedStory, {
    String? fallbackProfileId,
    ChildGender? fallbackGender,
  }) {
    if (encodedStory is! Map<String, Object?>) {
      throw const FormatException('Malformed story library entry.');
    }
    return StoryBook.fromJson(
      encodedStory,
      fallbackProfileId: fallbackProfileId,
      fallbackGender: fallbackGender,
    );
  }

  /// Validates one entry from the current profile list schema.
  ChildProfile _decodeChildProfile(Object? encodedProfile) {
    if (encodedProfile is! Map<String, Object?>) {
      throw const FormatException('Malformed child profile entry.');
    }
    return ChildProfile.fromJson(encodedProfile);
  }

  /// Supplies the sole migrated identity only while old stories lack one.
  String? _legacyStoryProfileId(List<ChildProfile> profiles) {
    if (_preferences.containsKey(_profilesKey) || profiles.length != 1) {
      return null;
    }
    return profiles.single.id;
  }

  /// Commits a successful legacy decode before removing the old preference.
  Future<void> _finishLegacyProfileMigration(
    List<ChildProfile> profiles,
    List<StoryBook> stories,
    String? activeProfileId,
  ) async {
    if (_preferences.containsKey(_profilesKey) ||
        !_preferences.containsKey(_legacyProfileKey)) {
      return;
    }
    await saveStories(stories);
    await saveProfiles(profiles);
    if (activeProfileId != null) {
      await saveActiveProfileId(activeProfileId);
    }
    await _preferences.remove(_legacyProfileKey);
  }

  /// Resolves a valid active identity or adopts the migrated singleton profile.
  String? _readActiveProfileId(
    List<ChildProfile> profiles, {
    String? legacyProfileId,
  }) {
    final activeProfileId = _preferences.getString(_activeProfileKey);
    if (activeProfileId == null) return legacyProfileId;
    if (!profiles.any((profile) => profile.id == activeProfileId)) {
      throw const FormatException('Active child profile does not exist.');
    }
    return activeProfileId;
  }

  /// Rejects stories whose child identity cannot resolve to a saved profile.
  void _validateStoryProfiles(AppState state) {
    for (final story in state.stories) {
      if (state.profileById(story.content.request.profileId) == null) {
        throw const FormatException(
          'Story references an unknown child profile.',
        );
      }
    }
  }
}
