import 'package:flutter/material.dart';

/// The one icon vocabulary the whole app draws from.
///
/// Every glyph in the interface is named here once, by the thing it means
/// rather than by the picture it happens to be, and every name resolves to a
/// glyph from the single rounded Material family. A screen never writes
/// `Icons.` itself: a concept that shows up on the bottom bar, in an overflow
/// menu, on a settings row and inside a dialog is the same glyph in all four
/// because all four ask for the same name. Two names may share one glyph where
/// two concepts genuinely look alike (illustrating a story and picking a
/// colour are both a palette); one concept never has two glyphs.
///
/// `test/shared/app_icons_test.dart` holds the rule up: it reads every source
/// file under `lib/` and fails on any `Icons.` outside this file.
abstract final class AppIcons {
  // --- The frame: the five destinations and the app's own mark ---

  /// Home, the family's first screen.
  static const IconData home = Icons.home_rounded;

  /// The shelf of a child's approved stories.
  static const IconData shelf = Icons.menu_book_rounded;

  /// A child's Kingdom.
  static const IconData kingdom = Icons.castle_rounded;

  /// The settings screen, and settings anywhere else.
  static const IconData settings = Icons.settings_rounded;

  /// Making something new: the Create destination, the Home tile that opens
  /// it, the button that sends a story request, and the mark on demo artwork.
  static const IconData sparkle = Icons.auto_awesome_rounded;

  /// Asking the PC to fill something in that the parent could also type: the
  /// four spellings of a child's name.
  static const IconData suggest = Icons.auto_fix_high_rounded;

  /// Stories as a body of work: the app's own mark, the About row, an empty
  /// shelf, the first-story reading badge, the Kingdom's book symbol.
  static const IconData stories = Icons.auto_stories_rounded;

  /// Moving forward into a row's own screen.
  static const IconData forward = Icons.chevron_right_rounded;

  /// Leaving a screen the way it was entered.
  static const IconData back = Icons.arrow_back_rounded;

  /// Closing a screen, a search field, or a queued job.
  static const IconData close = Icons.close_rounded;

  /// Anything that went wrong and is worth retrying.
  static const IconData error = Icons.error_outline_rounded;

  /// Asking for the same thing again.
  static const IconData refresh = Icons.refresh_rounded;

  /// Searching a shelf.
  static const IconData search = Icons.search_rounded;

  /// Opening a closed list.
  static const IconData expandMore = Icons.expand_more_rounded;

  /// A closed dropdown menu.
  static const IconData dropdownClosed = Icons.keyboard_arrow_down_rounded;

  /// An open dropdown menu.
  static const IconData dropdownOpen = Icons.keyboard_arrow_up_rounded;

  /// The interface language.
  static const IconData language = Icons.language_rounded;

  /// The chosen entry of a menu.
  static const IconData selectedLanguage = Icons.check_circle_rounded;

  /// A hint that a card can be tapped.
  static const IconData tapHint = Icons.touch_app_rounded;

  /// How stories are read on this device: prose size, letters, reading aloud.
  static const IconData reading = Icons.chrome_reader_mode_rounded;

  /// Everything this device has stored for the family, as one thing to manage.
  static const IconData storedData = Icons.inventory_2_rounded;

  // --- The family ---

  /// A hero, where no photo of the child could be drawn.
  static const IconData hero = Icons.face_rounded;

  /// A hero in a list of heroes to switch between.
  static const IconData heroSilhouette = Icons.person_rounded;

  /// The invitation to set up a first hero.
  static const IconData heroPortrait = Icons.face_retouching_natural_rounded;

  /// Every child profile on this device, together.
  static const IconData heroFamily = Icons.groups_2_rounded;

  /// Adding another child profile.
  static const IconData addHero = Icons.person_add_alt_1_rounded;

  /// Changing a child profile that already exists.
  static const IconData editHero = Icons.edit_rounded;

  /// The hero the story sees as a girl.
  static const IconData girlHero = Icons.face_3_rounded;

  /// The hero the story sees as a boy.
  static const IconData boyHero = Icons.face_6_rounded;

  /// The child whose shelf is showing right now.
  static const IconData activeHero = Icons.check_rounded;

  /// A child's birth date.
  static const IconData birthDate = Icons.event_rounded;

  /// Choosing a photo from the device.
  static const IconData photoLibrary = Icons.photo_library_rounded;

  /// Taking or attaching a first photo.
  static const IconData addPhoto = Icons.add_a_photo_rounded;

  // --- Stories ---

  /// A story a parent has marked a favourite.
  static const IconData favourite = Icons.favorite_rounded;

  /// A story no parent has marked a favourite yet.
  static const IconData notFavourite = Icons.favorite_border_rounded;

  /// A story's collections.
  static const IconData collection = Icons.folder_copy_rounded;

  /// Drawing a story's pictures, and picking a colour: both are the palette.
  static const IconData palette = Icons.palette_rounded;

  /// Asking the PC to illustrate a story.
  static const IconData illustrate = Icons.palette_rounded;

  /// Deleting one story, one draft, or one photo.
  static const IconData delete = Icons.delete_outline_rounded;

  /// Erasing everything this device has stored.
  static const IconData deleteEverything = Icons.delete_forever_rounded;

  /// Every other command a story tile carries.
  static const IconData moreActions = Icons.more_horiz_rounded;

  /// Drafts waiting for a parent to read them.
  static const IconData factCheck = Icons.fact_check_rounded;

  /// Approving a draft so the child can see it.
  static const IconData approveStory = Icons.verified_rounded;

  /// Writing a story out as an encrypted story file.
  static const IconData storyFile = Icons.ios_share_rounded;

  /// Reading a story file back in from another device.
  static const IconData import = Icons.file_open_rounded;

  /// Saving a story as a PDF.
  static const IconData savePdf = Icons.picture_as_pdf_rounded;

  /// What a parent may ask a story to be like.
  static const IconData storyPreferences = Icons.tune_rounded;

  /// Content written by the demo generator rather than by the PC.
  static const IconData demo = Icons.science_rounded;

  // --- The reader ---

  /// The page before this one.
  static const IconData previousPage = Icons.arrow_back_rounded;

  /// The page after this one.
  static const IconData nextPage = Icons.arrow_forward_rounded;

  /// Bedtime mode, on or off.
  static const IconData bedtime = Icons.bedtime_rounded;

  /// Starting or resuming narration.
  static const IconData narrationPlay = Icons.play_arrow_rounded;

  /// Holding narration where it is.
  static const IconData narrationPause = Icons.pause_rounded;

  /// Ending narration.
  static const IconData narrationStop = Icons.stop_rounded;

  /// How fast the narration reads.
  static const IconData narrationSpeed = Icons.speed_rounded;

  /// The timer that stops narration on its own.
  static const IconData sleepTimer = Icons.timer_rounded;

  /// How large the prose is set.
  static const IconData readerTextSize = Icons.text_fields_rounded;

  // --- Reading rewards and Kingdom decorations ---

  /// A reading badge, and the rewards it is counted towards.
  static const IconData readingBadge = Icons.emoji_events_rounded;

  /// The star symbol.
  static const IconData star = Icons.star_rounded;

  /// The rocket symbol.
  static const IconData rocket = Icons.rocket_launch_rounded;

  /// The crown symbol.
  static const IconData crown = Icons.workspace_premium_rounded;

  /// The butterfly symbol.
  static const IconData butterfly = Icons.emoji_nature_rounded;

  /// The dragon symbol.
  static const IconData dragon = Icons.pets_rounded;

  /// The flower symbol.
  static const IconData flower = Icons.local_florist_rounded;

  /// The football symbol.
  static const IconData football = Icons.sports_soccer_rounded;

  /// The music symbol.
  static const IconData music = Icons.music_note_rounded;

  /// The paw symbol.
  static const IconData paw = Icons.cruelty_free_rounded;

  /// The rainbow symbol.
  static const IconData rainbow = Icons.gradient_rounded;

  // --- The PC ---

  /// The bridge on the family PC.
  static const IconData bridge = Icons.hub_rounded;

  /// The local models the bridge writes stories with.
  static const IconData localAi = Icons.memory_rounded;

  /// Writing stories on this device instead of on the PC.
  static const IconData offlineGenerator = Icons.offline_bolt_rounded;

  /// The drawn pictures the PC makes.
  static const IconData illustration = Icons.image_rounded;

  /// One job the PC is working through.
  static const IconData job = Icons.pending_actions_rounded;

  /// Pairing this device with the PC.
  static const IconData pair = Icons.link_rounded;

  /// Forgetting the token this device holds.
  static const IconData forgetDevice = Icons.link_off_rounded;

  /// Ending another paired device's access.
  static const IconData removeDevice = Icons.link_off_rounded;

  /// The device the parent is holding.
  static const IconData thisDevice = Icons.smartphone_rounded;

  /// Another device the PC has paired.
  static const IconData pairedDevice = Icons.devices_rounded;

  /// Checking whether the bridge answers.
  static const IconData testConnection = Icons.monitor_heart_rounded;

  /// The bridge answered.
  static const IconData bridgeAvailable = Icons.check_circle_rounded;

  /// The bridge did not answer.
  static const IconData bridgeUnavailable = Icons.cancel_rounded;

  /// Taking what is new in the master library.
  static const IconData sync = Icons.cloud_sync_rounded;

  /// Asking for stories this device had removed.
  static const IconData redownload = Icons.cloud_download_rounded;

  /// Keeping a typed setting.
  static const IconData save = Icons.save_rounded;

  // --- Parents, backups and privacy ---

  /// The parent-only area, locked.
  static const IconData lock = Icons.lock_rounded;

  /// The parent-only area, opened.
  static const IconData unlock = Icons.lock_open_rounded;

  /// The parent security settings.
  static const IconData parentSecurity = Icons.admin_panel_settings_rounded;

  /// Setting a parent PIN for the first time.
  static const IconData parentPin = Icons.pin_rounded;

  /// Replacing a parent PIN that already exists.
  static const IconData changePin = Icons.password_rounded;

  /// What the app keeps to itself.
  static const IconData privacy = Icons.shield_rounded;

  /// An encrypted backup of the whole library.
  static const IconData backup = Icons.backup_rounded;

  /// Writing a backup out.
  static const IconData export = Icons.file_download_rounded;

  /// Reading a backup back in.
  static const IconData restoreBackup = Icons.settings_backup_restore_rounded;

  /// Fetching a prepared file onto the device.
  static const IconData download = Icons.download_rounded;
}
