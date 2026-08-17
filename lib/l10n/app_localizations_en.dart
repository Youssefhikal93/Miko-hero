// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Miko-hero';

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
      'Create private, illustrated stories where your daughter is the hero.';

  @override
  String get createFirstStory => 'Create her first story';

  @override
  String get createAnotherStory => 'Create another story';

  @override
  String get recentStories => 'Recent stories';

  @override
  String get profileIncompleteTitle => 'Set up her hero profile';

  @override
  String get profileIncompleteBody =>
      'Add her name, age, and a reference photo before creating a story.';

  @override
  String get setUpProfile => 'Set up profile';

  @override
  String get editProfile => 'Edit hero profile';

  @override
  String get profileTitle => 'Hero profile';

  @override
  String get profileIntro =>
      'This information stays on this device and is never committed to the app\'s source code.';

  @override
  String get daughterName => 'Daughter\'s name';

  @override
  String get age => 'Age';

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
  String get nameRequired => 'Enter her name.';

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
  String get profileNeeded => 'Complete the hero profile first.';

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
  String get libraryTitle => 'Her story library';

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
      'Profile details, photos, and stories stay in local device storage. No analytics or paid cloud service is used.';

  @override
  String get deleteAllData => 'Delete all local data';

  @override
  String get deleteAllTitle => 'Delete everything?';

  @override
  String get deleteAllBody =>
      'The profile, photo, and every story will be permanently deleted from this device.';

  @override
  String get allDataDeleted => 'All local data was deleted';

  @override
  String get aboutTitle => 'About Miko-hero';

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
}
