import 'dart:convert';
import 'dart:ui';

import 'package:miko_hero/core/ai_connection/ai_connection_settings.dart';
import 'package:miko_hero/core/ai_connection/bridge_credential.dart';
import 'package:miko_hero/core/ai_connection/library_sync_state.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/app_state.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/generation_job.dart';
import 'package:miko_hero/core/models/story_models.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/core/storage/bridge_credential_storage.dart';
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
  LocalRepository._(this._preferences, this._bridgeCredentialStorage);

  static const _localeKey = 'app_locale';
  static const _legacyProfileKey = 'daughter_profile';
  static const _profilesKey = 'child_profiles';
  static const _storiesKey = 'story_library';
  static const _activeProfileKey = 'active_profile_id';
  static const _parentSecurityKey = 'parent_security';
  static const _generationJobsKey = 'generation_jobs';
  static const _schemaVersionKey = 'schema_version';
  static const _aiConnectionKey = 'ai_connection';
  static const _bridgeDeviceKey = 'bridge_device';
  static const _librarySyncKey = 'library_sync';

  /// Keys that a backup restore replaces as one all-or-nothing group.
  static const _restoredKeys = <String>[
    _localeKey,
    _profilesKey,
    _storiesKey,
    _activeProfileKey,
    _legacyProfileKey,
    _generationJobsKey,
    _schemaVersionKey,
  ];

  final SharedPreferences _preferences;
  final BridgeCredentialStorage _bridgeCredentialStorage;

  /// Opens the platform-backed preferences store used by this device.
  static Future<LocalRepository> open({
    BridgeCredentialStorage bridgeCredentialStorage =
        const SecureBridgeCredentialStorage(),
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return LocalRepository._(preferences, bridgeCredentialStorage);
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
        legacyProfileId: fallbackProfileId,
      );
      final state = AppState.validated(
        locale: _readLocale(),
        profiles: profiles,
        stories: _readStories(
          fallbackProfileId: fallbackProfileId,
          fallbackGender: fallbackGender,
        ),
        activeProfileId: activeProfileId,
      );
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

  /// Schema version of the values on this device; absent storage is version 1.
  ///
  /// Reserved for future on-device migrations: readers must tolerate any
  /// version this build accepts rather than assume the newest one.
  int get storedSchemaVersion {
    return _preferences.getInt(_schemaVersionKey) ??
        minimumAppStateSchemaVersion;
  }

  /// Persists the complete ordered profile list as one preference value.
  Future<void> saveProfiles(List<ChildProfile> profiles) async {
    final encodedProfiles = profiles
        .map((profile) => profile.toJson())
        .toList();
    await _preferences.setString(_profilesKey, jsonEncode(encodedProfiles));
    await _markSchemaVersion();
  }

  /// Persists the complete ordered library as one atomic preference value.
  Future<void> saveStories(List<StoryBook> stories) async {
    final encodedStories = stories.map((story) => story.toJson()).toList();
    await _preferences.setString(_storiesKey, jsonEncode(encodedStories));
    await _markSchemaVersion();
  }

  /// Persists the profile currently controlling the application color palette.
  Future<void> saveActiveProfileId(String profileId) async {
    await _preferences.setString(_activeProfileKey, profileId);
  }

  /// Reads and validates pending generation requests in oldest-first order.
  Future<List<GenerationJob>> readGenerationJobs() async {
    final encodedJobs = _preferences.getString(_generationJobsKey);
    if (encodedJobs == null) return const <GenerationJob>[];
    try {
      final decodedJobs = jsonDecode(encodedJobs);
      if (decodedJobs is! List) {
        throw const FormatException('Generation jobs must be a list.');
      }
      final jobs = decodedJobs.map(_decodeGenerationJob).toList();
      final identities = jobs.map((job) => job.id).toSet();
      if (identities.length != jobs.length) {
        throw const FormatException(
          'Generation job identities must be unique.',
        );
      }
      jobs.sort((left, right) => left.createdAt.compareTo(right.createdAt));
      return List<GenerationJob>.unmodifiable(jobs);
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Persists the complete pending generation queue as one local value.
  Future<void> saveGenerationJobs(List<GenerationJob> jobs) async {
    final encodedJobs = jobs.map((job) => job.toJson()).toList();
    await _preferences.setString(_generationJobsKey, jsonEncode(encodedJobs));
  }

  /// Replaces every family and locale value after a backup is fully validated.
  ///
  /// All-or-nothing: a write that fails part way through is rolled back to the
  /// values captured before the restore started and then rethrown, so a
  /// half-restored device never fails startup validation.
  Future<void> replaceState(AppState restoredState) async {
    final previousValues = _snapshotRestoredKeys();
    try {
      await saveLocale(restoredState.locale);
      await saveProfiles(restoredState.profiles);
      await saveStories(restoredState.stories);
      final activeProfileId = restoredState.activeProfileId;
      if (activeProfileId == null) {
        await _preferences.remove(_activeProfileKey);
      } else {
        await saveActiveProfileId(activeProfileId);
      }
      await _preferences.remove(_legacyProfileKey);
      await _preferences.remove(_generationJobsKey);
      await _markSchemaVersion();
    } catch (error, stackTrace) {
      await _rollBack(previousValues);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Reads the optional local parent-PIN verifier without exposing the PIN.
  Future<ParentSecurityRecord?> readParentSecurity() async {
    final encodedRecord = _preferences.getString(_parentSecurityKey);
    if (encodedRecord == null) return null;
    try {
      return ParentSecurityRecord.fromJson(_jsonObject(encodedRecord));
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Persists a salted parent-PIN verifier on the current device only.
  Future<void> saveParentSecurity(ParentSecurityRecord record) async {
    await _preferences.setString(
      _parentSecurityKey,
      jsonEncode(record.toJson()),
    );
  }

  /// Disables the optional local parent PIN without changing family data.
  Future<void> removeParentSecurity() async {
    await _preferences.remove(_parentSecurityKey);
  }

  /// Reads the generator mode and PC bridge address chosen on this device.
  ///
  /// A device that has never opened the AI connection card reads the offline
  /// demo and the loopback address, so first launch needs no stored value.
  Future<AiConnectionSettings> readAiConnectionSettings() async {
    final encodedSettings = _preferences.getString(_aiConnectionKey);
    if (encodedSettings == null) return defaultAiConnectionSettings();
    try {
      return AiConnectionSettings.fromJson(_jsonObject(encodedSettings));
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Persists the parent's generator mode and bridge address.
  Future<void> saveAiConnectionSettings(AiConnectionSettings settings) async {
    await _preferences.setString(
      _aiConnectionKey,
      jsonEncode(settings.toJson()),
    );
  }

  /// Reads this device's pairing token record, absent until it is paired.
  ///
  /// Kept out of the backup-restore key group for the same reason as the
  /// parent PIN: a token belongs to one device and its PC, not to a family
  /// snapshot that travels between devices.
  Future<BridgeCredential?> readBridgeCredential() async {
    try {
      final secureCredential = await _bridgeCredentialStorage.read();
      if (secureCredential != null) {
        final credential = BridgeCredential.fromJson(
          _jsonObject(secureCredential),
        );
        await _preferences.remove(_bridgeDeviceKey);
        return credential;
      }
      final legacyCredential = _preferences.getString(_bridgeDeviceKey);
      if (legacyCredential == null) return null;
      final credential = BridgeCredential.fromJson(
        _jsonObject(legacyCredential),
      );
      await _bridgeCredentialStorage.write(legacyCredential);
      await _preferences.remove(_bridgeDeviceKey);
      return credential;
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Persists the bearer token issued by the PC at pairing time.
  Future<void> saveBridgeCredential(BridgeCredential credential) async {
    await _bridgeCredentialStorage.write(jsonEncode(credential.toJson()));
    await _preferences.remove(_bridgeDeviceKey);
  }

  /// Forgets this device's pairing locally without contacting the PC.
  Future<void> removeBridgeCredential() async {
    await _bridgeCredentialStorage.delete();
    await _preferences.remove(_bridgeDeviceKey);
  }

  /// Reads what this device already took from the PC master library.
  ///
  /// A device that never synced reads an empty record, which is also the
  /// recovery path the bridge contract expects: with no notes, one manifest is
  /// enough to work out everything that is missing.
  Future<LibrarySyncState> readLibrarySyncState() async {
    final encodedState = _preferences.getString(_librarySyncKey);
    if (encodedState == null) return const LibrarySyncState();
    try {
      return LibrarySyncState.fromJson(_jsonObject(encodedState));
    } on FormatException catch (error) {
      throw LocalDataFormatException(error);
    }
  }

  /// Persists the synchronization record after a sync applied its downloads.
  ///
  /// Kept out of the backup-restore key group like the pairing token: a
  /// watermark and a not-wanted-offline list describe one device's shelf
  /// space, not family content that should travel between devices.
  Future<void> saveLibrarySyncState(LibrarySyncState syncState) async {
    await _preferences.setString(
      _librarySyncKey,
      jsonEncode(syncState.toJson()),
    );
  }

  /// Permanently removes every Iam - hero family value from this device.
  ///
  /// The synchronization record goes with the stories it describes: a device
  /// whose library was deleted must be able to sync it back, which a stale
  /// not-wanted-offline list would silently prevent.
  Future<void> clearAll() async {
    await Future.wait(<Future<bool>>[
      _preferences.remove(_legacyProfileKey),
      _preferences.remove(_profilesKey),
      _preferences.remove(_storiesKey),
      _preferences.remove(_activeProfileKey),
      _preferences.remove(_generationJobsKey),
      _preferences.remove(_librarySyncKey),
    ]);
  }

  /// Copies every restore-owned value, using null for keys that are absent.
  Map<String, Object?> _snapshotRestoredKeys() {
    return <String, Object?>{
      for (final key in _restoredKeys) key: _preferences.get(key),
    };
  }

  /// Best-effort return to the pre-restore values of the replaced keys.
  ///
  /// Swallows its own failures so the caller always sees the original write
  /// error instead of a secondary rollback error.
  Future<void> _rollBack(Map<String, Object?> previousValues) async {
    for (final entry in previousValues.entries) {
      try {
        final value = entry.value;
        if (value == null) {
          await _preferences.remove(entry.key);
        } else if (value is int) {
          await _preferences.setInt(entry.key, value);
        } else {
          await _preferences.setString(entry.key, value as String);
        }
      } on Exception {
        continue;
      }
    }
  }

  /// Records the schema that produced the values currently on this device.
  Future<void> _markSchemaVersion() async {
    if (storedSchemaVersion == appStateSchemaVersion) return;
    await _preferences.setInt(_schemaVersionKey, appStateSchemaVersion);
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

  /// Validates one entry from the durable generation queue schema.
  GenerationJob _decodeGenerationJob(Object? encodedJob) {
    if (encodedJob is! Map<String, Object?>) {
      throw const FormatException('Malformed generation job entry.');
    }
    return GenerationJob.fromJson(encodedJob);
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
  String? _readActiveProfileId({String? legacyProfileId}) {
    final activeProfileId = _preferences.getString(_activeProfileKey);
    return activeProfileId ?? legacyProfileId;
  }
}
