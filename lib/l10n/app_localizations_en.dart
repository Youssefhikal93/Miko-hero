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
  String get welcomeTitle => 'A new adventure starts here';

  @override
  String get welcomeBody =>
      'Create private, illustrated stories where each child becomes the hero.';

  @override
  String get createFirstStory => 'Create a first story';

  @override
  String get createAnotherStory => 'Create another story';

  @override
  String get recentStories => 'Recent stories';

  @override
  String get profileIncompleteTitle => 'Add a hero profile';

  @override
  String get profileIncompleteBody =>
      'Add a child\'s name, age, Girl/Boy choice, and reference photo before creating a story.';

  @override
  String get setUpProfile => 'Add a profile';

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
  String get photoTooLarge => 'Choose a photo smaller than 2 MB.';

  @override
  String get photoReadFailed => 'The selected photo could not be read.';

  @override
  String get photoRequired => 'Choose a reference photo.';

  @override
  String get createStoryTitle => 'Create a story';

  @override
  String get chooseHeroProfile => 'Choose a hero profile';

  @override
  String get selectHeroProfile => 'Select a child';

  @override
  String get profileSelectionRequired => 'Choose which child will be the hero.';

  @override
  String get storyLanguage => 'Story language';

  @override
  String get theme => 'Adventure theme';

  @override
  String get themeHint => 'For example: a moon garden';

  @override
  String get moral => 'Lesson or value';

  @override
  String get moralHint => 'For example: kindness and courage';

  @override
  String get storyLength => 'Story length';

  @override
  String get illustrationStyle => 'Illustration style';

  @override
  String get shortLength => 'Short · 6 pages';

  @override
  String get mediumLength => 'Medium · 8 pages';

  @override
  String get longLength => 'Long · 10 pages';

  @override
  String get pictureBookStyle => 'Soft picture book';

  @override
  String get watercolorStyle => 'Watercolor';

  @override
  String get threeDStyle => 'Colorful 3D';

  @override
  String get generateStory => 'Generate demo story';

  @override
  String get demoModeNotice =>
      'Local AI is not connected yet. Demo mode creates a clearly marked sample story so the complete app flow can be tested for free.';

  @override
  String get profileNeeded => 'Add at least one hero profile first.';

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
  String get libraryTitle => 'Family story library';

  @override
  String get librarySubtitle =>
      'Completed stories are stored only on this device.';

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
  String get playNarration => 'Play narration';

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
      'A private family storybook. Local Ollama and ComfyUI connections will be added in a later phase.';

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
  String get filterStories => 'Filter this shelf';

  @override
  String get allStories => 'All stories';

  @override
  String get favoriteStories => 'Favorites';

  @override
  String get noStoriesInFilter => 'No stories match this filter yet.';

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
      'The demo works with the PC off. After local AI is connected later, the PC and its models must be running for new AI stories; saved books still open offline.';

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
}
