// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Iam - hero';

  @override
  String get home => 'Home';

  @override
  String get create => 'Create';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get createFirstStory => 'Create a first story';

  @override
  String get profileIncompleteTitle => 'Add a hero profile';

  @override
  String get profileIncompleteBody =>
      'Add a child\'s name, age, Girl/Boy choice, and reference photo before creating a story.';

  @override
  String get setUpProfile => 'Add a profile';

  @override
  String get readingAs => 'Reading as';

  @override
  String get greetingMorning => 'Good morning.';

  @override
  String get greetingAfternoon => 'Good afternoon.';

  @override
  String get greetingEvening => 'Good evening.';

  @override
  String get greetingNight => 'Good night.';

  @override
  String greetingContinueStory(String title) {
    return '$title is waiting to be finished.';
  }

  @override
  String get greetingDraftsWaiting =>
      'New stories are waiting for a parent to read them.';

  @override
  String get greetingCreateStory =>
      'Tonight\'s story has not been written yet.';

  @override
  String get keepReading => 'Keep reading';

  @override
  String get newStory => 'New story';

  @override
  String readingBadgesEarned(int earned, int total) {
    return '$earned of $total';
  }

  @override
  String draftsWaitingForReview(int count) {
    return 'Drafts waiting for review: $count';
  }

  @override
  String get draftsWaitingHint => 'Parent only · hidden from the shelf';

  @override
  String get onTheShelf => 'On the shelf';

  @override
  String get seeAll => 'See all';

  @override
  String get editProfile => 'Edit hero profile';

  @override
  String get profileTitle => 'Hero profile';

  @override
  String get profilesTitle => 'Hero profiles';

  @override
  String get profilesSubtitle =>
      'Add one private profile for each child who can star in a story.';

  @override
  String get addProfile => 'Add profile';

  @override
  String get manageProfiles => 'Manage hero profiles';

  @override
  String profileCount(int count) {
    return 'Profiles: $count';
  }

  @override
  String get noProfilesTitle => 'No hero profiles yet';

  @override
  String get noProfilesBody =>
      'Add the first child profile to start creating personalized stories.';

  @override
  String get profileIntro =>
      'This child\'s information stays on this device and is never committed to the app\'s source code.';

  @override
  String get childName => 'Child\'s name';

  @override
  String get age => 'Age';

  @override
  String get genderTitle => 'Is this hero a girl or a boy?';

  @override
  String get girl => 'Girl';

  @override
  String get boy => 'Boy';

  @override
  String get genderRequired => 'Choose Girl or Boy.';

  @override
  String get genderNotSet => 'Girl/Boy not selected';

  @override
  String get referencePhoto => 'Reference photo';

  @override
  String get choosePhoto => 'Choose photo';

  @override
  String get replacePhoto => 'Replace photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get nameRequired => 'Enter the child\'s name.';

  @override
  String get ageInvalid => 'Enter an age from 1 to 17.';

  @override
  String get birthDate => 'Birth date';

  @override
  String get chooseBirthDate => 'Choose birth date';

  @override
  String get changeBirthDate => 'Change date';

  @override
  String get birthDateHelper =>
      'The age used in stories updates itself every birthday.';

  @override
  String birthDateLegacyAge(int age) {
    return 'Saved age: $age. Choose a birth date so it stays correct.';
  }

  @override
  String get birthDateRequired => 'Choose the child\'s birth date.';

  @override
  String get photoTooLarge => 'Choose a photo smaller than 2 MB.';

  @override
  String get photoReadFailed => 'The selected photo could not be read.';

  @override
  String get photoRequired => 'Choose a reference photo.';

  @override
  String get createStoryTitle => 'New story';

  @override
  String get whoIsTheHero => 'Who is the hero';

  @override
  String get add => 'Add';

  @override
  String heroAgeGender(int age, String gender) {
    return '$age · $gender';
  }

  @override
  String get whatHappens => 'What happens';

  @override
  String get lessonHint => 'And the lesson it teaches';

  @override
  String get howLong => 'How long';

  @override
  String get pages => 'pages';

  @override
  String get lookAndLanguage => 'Look and language';

  @override
  String get storyLanguageEnglish => 'English';

  @override
  String get storyLanguageArabic => 'العربية';

  @override
  String get storyLanguageSwedish => 'Svenska';

  @override
  String get storyLanguageSomali => 'Soomaali';

  @override
  String get writeTheStory => 'Write the story';

  @override
  String get demoGeneratorLabel => 'Demo';

  @override
  String get localAiGeneratorLabel => 'Local AI';

  @override
  String get profileSelectionRequired => 'Choose which child will be the hero.';

  @override
  String get theme => 'Adventure theme';

  @override
  String get themeHint => 'For example: a moon garden';

  @override
  String get moral => 'Lesson or value';

  @override
  String get pictureBookStyle => 'Picture book';

  @override
  String get watercolorStyle => 'Watercolor';

  @override
  String get threeDStyle => 'Colorful 3D';

  @override
  String get demoModeNotice =>
      'Demo mode creates a clearly marked sample story with no PC and no AI. Switch the story generator to Local AI in settings to write on your family PC.';

  @override
  String get themeRequired => 'Describe the adventure theme.';

  @override
  String get moralRequired => 'Add a lesson or value.';

  @override
  String get generatingTitle => 'Building the adventure';

  @override
  String get generatingBody =>
      'Writing pages and preparing the private local book…';

  @override
  String get storyCreated => 'The story is ready';

  @override
  String get libraryTitle => 'The shelf';

  @override
  String get librarySubtitle => 'Stored only on this device';

  @override
  String get libraryStoredWithPc => 'Synced with the family PC';

  @override
  String get searchStoryTitles => 'Search titles';

  @override
  String get clearStorySearch => 'Clear search';

  @override
  String get emptyLibraryTitle => 'The bookshelf is waiting';

  @override
  String get emptyLibraryBody =>
      'Create a first adventure and it will appear here.';

  @override
  String get openStory => 'Open story';

  @override
  String get delete => 'Delete';

  @override
  String get deleteStoryTitle => 'Delete this story?';

  @override
  String get deleteStoryBody =>
      'The story will be permanently removed from this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirmDelete => 'Delete permanently';

  @override
  String get readStory => 'Read story';

  @override
  String get previousPage => 'Previous';

  @override
  String get nextPage => 'Next';

  @override
  String pageProgress(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get readToMe => 'Read to me';

  @override
  String get playNarration => 'Play narration';

  @override
  String get pauseNarration => 'Pause narration';

  @override
  String get resumeNarration => 'Continue narration';

  @override
  String get stopNarration => 'Stop narration';

  @override
  String get narrationUnavailable =>
      'No compatible voice is installed for this language.';

  @override
  String get settingsTitle => 'Settings and privacy';

  @override
  String get appLanguage => 'App language';

  @override
  String get privacyTitle => 'Local and private';

  @override
  String get privacyBody =>
      'Profile details, photos, and stories stay in local device storage unless you manually export an encrypted backup. No analytics or paid cloud service is used.';

  @override
  String get deleteAllData => 'Delete all local data';

  @override
  String get deleteAllTitle => 'Delete everything?';

  @override
  String get deleteAllBody =>
      'All profiles, photos, and stories will be permanently deleted from this device.';

  @override
  String get allDataDeleted => 'All local data was deleted';

  @override
  String get aboutTitle => 'About Iam - hero';

  @override
  String get aboutBody =>
      'A private family storybook. Stories are written by a local Ollama model and pictures are drawn by ComfyUI, both on your own PC.';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get swedish => 'Swedish';

  @override
  String get somali => 'Somali';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get retry => 'Retry';

  @override
  String get demoBadge => 'DEMO';

  @override
  String yearsOld(int age) {
    return '$age years old';
  }

  @override
  String storyByHero(String name) {
    return 'An adventure starring $name';
  }

  @override
  String get myKingdom => 'My Kingdom';

  @override
  String get kingdomTitle => 'My Kingdom';

  @override
  String get kingdomSubtitle =>
      'Choose a hero, update their profile, and give each child their own app color.';

  @override
  String get activeHero => 'Active hero';

  @override
  String get chooseHero => 'Choose a child';

  @override
  String get editHeroProfile => 'Edit name and profile';

  @override
  String get addAnotherHero => 'Add another hero';

  @override
  String get themeColor => 'Kingdom color';

  @override
  String themeColorHint(String name) {
    return 'This color is saved only for $name\'s profile.';
  }

  @override
  String get goldenTheme => 'Golden';

  @override
  String get roseTheme => 'Rose';

  @override
  String get purpleTheme => 'Purple';

  @override
  String get cyanTheme => 'Cyan';

  @override
  String get greenTheme => 'Green';

  @override
  String get customColor => 'Custom color';

  @override
  String get customColorTitle => 'Choose a custom color';

  @override
  String get hue => 'Color';

  @override
  String get intensity => 'Intensity';

  @override
  String get brightness => 'Brightness';

  @override
  String get applyColor => 'Use this color';

  @override
  String profileThemeSaved(String name) {
    return 'Color saved for $name';
  }

  @override
  String get parentSecurityTitle => 'Parent protection';

  @override
  String get parentSecurityBody =>
      'An optional local PIN protects profiles, My Kingdom, settings, and deletion. It is not a replacement for device security.';

  @override
  String get parentPin => 'Parent PIN';

  @override
  String get parentPinConfigured => 'A parent PIN is enabled on this device.';

  @override
  String get parentPinNotConfigured =>
      'No parent PIN is set. Parent controls are currently open.';

  @override
  String get setParentPin => 'Set parent PIN';

  @override
  String get changeParentPin => 'Change PIN';

  @override
  String get removeParentPin => 'Remove PIN';

  @override
  String get lockParentArea => 'Lock now';

  @override
  String get parentAreaLocked => 'Parent area locked';

  @override
  String get enterParentPin => 'Enter the local parent PIN to continue.';

  @override
  String get incorrectParentPin => 'That PIN is incorrect.';

  @override
  String get unlock => 'Unlock';

  @override
  String get newParentPin => 'New PIN';

  @override
  String get confirmParentPin => 'Confirm PIN';

  @override
  String get parentPinRequirements => 'Use 4 to 8 digits.';

  @override
  String get parentPinMismatch => 'The PINs do not match.';

  @override
  String get saveParentPin => 'Save PIN';

  @override
  String get parentPinSaved => 'Parent PIN saved';

  @override
  String get parentPinRemoved => 'Parent PIN removed';

  @override
  String get removeParentPinTitle => 'Remove parent PIN?';

  @override
  String get removeParentPinBody =>
      'Parent controls will remain open on this device until a new PIN is set.';

  @override
  String parentPinLockedSeconds(int seconds) {
    return 'Too many attempts. Try again in $seconds s.';
  }

  @override
  String parentPinLockedMinutes(int minutes) {
    return 'Too many attempts. Try again in $minutes min.';
  }

  @override
  String get changeParentPinTitle => 'Change parent PIN';

  @override
  String get currentParentPin => 'Current PIN';

  @override
  String get parentPinChanged => 'Parent PIN changed';

  @override
  String get forgotParentPinBody =>
      'There is no PIN recovery. If the PIN is forgotten, the only option is deleting all app data; an encrypted backup then restores the family content, because a backup never contains the PIN.';

  @override
  String get encryptedBackupTitle => 'Encrypted backup';

  @override
  String get encryptedBackupBody =>
      'Save a password-protected file and restore it on another device. The backup password is never stored, so keep it safe.';

  @override
  String get exportEncryptedBackup => 'Export backup';

  @override
  String get restoreEncryptedBackup => 'Restore backup';

  @override
  String get createBackupPasswordTitle => 'Create a backup password';

  @override
  String get enterBackupPasswordTitle => 'Enter the backup password';

  @override
  String get backupPassword => 'Backup password';

  @override
  String get confirmBackupPassword => 'Confirm backup password';

  @override
  String get backupPasswordRequirements =>
      'Use at least 8 characters. This password cannot be recovered.';

  @override
  String get backupPasswordMismatch => 'The backup passwords do not match.';

  @override
  String get continueAction => 'Continue';

  @override
  String get backupReadyTitle => 'Encrypted backup ready';

  @override
  String get backupReadyBody =>
      'Choose Download backup to save the encrypted file.';

  @override
  String get downloadBackup => 'Download backup';

  @override
  String get saveBackupDialogTitle => 'Save encrypted Iam - hero backup';

  @override
  String get backupSaved => 'Encrypted backup saved';

  @override
  String restoreFileName(String name) {
    return 'Selected file: $name';
  }

  @override
  String get confirmRestoreTitle => 'Replace local family data?';

  @override
  String confirmRestoreBody(int profiles, int stories) {
    return 'This backup contains $profiles profiles and $stories stories. Restoring replaces the profiles, stories, active hero, and app language currently on this device.';
  }

  @override
  String get restoreNow => 'Restore now';

  @override
  String get backupRestored => 'Encrypted backup restored';

  @override
  String get backupWrongPassword =>
      'The password is wrong or the backup was changed.';

  @override
  String get backupInvalid => 'This is not a supported Iam - hero backup.';

  @override
  String get backupTooLarge => 'This backup is too large to open safely.';

  @override
  String get backupFileReadFailed => 'The selected backup could not be read.';

  @override
  String get backupFailed => 'The backup action could not be completed.';

  @override
  String get backupNewerVersion =>
      'This backup was created by a newer version of the app.';

  @override
  String get storyPreferencesTitle => 'Story preferences and safety';

  @override
  String storyPreferencesBody(String name) {
    return 'Choose what inspires $name\'s stories and what local AI must avoid.';
  }

  @override
  String get editStoryPreferences => 'Edit story preferences';

  @override
  String get defaultStoryLanguage => 'Default story language';

  @override
  String defaultStoryLanguageValue(String language) {
    return 'Default language: $language';
  }

  @override
  String get favoriteThings => 'Favorite things';

  @override
  String get favoriteThingsHint => 'For example: trains, cats, stars';

  @override
  String favoriteThingsValue(String value) {
    return 'Favorite things: $value';
  }

  @override
  String get recurringWorld => 'Recurring world';

  @override
  String get recurringWorldHint => 'For example: The Golden Cloud Kingdom';

  @override
  String recurringWorldValue(String value) {
    return 'Recurring world: $value';
  }

  @override
  String get safetyControls => 'Topics to avoid';

  @override
  String get safetyControlsHint =>
      'These exclusions will be passed to future local story and image generation.';

  @override
  String safetyRulesValue(int count) {
    return 'Safety exclusions: $count';
  }

  @override
  String get avoidFrighteningContent => 'Frightening content';

  @override
  String get avoidViolence => 'Violence or injury';

  @override
  String get avoidBullying => 'Bullying or exclusion';

  @override
  String get avoidGriefAndLoss => 'Grief or loss';

  @override
  String get savePreferences => 'Save preferences';

  @override
  String storyPreferencesSaved(String name) {
    return 'Story preferences saved for $name';
  }

  @override
  String savedPreferencesInUse(String name, int count) {
    return 'Using $name\'s saved preferences and $count safety exclusions.';
  }

  @override
  String get reviewStoriesTitle => 'Parent story review';

  @override
  String get reviewStoriesBody =>
      'Generated drafts stay out of the child library until you read and approve them.';

  @override
  String get reviewStoryTitle => 'Review this story';

  @override
  String get reviewStoryBody =>
      'Check the request and every page before making the story visible in the library.';

  @override
  String reviewDraftCount(int count) {
    return 'Review drafts ($count)';
  }

  @override
  String get approveStory => 'Approve story';

  @override
  String get storyApproved => 'Story approved and added to the library';

  @override
  String get deleteDraft => 'Delete draft';

  @override
  String get deleteDraftTitle => 'Delete this draft?';

  @override
  String get deleteDraftBody =>
      'This generated draft will be permanently removed from this device.';

  @override
  String reviewHero(String value) {
    return 'Hero: $value';
  }

  @override
  String reviewTheme(String value) {
    return 'Theme: $value';
  }

  @override
  String reviewMoral(String value) {
    return 'Moral: $value';
  }

  @override
  String reviewPageNumber(int number) {
    return 'Page $number';
  }

  @override
  String get noDrafts => 'No stories are waiting for review.';

  @override
  String get moreStoryActions => 'More story actions';

  @override
  String storyPageCount(int count) {
    return '$count pages';
  }

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get manageCollections => 'Manage collections';

  @override
  String collectionsHint(int max) {
    return 'Enter up to $max collection names, separated by commas or new lines.';
  }

  @override
  String get collectionNames => 'Collection names';

  @override
  String get collectionNamesHint => 'Bedtime, Space adventures';

  @override
  String get saveCollections => 'Save collections';

  @override
  String tooManyCollections(int max) {
    return 'Use no more than $max collections.';
  }

  @override
  String collectionNameTooLong(int max) {
    return 'Each collection name must be $max characters or fewer.';
  }

  @override
  String allStoriesCount(int count) {
    return 'All $count';
  }

  @override
  String get favoriteStories => 'Favorites';

  @override
  String get noStoriesInFilter => 'No stories match this filter yet.';

  @override
  String get noStoriesMatchSearch =>
      'No title on this shelf matches that search.';

  @override
  String get generationCenterTitle => 'Local generation center';

  @override
  String get generationCenterBody =>
      'See what works offline now and safely retry requests saved before generation.';

  @override
  String get openGenerationCenter => 'Open generation center';

  @override
  String get generationQueueTitle => 'Saved generation queue';

  @override
  String get generationQueueEmpty => 'No story requests are waiting or failed.';

  @override
  String get demoGeneratorStatus => 'Offline demo generator';

  @override
  String get readyOffline => 'Ready offline';

  @override
  String get ollamaStatus => 'Ollama story model';

  @override
  String get comfyUiStatus => 'ComfyUI illustrations';

  @override
  String get notConnectedYet => 'Not connected yet';

  @override
  String get pcRequirementStatus =>
      'The demo works with the PC switched off. Local AI stories need the PC, its bridge, and its model running; saved books always open offline.';

  @override
  String get generationQueued => 'Queued and saved';

  @override
  String get generationRunning => 'Generating now';

  @override
  String get generationFailed => 'Attempt failed — safe to retry';

  @override
  String get retryGeneration => 'Retry generation';

  @override
  String get cancelGenerationTitle => 'Remove this request?';

  @override
  String get cancelGenerationBody =>
      'The pending request will be removed. Already saved stories are not affected.';

  @override
  String get removeFromQueue => 'Remove from queue';

  @override
  String get exportPdf => 'Save PDF';

  @override
  String get exportPdfDialogTitle => 'Save story as PDF';

  @override
  String get exportingPdf => 'Creating PDF…';

  @override
  String get pdfSaved => 'PDF saved';

  @override
  String get pdfSaveCancelled => 'PDF save cancelled';

  @override
  String get pdfExportFailed => 'Could not save the PDF';

  @override
  String get exportPdfOptionsTitle => 'PDF options';

  @override
  String includePhotoOnCover(String name) {
    return 'Include $name\'s photo on the cover';
  }

  @override
  String get exportPdfPhotoNotice =>
      'A saved PDF is not encrypted and leaves the app.';

  @override
  String pdfForHero(String name) {
    return 'for $name';
  }

  @override
  String pdfBelongsTo(String name) {
    return 'This book belongs to $name';
  }

  @override
  String pdfMadeOn(String date) {
    return 'Made on $date';
  }

  @override
  String pdfPageBadge(int number, int total) {
    return 'Page $number of $total';
  }

  @override
  String get pdfMoralHeading => 'The heart of this story';

  @override
  String get pdfTheEnd => 'The End';

  @override
  String get narrationSettings => 'Narration settings';

  @override
  String get narrationSpeed => 'Reading speed';

  @override
  String get slowSpeed => 'Slow';

  @override
  String get normalSpeed => 'Normal';

  @override
  String get fastSpeed => 'Fast';

  @override
  String get narrationScope => 'Read aloud';

  @override
  String get currentPage => 'Current page';

  @override
  String get remainingStory => 'From this page to the end';

  @override
  String get applyNarrationSettings => 'Apply';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get sleepTimerOff => 'Off';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimerRemaining(int minutes) {
    return 'Narration stops in about $minutes min.';
  }

  @override
  String get kingdomStyleTitle => 'Kingdom style';

  @override
  String kingdomStyleBody(String name) {
    return 'Choose the castle, photo frame, backdrop, and symbol of $name\'s kingdom.';
  }

  @override
  String kingdomStyleSaved(String name) {
    return 'Kingdom style saved for $name';
  }

  @override
  String get kingdomCastle => 'Castle';

  @override
  String get castleClassicTowers => 'Classic towers';

  @override
  String get castleRoundDomes => 'Round domes';

  @override
  String get castleCrystalSpires => 'Crystal spires';

  @override
  String get castleForestTreehouse => 'Forest treehouse';

  @override
  String get kingdomAvatarFrame => 'Photo frame';

  @override
  String get avatarFrameNone => 'Simple circle';

  @override
  String get avatarFrameStars => 'Stars';

  @override
  String get avatarFrameHearts => 'Hearts';

  @override
  String get avatarFrameLaurel => 'Laurel wreath';

  @override
  String get kingdomBackdrop => 'Backdrop';

  @override
  String get backdropNightSky => 'Night sky';

  @override
  String get backdropMeadow => 'Meadow';

  @override
  String get backdropOcean => 'Ocean';

  @override
  String get backdropSunset => 'Sunset';

  @override
  String get kingdomSymbol => 'Favourite symbol';

  @override
  String get symbolStar => 'Star';

  @override
  String get symbolRocket => 'Rocket';

  @override
  String get symbolCrown => 'Crown';

  @override
  String get symbolButterfly => 'Butterfly';

  @override
  String get symbolDragon => 'Dragon';

  @override
  String get symbolFlower => 'Flower';

  @override
  String get symbolFootball => 'Football';

  @override
  String get symbolMusic => 'Music';

  @override
  String get symbolBook => 'Book';

  @override
  String get symbolPaw => 'Paw';

  @override
  String get symbolRainbow => 'Rainbow';

  @override
  String get symbolSparkles => 'Sparkles';

  @override
  String get readingComfortTitle => 'Reading comfort';

  @override
  String readingComfortBody(String name) {
    return 'Choose how story pages look while $name reads.';
  }

  @override
  String get readerTextSize => 'Text size';

  @override
  String get textSizeSmall => 'Small';

  @override
  String get textSizeMedium => 'Medium';

  @override
  String get textSizeLarge => 'Large';

  @override
  String get textSizeExtraLarge => 'Extra large';

  @override
  String get easyReadingFont => 'Easy-reading font';

  @override
  String get easyReadingFontHint =>
      'Uses letter shapes made for reading practice in English, Swedish, and Somali stories. Arabic stories keep their usual letters.';

  @override
  String readingComfortSaved(String name) {
    return 'Reading comfort saved for $name';
  }

  @override
  String get bedtimeMode => 'Bedtime mode';

  @override
  String get turnOffBedtimeMode => 'Turn off bedtime mode';

  @override
  String bedtimeSleepTimerApplied(int minutes) {
    return 'Bedtime mode set a $minutes min sleep timer.';
  }

  @override
  String get readingBadgesTitle => 'Reading badges';

  @override
  String readingBadgesBody(String name) {
    return 'Badges $name earns by finishing stories. No streaks and no daily goals.';
  }

  @override
  String storiesFinished(int count) {
    return 'Stories finished: $count';
  }

  @override
  String get badgeFirstStory => 'First story';

  @override
  String get badgeFiveStories => 'Five stories';

  @override
  String get badgeTenStories => 'Ten stories';

  @override
  String get badgeTwentyFiveStories => 'Twenty-five stories';

  @override
  String badgeEarned(String badge) {
    return 'New badge earned: $badge';
  }

  @override
  String nextBadgeProgress(int count, String badge) {
    return '$count more to go until $badge.';
  }

  @override
  String get allBadgesEarned => 'Every badge earned. Wonderful reading!';

  @override
  String get shareStoryFile => 'Save story file';

  @override
  String get storyFileNotice =>
      'The story file is encrypted with this password. The child\'s photo is never included.';

  @override
  String get createStoryPasswordTitle => 'Create a story file password';

  @override
  String get enterStoryPasswordTitle => 'Enter the story file password';

  @override
  String get storyFilePassword => 'Story file password';

  @override
  String get confirmStoryFilePassword => 'Confirm story file password';

  @override
  String get storyFilePasswordMismatch =>
      'The story file passwords do not match.';

  @override
  String get saveStoryFileDialogTitle => 'Save encrypted Iam - hero story';

  @override
  String get storyFileSaved => 'Encrypted story file saved';

  @override
  String get storyFileSaveCancelled => 'Story file save cancelled';

  @override
  String get importStoryFile => 'Import story file';

  @override
  String get importStoryTitle => 'Import this story?';

  @override
  String importStoryPages(int count) {
    return 'Pages: $count';
  }

  @override
  String importStoryHero(String name) {
    return 'Hero in the file: $name';
  }

  @override
  String get importStoryChooseProfile => 'Add the story to';

  @override
  String get importStoryAction => 'Import story';

  @override
  String storyImported(String title) {
    return 'Story imported: $title';
  }

  @override
  String get storyAlreadyOnDevice => 'This story is already on this device.';

  @override
  String get importStoryNeedsProfile =>
      'Add a hero profile before importing a story.';

  @override
  String get storyFileWrongPassword =>
      'The password is wrong or the story file was changed.';

  @override
  String get storyFileInvalid =>
      'This is not a supported Iam - hero story file.';

  @override
  String get storyFileTooLarge =>
      'This story file is too large to open safely.';

  @override
  String get storyFileReadFailed =>
      'The selected story file could not be read.';

  @override
  String get storyFileFailed => 'The story file action could not be completed.';

  @override
  String get storyFileNewerVersion =>
      'This story file was created by a newer version of the app.';

  @override
  String get aiConnectionTitle => 'AI connection';

  @override
  String get aiConnectionBody =>
      'Choose whether new stories come from the offline sample or from the AI running on your own family PC.';

  @override
  String get aiConnectionParentNotice =>
      'These controls are for parents only. Children never see the PC address or the pairing.';

  @override
  String get storyGeneratorMode => 'Story generator';

  @override
  String get demoGeneratorMode => 'Demo · offline sample';

  @override
  String get localAiGeneratorMode => 'Local AI on the PC';

  @override
  String get storyGeneratorModeSaved => 'Story generator updated';

  @override
  String get bridgeAddress => 'PC bridge address';

  @override
  String get bridgeAddressHint => 'http://127.0.0.1:8765';

  @override
  String get bridgeAddressInvalid =>
      'Enter a full address, for example http://192.168.1.20:8765.';

  @override
  String get saveBridgeAddress => 'Save address';

  @override
  String get bridgeAddressSaved => 'PC bridge address saved';

  @override
  String get testBridgeConnection => 'Test connection';

  @override
  String bridgeReachable(String version) {
    return 'The PC bridge answered. Version $version.';
  }

  @override
  String get bridgeStatusReady => 'Ready';

  @override
  String get bridgeStatusUnavailable => 'Not available';

  @override
  String get bridgeLibraryStatus => 'PC story library';

  @override
  String get pairWithPc => 'Pair with PC';

  @override
  String get pairDeviceTitle => 'Pair this device';

  @override
  String get pairDeviceBody =>
      'Look at the PC screen: it shows a 6-digit code for two minutes. Type that code here together with a name for this device.';

  @override
  String get pairingCode => '6-digit code from the PC';

  @override
  String get pairingCodeInvalid => 'Enter the 6 digits shown on the PC.';

  @override
  String get pairedDeviceNameLabel => 'Name for this device';

  @override
  String get pairedDeviceNameHint => 'Family tablet';

  @override
  String pairedDeviceNameInvalid(int max) {
    return 'Enter a name of up to $max characters.';
  }

  @override
  String get confirmPairing => 'Pair device';

  @override
  String get devicePaired => 'Device paired with the PC';

  @override
  String devicePairedAs(String name) {
    return 'Paired with the PC as $name';
  }

  @override
  String get deviceNotPaired => 'This device is not paired with the PC yet.';

  @override
  String get forgetPairedDevice => 'Forget this device';

  @override
  String get forgetPairedDeviceTitle => 'Forget this pairing?';

  @override
  String get forgetPairedDeviceBody =>
      'This device stops using the PC until it is paired again. Remove it on the PC as well if it should not stay listed there.';

  @override
  String get pairedDeviceForgotten => 'Pairing removed from this device';

  @override
  String get pairedDevicesTitle => 'Devices paired with the PC';

  @override
  String get pairedDevicesBody =>
      'Everything listed here can reach the PC. Remove one and it has to pair again.';

  @override
  String get pairedDevicesEmpty => 'The PC lists no paired devices.';

  @override
  String pairedDeviceThisDevice(String name) {
    return '$name · this device';
  }

  @override
  String pairedDeviceSince(String date) {
    return 'Paired $date';
  }

  @override
  String pairedDeviceLastSeen(String date) {
    return 'Last seen $date';
  }

  @override
  String get pairedDeviceNeverSeen => 'Not used since pairing';

  @override
  String get removePairedDevice => 'Remove';

  @override
  String removePairedDeviceTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removePairedDeviceBody =>
      'That device loses access to the PC at once. It can pair again with a new code.';

  @override
  String pairedDeviceRemoved(String name) {
    return '$name can no longer reach the PC';
  }

  @override
  String get openAiConnectionSettings => 'Open AI connection settings';

  @override
  String get localAiModeNotice =>
      'Stories are written by the AI on your family PC. The PC, its bridge, and its model must be running.';

  @override
  String get localAiSubmitting => 'Sending the request to the PC…';

  @override
  String get localAiQueued => 'Waiting for the PC to start.';

  @override
  String localAiQueuedPosition(int position) {
    return 'Waiting on the PC · $position in line.';
  }

  @override
  String get localAiWriting => 'The PC is writing the story…';

  @override
  String get localAiChecking => 'Checking the finished pages…';

  @override
  String get bridgeUnreachable =>
      'The PC did not answer. Check that the bridge is running and that the address is correct.';

  @override
  String get bridgeBlockedByBrowser =>
      'The browser did not let this page contact the PC. On the PC itself, or on a device that runs Tailscale, open the browser\'s site settings for this page, set \"Local network access\" to Allow, and reload. If it still fails, check that the bridge is running and that the address is correct.';

  @override
  String get bridgeTimedOut => 'The PC took too long to answer.';

  @override
  String get bridgeNotPaired =>
      'Pair this device with the PC before generating a story there.';

  @override
  String get bridgeUnauthorized => 'The PC refused this device. Pair it again.';

  @override
  String get bridgeRateLimited =>
      'Too many pairing requests. Wait a minute and try again.';

  @override
  String get bridgePairingNotFound =>
      'That pairing is no longer waiting. Start a new one.';

  @override
  String get bridgePairingExpired =>
      'The code expired. Ask the PC for a new one.';

  @override
  String get bridgeInvalidPairingCode =>
      'That code is not correct. Five wrong codes cancel the pairing.';

  @override
  String get bridgeInvalidRequest => 'The PC refused this story request.';

  @override
  String get bridgeDeviceNotFound => 'The PC no longer lists that device.';

  @override
  String get bridgeCannotRemoveThisDevice =>
      'Use “Forget this device” to unpair this device.';

  @override
  String get bridgeJobNotFound => 'The PC no longer knows this story request.';

  @override
  String get bridgeGenerationFailed =>
      'The PC could not finish the story. Nothing was saved.';

  @override
  String get bridgeGenerationCancelled =>
      'Story generation was cancelled. Nothing was saved.';

  @override
  String get bridgeInvalidResponse =>
      'The PC answered with something this app cannot read.';

  @override
  String get bridgeProblem => 'The PC bridge reported a problem.';

  @override
  String get bridgeStoryNotFound => 'The PC no longer has this story.';

  @override
  String get librarySyncTitle => 'Offline story library';

  @override
  String get librarySyncBody =>
      'Bring the family\'s stories from the PC onto this device so they can be read when the PC is off.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get librarySyncRunning => 'Syncing with the PC…';

  @override
  String get librarySyncNever => 'This device has not synced with the PC yet.';

  @override
  String librarySyncLastRun(String moment) {
    return 'Last sync: $moment';
  }

  @override
  String librarySyncResult(int added, int updated, int removed) {
    return '$added new · $updated updated · $removed removed';
  }

  @override
  String get librarySyncUpToDate => 'This device already matches the PC.';

  @override
  String get librarySyncPendingProfilesTitle => 'Waiting for a hero profile';

  @override
  String librarySyncPendingProfile(int count, String name) {
    return '$count stories for $name stay on the PC: this device has no profile for that child.';
  }

  @override
  String get librarySyncPendingProfilesBody =>
      'A child\'s profile belongs to the device it was created on. Restore that device\'s backup here, or create stories for this child from this device, and their stories will sync too.';

  @override
  String get removedStoriesTitle => 'Stories removed from this device';

  @override
  String removedStoriesBody(int count) {
    return '$count stories were removed from this device only. They are still on the PC, and sync leaves them alone until you ask for them.';
  }

  @override
  String get redownloadRemovedStories => 'Download them again';

  @override
  String get redownloadRemovedStoriesDone =>
      'The next sync will bring those stories back';

  @override
  String get deleteBridgeStoryTitle => 'Where should this story be deleted?';

  @override
  String get deleteBridgeStoryBody =>
      'This story is also in the library on the family PC, so there are two different things you can do.';

  @override
  String get removeStoryFromDevice => 'Remove from this device';

  @override
  String get removeStoryFromDeviceDetail =>
      'Deletes the copy here. The story stays on the PC, and this device will not download it again until you ask for it.';

  @override
  String get deleteStoryEverywhere => 'Delete everywhere';

  @override
  String get deleteStoryEverywhereDetail =>
      'Deletes the story on the PC and on every device in the family. This cannot be undone, and the PC has to be reachable.';

  @override
  String get storyRemovedFromDevice => 'Story removed from this device';

  @override
  String get storyDeletedEverywhere =>
      'Story deleted on the PC and on every device';

  @override
  String get storyAlreadyDeletedEverywhere =>
      'That story had already been deleted for the whole family';

  @override
  String get close => 'Close';

  @override
  String get illustrateStory => 'Illustrate this story';

  @override
  String get illustrateStoryTitle => 'Make pictures for this story?';

  @override
  String get illustrateStoryBody =>
      'The family PC draws one picture for every page. That takes a few minutes per page, so leave the PC on until it is finished. You can stop at any time and the pictures that are already done are kept.';

  @override
  String get startIllustrating => 'Make the pictures';

  @override
  String get stopIllustrating => 'Stop';

  @override
  String get illustrationsSendingPhoto => 'Sending the hero photo to the PC…';

  @override
  String get illustrationsSubmitting => 'Asking the PC to start drawing…';

  @override
  String get illustrationsDrawingAny => 'The PC is drawing the pictures…';

  @override
  String illustrationsDrawing(int done, int total) {
    return 'Drawing picture $done of $total…';
  }

  @override
  String get illustrationsDownloading =>
      'Bringing the finished pictures to this device…';

  @override
  String illustrationsReady(int count) {
    return '$count pictures are ready.';
  }

  @override
  String illustrationsPartlyReady(int done, int total) {
    return '$done of $total pictures are ready. The PC could not draw the rest.';
  }

  @override
  String get illustrationsNoneDrawn => 'The PC could not draw any pictures.';

  @override
  String get illustrationsAlreadyDone => 'Every page already has its picture.';

  @override
  String get illustrationsStopped =>
      'Drawing stopped. The pictures that were finished are kept.';

  @override
  String illustrationsNotFetched(int count) {
    return '$count pictures could not be brought to this device.';
  }

  @override
  String get referencePhotoSkipped =>
      'The hero photo could not be used, so the faces in the pictures are not their own.';

  @override
  String librarySyncPictures(int count) {
    return '$count new pictures';
  }

  @override
  String get bridgeProfileNotFound => 'The PC does not know this child yet.';

  @override
  String get bridgePhotoTooLarge => 'That photo is too large for the PC.';

  @override
  String get bridgeUnsupportedImage =>
      'The PC can only use a JPEG or a PNG photo.';

  @override
  String get bridgeIllustrationNotFound => 'The PC no longer has that picture.';

  @override
  String get bridgeIllustrationNotReady =>
      'That picture has not been made yet.';
}
