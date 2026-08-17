import 'dart:convert';
import 'dart:ui';

import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/daughter_profile.dart';
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

/// Persists the private profile, interface locale, and story library locally.
class LocalRepository {
  /// Wraps one opened preferences instance for atomic repository operations.
  LocalRepository._(this._preferences);

  static const _localeKey = 'app_locale';
  static const _profileKey = 'daughter_profile';
  static const _storiesKey = 'story_library';

  final SharedPreferences _preferences;

  /// Opens the platform-backed preferences store used by this device.
  static Future<LocalRepository> open() async {
    final preferences = await SharedPreferences.getInstance();
    return LocalRepository._(preferences);
  }

  /// Reads and validates a complete application snapshot from local storage.
  Future<AppState> readState() async {
    try {
      return AppState(
        locale: _readLocale(),
        profile: _readProfile(),
        stories: _readStories(),
      );
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Saves the selected interface locale before the UI commits the change.
  Future<void> saveLocale(Locale locale) async {
    await _preferences.setString(_localeKey, locale.languageCode);
  }

  /// Saves or replaces the one private daughter profile.
  Future<void> saveProfile(DaughterProfile profile) async {
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  /// Persists the complete ordered library as one atomic preference value.
  Future<void> saveStories(List<StoryBook> stories) async {
    final encodedStories = stories.map((story) => story.toJson()).toList();
    await _preferences.setString(_storiesKey, jsonEncode(encodedStories));
  }

  /// Permanently removes every Miko-hero value from this device.
  Future<void> clearAll() async {
    await Future.wait(<Future<bool>>[
      _preferences.remove(_profileKey),
      _preferences.remove(_storiesKey),
    ]);
  }

  /// Resolves the saved locale and safely defaults first launch to English.
  Locale _readLocale() {
    final language = AppLanguage.fromCode(_preferences.getString(_localeKey));
    return language.locale;
  }

  /// Decodes the optional child profile from local JSON.
  DaughterProfile? _readProfile() {
    final encodedProfile = _preferences.getString(_profileKey);
    if (encodedProfile == null) {
      return null;
    }
    return DaughterProfile.fromJson(_jsonObject(encodedProfile));
  }

  /// Decodes books and returns them newest first for deterministic rendering.
  List<StoryBook> _readStories() {
    final encodedStories = _preferences.getString(_storiesKey);
    if (encodedStories == null) {
      return const <StoryBook>[];
    }
    final decodedStories = jsonDecode(encodedStories);
    if (decodedStories is! List) {
      throw const FormatException('Story library must be a list.');
    }
    final stories = decodedStories.map(_decodeStoryBook).toList();
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
  StoryBook _decodeStoryBook(Object? encodedStory) {
    if (encodedStory is! Map<String, Object?>) {
      throw const FormatException('Malformed story library entry.');
    }
    return StoryBook.fromJson(encodedStory);
  }
}
