/// The one line each Settings row says about what is currently true.
///
/// Every rule lives here rather than inside the rows, so the sentence a parent
/// reads on the root list is decided from stored state alone and can be
/// asserted without a screen around it. Nothing in this file asks the PC a
/// question: the root list must open without a network call, which is why the
/// PC row names the pairing and the last sync it already has and leaves the
/// PC's own device list to the page that reads it.
///
/// A summary that is still loading is [pendingSummary] rather than a guess, so
/// a device is never told it is on the demo before the saved selection is read.
library;

import 'package:intl/intl.dart';
import 'package:miko_hero/core/models/app_language.dart';
import 'package:miko_hero/core/models/child_profile.dart';
import 'package:miko_hero/core/models/child_story_preferences.dart';
import 'package:miko_hero/core/security/parent_security.dart';
import 'package:miko_hero/features/settings/ai_connection_controller.dart';
import 'package:miko_hero/features/settings/library_sync_controller.dart';
import 'package:miko_hero/l10n/app_localizations.dart';
import 'package:miko_hero/shared/app_language_dropdown.dart';
import 'package:miko_hero/shared/reading_comfort_controls.dart';

/// Placeholder printed while the state a summary needs is still loading.
const pendingSummary = '…';

/// Separator between the parts of one summary line.
const _separator = ' · ';

/// What the Family row says: how many heroes, and which interface language.
String familySummary(
  AppLocalizations text,
  List<ChildProfile> profiles,
  AppLanguage language,
) {
  return <String>[
    text.profileCount(profiles.length),
    appLanguageName(text, language),
  ].join(_separator);
}

/// What the Reading row says: the saved prose size, and the easy-reading font.
///
/// Both parts are per child, so a family whose children disagree is told they
/// disagree instead of being shown one child's answer as everybody's.
String readingSummary(AppLocalizations text, List<ChildProfile> profiles) {
  if (profiles.isEmpty) return text.settingsNoHeroes;
  final sizes = profiles
      .map((profile) => profile.readingSettings.textSize)
      .toSet();
  final sizeLabel = sizes.length == 1
      ? readerTextSizeLabel(text, sizes.single)
      : text.settingsReadingMixed;
  final easyReaders = profiles
      .where((profile) => profile.readingSettings.easyReadingFont)
      .length;
  final easyLabel = switch (easyReaders) {
    0 => text.settingsReadingEasyOff,
    _ when easyReaders == profiles.length => text.settingsReadingEasyOn,
    _ => text.settingsReadingEasySome,
  };
  return <String>[
    text.settingsReadingTextSizeValue(sizeLabel),
    easyLabel,
  ].join(_separator);
}

/// What The PC row says: the generator, the pairing, and the last sync.
///
/// A device on the demo says only that: an address, a pairing and a sync are
/// all meaningless until the family has chosen the PC.
String pcSummary(
  AppLocalizations text, {
  required AiConnectionState? connection,
  required LibrarySyncSnapshot? sync,
  required String localeName,
}) {
  if (connection == null) return pendingSummary;
  if (!connection.usesLocalAi) return text.settingsPcDemo;
  if (!connection.isPaired) return text.settingsPcNotPaired;
  return <String>[
    text.settingsPcPaired,
    _lastSyncSummary(text, sync, localeName),
  ].join(_separator);
}

/// What the Safety row says: the parent PIN, and how many topics are avoided.
///
/// The topics are counted as a union across the family: a topic one child is
/// kept away from is a topic this device avoids.
String safetySummary(
  AppLocalizations text, {
  required ParentAccessState? access,
  required List<ChildProfile> profiles,
}) {
  if (access == null) return pendingSummary;
  final excluded = <SafetyTopic>{
    for (final profile in profiles) ...profile.storyPreferences.excludedTopics,
  };
  return <String>[
    access.isConfigured ? text.settingsSafetyPinOn : text.settingsSafetyPinOff,
    text.safetyRulesValue(excluded.length),
  ].join(_separator);
}

/// What the Your data row says: how much of the family is on this device.
String dataSummary(AppLocalizations text, int storyCount) {
  return text.settingsDataSummary(storyCount);
}

/// Names the last sync in the local time zone, or says there has not been one.
String _lastSyncSummary(
  AppLocalizations text,
  LibrarySyncSnapshot? sync,
  String localeName,
) {
  final lastSyncedAtUtc = sync?.lastSyncedAtUtc;
  if (lastSyncedAtUtc == null) return text.settingsPcNeverSynced;
  final moment = DateFormat.yMMMd(
    localeName,
  ).add_jm().format(lastSyncedAtUtc.toLocal());
  return text.settingsPcSyncedAt(moment);
}
