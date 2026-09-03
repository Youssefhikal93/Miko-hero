import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_so.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('so'),
    Locale('sv'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Iam - hero'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'A new adventure starts here'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Create private, illustrated stories where each child becomes the hero.'**
  String get welcomeBody;

  /// No description provided for @createFirstStory.
  ///
  /// In en, this message translates to:
  /// **'Create a first story'**
  String get createFirstStory;

  /// No description provided for @createAnotherStory.
  ///
  /// In en, this message translates to:
  /// **'Create another story'**
  String get createAnotherStory;

  /// No description provided for @recentStories.
  ///
  /// In en, this message translates to:
  /// **'Recent stories'**
  String get recentStories;

  /// No description provided for @profileIncompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a hero profile'**
  String get profileIncompleteTitle;

  /// No description provided for @profileIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Add a child\'s name, age, Girl/Boy choice, and reference photo before creating a story.'**
  String get profileIncompleteBody;

  /// No description provided for @setUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Add a profile'**
  String get setUpProfile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit hero profile'**
  String get editProfile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Hero profile'**
  String get profileTitle;

  /// No description provided for @profilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Hero profiles'**
  String get profilesTitle;

  /// No description provided for @profilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add one private profile for each child who can star in a story.'**
  String get profilesSubtitle;

  /// No description provided for @addProfile.
  ///
  /// In en, this message translates to:
  /// **'Add profile'**
  String get addProfile;

  /// No description provided for @manageProfiles.
  ///
  /// In en, this message translates to:
  /// **'Manage hero profiles'**
  String get manageProfiles;

  /// No description provided for @profileCount.
  ///
  /// In en, this message translates to:
  /// **'Profiles: {count}'**
  String profileCount(int count);

  /// No description provided for @noProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'No hero profiles yet'**
  String get noProfilesTitle;

  /// No description provided for @noProfilesBody.
  ///
  /// In en, this message translates to:
  /// **'Add the first child profile to start creating personalized stories.'**
  String get noProfilesBody;

  /// No description provided for @profileIntro.
  ///
  /// In en, this message translates to:
  /// **'This child\'s information stays on this device and is never committed to the app\'s source code.'**
  String get profileIntro;

  /// No description provided for @childName.
  ///
  /// In en, this message translates to:
  /// **'Child\'s name'**
  String get childName;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @genderTitle.
  ///
  /// In en, this message translates to:
  /// **'Is this hero a girl or a boy?'**
  String get genderTitle;

  /// No description provided for @girl.
  ///
  /// In en, this message translates to:
  /// **'Girl'**
  String get girl;

  /// No description provided for @boy.
  ///
  /// In en, this message translates to:
  /// **'Boy'**
  String get boy;

  /// No description provided for @genderRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose Girl or Boy.'**
  String get genderRequired;

  /// No description provided for @genderNotSet.
  ///
  /// In en, this message translates to:
  /// **'Girl/Boy not selected'**
  String get genderNotSet;

  /// No description provided for @referencePhoto.
  ///
  /// In en, this message translates to:
  /// **'Reference photo'**
  String get referencePhoto;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo'**
  String get choosePhoto;

  /// No description provided for @replacePhoto.
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get replacePhoto;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @saveProfile.
  ///
  /// In en, this message translates to:
  /// **'Save profile'**
  String get saveProfile;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the child\'s name.'**
  String get nameRequired;

  /// No description provided for @ageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 1 to 17.'**
  String get ageInvalid;

  /// No description provided for @birthDate.
  ///
  /// In en, this message translates to:
  /// **'Birth date'**
  String get birthDate;

  /// No description provided for @chooseBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Choose birth date'**
  String get chooseBirthDate;

  /// No description provided for @changeBirthDate.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get changeBirthDate;

  /// No description provided for @birthDateHelper.
  ///
  /// In en, this message translates to:
  /// **'The age used in stories updates itself every birthday.'**
  String get birthDateHelper;

  /// No description provided for @birthDateLegacyAge.
  ///
  /// In en, this message translates to:
  /// **'Saved age: {age}. Choose a birth date so it stays correct.'**
  String birthDateLegacyAge(int age);

  /// No description provided for @birthDateRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose the child\'s birth date.'**
  String get birthDateRequired;

  /// No description provided for @photoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo smaller than 2 MB.'**
  String get photoTooLarge;

  /// No description provided for @photoReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The selected photo could not be read.'**
  String get photoReadFailed;

  /// No description provided for @photoRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a reference photo.'**
  String get photoRequired;

  /// No description provided for @createStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'New story'**
  String get createStoryTitle;

  /// No description provided for @whoIsTheHero.
  ///
  /// In en, this message translates to:
  /// **'Who is the hero'**
  String get whoIsTheHero;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @heroAgeGender.
  ///
  /// In en, this message translates to:
  /// **'{age} · {gender}'**
  String heroAgeGender(int age, String gender);

  /// No description provided for @whatHappens.
  ///
  /// In en, this message translates to:
  /// **'What happens'**
  String get whatHappens;

  /// No description provided for @lessonHint.
  ///
  /// In en, this message translates to:
  /// **'And the lesson it teaches'**
  String get lessonHint;

  /// No description provided for @howLong.
  ///
  /// In en, this message translates to:
  /// **'How long'**
  String get howLong;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'pages'**
  String get pages;

  /// No description provided for @lookAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Look and language'**
  String get lookAndLanguage;

  /// No description provided for @storyLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get storyLanguageEnglish;

  /// No description provided for @storyLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get storyLanguageArabic;

  /// No description provided for @storyLanguageSwedish.
  ///
  /// In en, this message translates to:
  /// **'Svenska'**
  String get storyLanguageSwedish;

  /// No description provided for @storyLanguageSomali.
  ///
  /// In en, this message translates to:
  /// **'Soomaali'**
  String get storyLanguageSomali;

  /// No description provided for @writeTheStory.
  ///
  /// In en, this message translates to:
  /// **'Write the story'**
  String get writeTheStory;

  /// No description provided for @demoGeneratorLabel.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demoGeneratorLabel;

  /// No description provided for @localAiGeneratorLabel.
  ///
  /// In en, this message translates to:
  /// **'Local AI'**
  String get localAiGeneratorLabel;

  /// No description provided for @chooseHeroProfile.
  ///
  /// In en, this message translates to:
  /// **'Choose a hero profile'**
  String get chooseHeroProfile;

  /// No description provided for @selectHeroProfile.
  ///
  /// In en, this message translates to:
  /// **'Select a child'**
  String get selectHeroProfile;

  /// No description provided for @profileSelectionRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose which child will be the hero.'**
  String get profileSelectionRequired;

  /// No description provided for @storyLanguage.
  ///
  /// In en, this message translates to:
  /// **'Story language'**
  String get storyLanguage;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Adventure theme'**
  String get theme;

  /// No description provided for @themeHint.
  ///
  /// In en, this message translates to:
  /// **'For example: a moon garden'**
  String get themeHint;

  /// No description provided for @moral.
  ///
  /// In en, this message translates to:
  /// **'Lesson or value'**
  String get moral;

  /// No description provided for @moralHint.
  ///
  /// In en, this message translates to:
  /// **'For example: kindness and courage'**
  String get moralHint;

  /// No description provided for @storyLength.
  ///
  /// In en, this message translates to:
  /// **'Story length'**
  String get storyLength;

  /// No description provided for @illustrationStyle.
  ///
  /// In en, this message translates to:
  /// **'Illustration style'**
  String get illustrationStyle;

  /// No description provided for @shortLength.
  ///
  /// In en, this message translates to:
  /// **'Short · 6 pages'**
  String get shortLength;

  /// No description provided for @mediumLength.
  ///
  /// In en, this message translates to:
  /// **'Medium · 8 pages'**
  String get mediumLength;

  /// No description provided for @longLength.
  ///
  /// In en, this message translates to:
  /// **'Long · 10 pages'**
  String get longLength;

  /// No description provided for @pictureBookStyle.
  ///
  /// In en, this message translates to:
  /// **'Picture book'**
  String get pictureBookStyle;

  /// No description provided for @watercolorStyle.
  ///
  /// In en, this message translates to:
  /// **'Watercolor'**
  String get watercolorStyle;

  /// No description provided for @threeDStyle.
  ///
  /// In en, this message translates to:
  /// **'Colorful 3D'**
  String get threeDStyle;

  /// No description provided for @generateStory.
  ///
  /// In en, this message translates to:
  /// **'Generate demo story'**
  String get generateStory;

  /// No description provided for @demoModeNotice.
  ///
  /// In en, this message translates to:
  /// **'Demo mode creates a clearly marked sample story with no PC and no AI. Switch the story generator to Local AI in settings to write on your family PC.'**
  String get demoModeNotice;

  /// No description provided for @profileNeeded.
  ///
  /// In en, this message translates to:
  /// **'Add at least one hero profile first.'**
  String get profileNeeded;

  /// No description provided for @themeRequired.
  ///
  /// In en, this message translates to:
  /// **'Describe the adventure theme.'**
  String get themeRequired;

  /// No description provided for @moralRequired.
  ///
  /// In en, this message translates to:
  /// **'Add a lesson or value.'**
  String get moralRequired;

  /// No description provided for @generatingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building the adventure'**
  String get generatingTitle;

  /// No description provided for @generatingBody.
  ///
  /// In en, this message translates to:
  /// **'Writing pages and preparing the private local book…'**
  String get generatingBody;

  /// No description provided for @storyCreated.
  ///
  /// In en, this message translates to:
  /// **'The story is ready'**
  String get storyCreated;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Family story library'**
  String get libraryTitle;

  /// No description provided for @librarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed stories are stored only on this device.'**
  String get librarySubtitle;

  /// No description provided for @emptyLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'The bookshelf is waiting'**
  String get emptyLibraryTitle;

  /// No description provided for @emptyLibraryBody.
  ///
  /// In en, this message translates to:
  /// **'Create a first adventure and it will appear here.'**
  String get emptyLibraryBody;

  /// No description provided for @openStory.
  ///
  /// In en, this message translates to:
  /// **'Open story'**
  String get openStory;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this story?'**
  String get deleteStoryTitle;

  /// No description provided for @deleteStoryBody.
  ///
  /// In en, this message translates to:
  /// **'The story will be permanently removed from this device.'**
  String get deleteStoryBody;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get confirmDelete;

  /// No description provided for @readStory.
  ///
  /// In en, this message translates to:
  /// **'Read story'**
  String get readStory;

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get nextPage;

  /// No description provided for @pageProgress.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String pageProgress(int current, int total);

  /// No description provided for @playNarration.
  ///
  /// In en, this message translates to:
  /// **'Play narration'**
  String get playNarration;

  /// No description provided for @pauseNarration.
  ///
  /// In en, this message translates to:
  /// **'Pause narration'**
  String get pauseNarration;

  /// No description provided for @resumeNarration.
  ///
  /// In en, this message translates to:
  /// **'Continue narration'**
  String get resumeNarration;

  /// No description provided for @stopNarration.
  ///
  /// In en, this message translates to:
  /// **'Stop narration'**
  String get stopNarration;

  /// No description provided for @narrationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No compatible voice is installed for this language.'**
  String get narrationUnavailable;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings and privacy'**
  String get settingsTitle;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get appLanguage;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Local and private'**
  String get privacyTitle;

  /// No description provided for @privacyBody.
  ///
  /// In en, this message translates to:
  /// **'Profile details, photos, and stories stay in local device storage unless you manually export an encrypted backup. No analytics or paid cloud service is used.'**
  String get privacyBody;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data'**
  String get deleteAllData;

  /// No description provided for @deleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllBody.
  ///
  /// In en, this message translates to:
  /// **'All profiles, photos, and stories will be permanently deleted from this device.'**
  String get deleteAllBody;

  /// No description provided for @allDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'All local data was deleted'**
  String get allDataDeleted;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Iam - hero'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A private family storybook. Stories are written by a local Ollama model and pictures are drawn by ComfyUI, both on your own PC.'**
  String get aboutBody;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @swedish.
  ///
  /// In en, this message translates to:
  /// **'Swedish'**
  String get swedish;

  /// No description provided for @somali.
  ///
  /// In en, this message translates to:
  /// **'Somali'**
  String get somali;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @demoBadge.
  ///
  /// In en, this message translates to:
  /// **'DEMO'**
  String get demoBadge;

  /// No description provided for @yearsOld.
  ///
  /// In en, this message translates to:
  /// **'{age} years old'**
  String yearsOld(int age);

  /// No description provided for @storyByHero.
  ///
  /// In en, this message translates to:
  /// **'An adventure starring {name}'**
  String storyByHero(String name);

  /// No description provided for @myKingdom.
  ///
  /// In en, this message translates to:
  /// **'My Kingdom'**
  String get myKingdom;

  /// No description provided for @kingdomTitle.
  ///
  /// In en, this message translates to:
  /// **'My Kingdom'**
  String get kingdomTitle;

  /// No description provided for @kingdomSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a hero, update their profile, and give each child their own app color.'**
  String get kingdomSubtitle;

  /// No description provided for @activeHero.
  ///
  /// In en, this message translates to:
  /// **'Active hero'**
  String get activeHero;

  /// No description provided for @chooseHero.
  ///
  /// In en, this message translates to:
  /// **'Choose a child'**
  String get chooseHero;

  /// No description provided for @editHeroProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit name and profile'**
  String get editHeroProfile;

  /// No description provided for @addAnotherHero.
  ///
  /// In en, this message translates to:
  /// **'Add another hero'**
  String get addAnotherHero;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Kingdom color'**
  String get themeColor;

  /// No description provided for @themeColorHint.
  ///
  /// In en, this message translates to:
  /// **'This color is saved only for {name}\'s profile.'**
  String themeColorHint(String name);

  /// No description provided for @goldenTheme.
  ///
  /// In en, this message translates to:
  /// **'Golden'**
  String get goldenTheme;

  /// No description provided for @roseTheme.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get roseTheme;

  /// No description provided for @purpleTheme.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get purpleTheme;

  /// No description provided for @cyanTheme.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get cyanTheme;

  /// No description provided for @greenTheme.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get greenTheme;

  /// No description provided for @customColor.
  ///
  /// In en, this message translates to:
  /// **'Custom color'**
  String get customColor;

  /// No description provided for @customColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a custom color'**
  String get customColorTitle;

  /// No description provided for @hue.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get hue;

  /// No description provided for @intensity.
  ///
  /// In en, this message translates to:
  /// **'Intensity'**
  String get intensity;

  /// No description provided for @brightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get brightness;

  /// No description provided for @applyColor.
  ///
  /// In en, this message translates to:
  /// **'Use this color'**
  String get applyColor;

  /// No description provided for @profileThemeSaved.
  ///
  /// In en, this message translates to:
  /// **'Color saved for {name}'**
  String profileThemeSaved(String name);

  /// No description provided for @parentSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent protection'**
  String get parentSecurityTitle;

  /// No description provided for @parentSecurityBody.
  ///
  /// In en, this message translates to:
  /// **'An optional local PIN protects profiles, My Kingdom, settings, and deletion. It is not a replacement for device security.'**
  String get parentSecurityBody;

  /// No description provided for @parentPin.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN'**
  String get parentPin;

  /// No description provided for @parentPinConfigured.
  ///
  /// In en, this message translates to:
  /// **'A parent PIN is enabled on this device.'**
  String get parentPinConfigured;

  /// No description provided for @parentPinNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'No parent PIN is set. Parent controls are currently open.'**
  String get parentPinNotConfigured;

  /// No description provided for @setParentPin.
  ///
  /// In en, this message translates to:
  /// **'Set parent PIN'**
  String get setParentPin;

  /// No description provided for @changeParentPin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changeParentPin;

  /// No description provided for @removeParentPin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get removeParentPin;

  /// No description provided for @lockParentArea.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockParentArea;

  /// No description provided for @parentAreaLocked.
  ///
  /// In en, this message translates to:
  /// **'Parent area locked'**
  String get parentAreaLocked;

  /// No description provided for @enterParentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the local parent PIN to continue.'**
  String get enterParentPin;

  /// No description provided for @incorrectParentPin.
  ///
  /// In en, this message translates to:
  /// **'That PIN is incorrect.'**
  String get incorrectParentPin;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @newParentPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newParentPin;

  /// No description provided for @confirmParentPin.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get confirmParentPin;

  /// No description provided for @parentPinRequirements.
  ///
  /// In en, this message translates to:
  /// **'Use 4 to 8 digits.'**
  String get parentPinRequirements;

  /// No description provided for @parentPinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs do not match.'**
  String get parentPinMismatch;

  /// No description provided for @saveParentPin.
  ///
  /// In en, this message translates to:
  /// **'Save PIN'**
  String get saveParentPin;

  /// No description provided for @parentPinSaved.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN saved'**
  String get parentPinSaved;

  /// No description provided for @parentPinRemoved.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN removed'**
  String get parentPinRemoved;

  /// No description provided for @removeParentPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove parent PIN?'**
  String get removeParentPinTitle;

  /// No description provided for @removeParentPinBody.
  ///
  /// In en, this message translates to:
  /// **'Parent controls will remain open on this device until a new PIN is set.'**
  String get removeParentPinBody;

  /// No description provided for @parentPinLockedSeconds.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {seconds} s.'**
  String parentPinLockedSeconds(int seconds);

  /// No description provided for @parentPinLockedMinutes.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {minutes} min.'**
  String parentPinLockedMinutes(int minutes);

  /// No description provided for @changeParentPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Change parent PIN'**
  String get changeParentPinTitle;

  /// No description provided for @currentParentPin.
  ///
  /// In en, this message translates to:
  /// **'Current PIN'**
  String get currentParentPin;

  /// No description provided for @parentPinChanged.
  ///
  /// In en, this message translates to:
  /// **'Parent PIN changed'**
  String get parentPinChanged;

  /// No description provided for @forgotParentPinBody.
  ///
  /// In en, this message translates to:
  /// **'There is no PIN recovery. If the PIN is forgotten, the only option is deleting all app data; an encrypted backup then restores the family content, because a backup never contains the PIN.'**
  String get forgotParentPinBody;

  /// No description provided for @encryptedBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup'**
  String get encryptedBackupTitle;

  /// No description provided for @encryptedBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Save a password-protected file and restore it on another device. The backup password is never stored, so keep it safe.'**
  String get encryptedBackupBody;

  /// No description provided for @exportEncryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get exportEncryptedBackup;

  /// No description provided for @restoreEncryptedBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore backup'**
  String get restoreEncryptedBackup;

  /// No description provided for @createBackupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a backup password'**
  String get createBackupPasswordTitle;

  /// No description provided for @enterBackupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the backup password'**
  String get enterBackupPasswordTitle;

  /// No description provided for @backupPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassword;

  /// No description provided for @confirmBackupPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm backup password'**
  String get confirmBackupPassword;

  /// No description provided for @backupPasswordRequirements.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters. This password cannot be recovered.'**
  String get backupPasswordRequirements;

  /// No description provided for @backupPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The backup passwords do not match.'**
  String get backupPasswordMismatch;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @backupReadyTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup ready'**
  String get backupReadyTitle;

  /// No description provided for @backupReadyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose Download backup to save the encrypted file.'**
  String get backupReadyBody;

  /// No description provided for @downloadBackup.
  ///
  /// In en, this message translates to:
  /// **'Download backup'**
  String get downloadBackup;

  /// No description provided for @saveBackupDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save encrypted Iam - hero backup'**
  String get saveBackupDialogTitle;

  /// No description provided for @backupSaved.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup saved'**
  String get backupSaved;

  /// No description provided for @restoreFileName.
  ///
  /// In en, this message translates to:
  /// **'Selected file: {name}'**
  String restoreFileName(String name);

  /// No description provided for @confirmRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace local family data?'**
  String get confirmRestoreTitle;

  /// No description provided for @confirmRestoreBody.
  ///
  /// In en, this message translates to:
  /// **'This backup contains {profiles} profiles and {stories} stories. Restoring replaces the profiles, stories, active hero, and app language currently on this device.'**
  String confirmRestoreBody(int profiles, int stories);

  /// No description provided for @restoreNow.
  ///
  /// In en, this message translates to:
  /// **'Restore now'**
  String get restoreNow;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup restored'**
  String get backupRestored;

  /// No description provided for @backupWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is wrong or the backup was changed.'**
  String get backupWrongPassword;

  /// No description provided for @backupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a supported Iam - hero backup.'**
  String get backupInvalid;

  /// No description provided for @backupTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This backup is too large to open safely.'**
  String get backupTooLarge;

  /// No description provided for @backupFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The selected backup could not be read.'**
  String get backupFileReadFailed;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'The backup action could not be completed.'**
  String get backupFailed;

  /// No description provided for @backupNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This backup was created by a newer version of the app.'**
  String get backupNewerVersion;

  /// No description provided for @storyPreferencesTitle.
  ///
  /// In en, this message translates to:
  /// **'Story preferences and safety'**
  String get storyPreferencesTitle;

  /// No description provided for @storyPreferencesBody.
  ///
  /// In en, this message translates to:
  /// **'Choose what inspires {name}\'s stories and what local AI must avoid.'**
  String storyPreferencesBody(String name);

  /// No description provided for @editStoryPreferences.
  ///
  /// In en, this message translates to:
  /// **'Edit story preferences'**
  String get editStoryPreferences;

  /// No description provided for @defaultStoryLanguage.
  ///
  /// In en, this message translates to:
  /// **'Default story language'**
  String get defaultStoryLanguage;

  /// No description provided for @defaultStoryLanguageValue.
  ///
  /// In en, this message translates to:
  /// **'Default language: {language}'**
  String defaultStoryLanguageValue(String language);

  /// No description provided for @favoriteThings.
  ///
  /// In en, this message translates to:
  /// **'Favorite things'**
  String get favoriteThings;

  /// No description provided for @favoriteThingsHint.
  ///
  /// In en, this message translates to:
  /// **'For example: trains, cats, stars'**
  String get favoriteThingsHint;

  /// No description provided for @favoriteThingsValue.
  ///
  /// In en, this message translates to:
  /// **'Favorite things: {value}'**
  String favoriteThingsValue(String value);

  /// No description provided for @recurringWorld.
  ///
  /// In en, this message translates to:
  /// **'Recurring world'**
  String get recurringWorld;

  /// No description provided for @recurringWorldHint.
  ///
  /// In en, this message translates to:
  /// **'For example: The Golden Cloud Kingdom'**
  String get recurringWorldHint;

  /// No description provided for @recurringWorldValue.
  ///
  /// In en, this message translates to:
  /// **'Recurring world: {value}'**
  String recurringWorldValue(String value);

  /// No description provided for @safetyControls.
  ///
  /// In en, this message translates to:
  /// **'Topics to avoid'**
  String get safetyControls;

  /// No description provided for @safetyControlsHint.
  ///
  /// In en, this message translates to:
  /// **'These exclusions will be passed to future local story and image generation.'**
  String get safetyControlsHint;

  /// No description provided for @safetyRulesValue.
  ///
  /// In en, this message translates to:
  /// **'Safety exclusions: {count}'**
  String safetyRulesValue(int count);

  /// No description provided for @avoidFrighteningContent.
  ///
  /// In en, this message translates to:
  /// **'Frightening content'**
  String get avoidFrighteningContent;

  /// No description provided for @avoidViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence or injury'**
  String get avoidViolence;

  /// No description provided for @avoidBullying.
  ///
  /// In en, this message translates to:
  /// **'Bullying or exclusion'**
  String get avoidBullying;

  /// No description provided for @avoidGriefAndLoss.
  ///
  /// In en, this message translates to:
  /// **'Grief or loss'**
  String get avoidGriefAndLoss;

  /// No description provided for @savePreferences.
  ///
  /// In en, this message translates to:
  /// **'Save preferences'**
  String get savePreferences;

  /// No description provided for @storyPreferencesSaved.
  ///
  /// In en, this message translates to:
  /// **'Story preferences saved for {name}'**
  String storyPreferencesSaved(String name);

  /// No description provided for @savedPreferencesInUse.
  ///
  /// In en, this message translates to:
  /// **'Using {name}\'s saved preferences and {count} safety exclusions.'**
  String savedPreferencesInUse(String name, int count);

  /// No description provided for @reviewStoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Parent story review'**
  String get reviewStoriesTitle;

  /// No description provided for @reviewStoriesBody.
  ///
  /// In en, this message translates to:
  /// **'Generated drafts stay out of the child library until you read and approve them.'**
  String get reviewStoriesBody;

  /// No description provided for @reviewStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Review this story'**
  String get reviewStoryTitle;

  /// No description provided for @reviewStoryBody.
  ///
  /// In en, this message translates to:
  /// **'Check the request and every page before making the story visible in the library.'**
  String get reviewStoryBody;

  /// No description provided for @reviewDraftCount.
  ///
  /// In en, this message translates to:
  /// **'Review drafts ({count})'**
  String reviewDraftCount(int count);

  /// No description provided for @approveStory.
  ///
  /// In en, this message translates to:
  /// **'Approve story'**
  String get approveStory;

  /// No description provided for @storyApproved.
  ///
  /// In en, this message translates to:
  /// **'Story approved and added to the library'**
  String get storyApproved;

  /// No description provided for @deleteDraft.
  ///
  /// In en, this message translates to:
  /// **'Delete draft'**
  String get deleteDraft;

  /// No description provided for @deleteDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this draft?'**
  String get deleteDraftTitle;

  /// No description provided for @deleteDraftBody.
  ///
  /// In en, this message translates to:
  /// **'This generated draft will be permanently removed from this device.'**
  String get deleteDraftBody;

  /// No description provided for @reviewHero.
  ///
  /// In en, this message translates to:
  /// **'Hero: {value}'**
  String reviewHero(String value);

  /// No description provided for @reviewTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme: {value}'**
  String reviewTheme(String value);

  /// No description provided for @reviewMoral.
  ///
  /// In en, this message translates to:
  /// **'Moral: {value}'**
  String reviewMoral(String value);

  /// No description provided for @reviewPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String reviewPageNumber(int number);

  /// No description provided for @noDrafts.
  ///
  /// In en, this message translates to:
  /// **'No stories are waiting for review.'**
  String get noDrafts;

  /// No description provided for @addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get addFavorite;

  /// No description provided for @removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get removeFavorite;

  /// No description provided for @manageCollections.
  ///
  /// In en, this message translates to:
  /// **'Manage collections'**
  String get manageCollections;

  /// No description provided for @collectionsHint.
  ///
  /// In en, this message translates to:
  /// **'Enter up to {max} collection names, separated by commas or new lines.'**
  String collectionsHint(int max);

  /// No description provided for @collectionNames.
  ///
  /// In en, this message translates to:
  /// **'Collection names'**
  String get collectionNames;

  /// No description provided for @collectionNamesHint.
  ///
  /// In en, this message translates to:
  /// **'Bedtime, Space adventures'**
  String get collectionNamesHint;

  /// No description provided for @saveCollections.
  ///
  /// In en, this message translates to:
  /// **'Save collections'**
  String get saveCollections;

  /// No description provided for @tooManyCollections.
  ///
  /// In en, this message translates to:
  /// **'Use no more than {max} collections.'**
  String tooManyCollections(int max);

  /// No description provided for @collectionNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Each collection name must be {max} characters or fewer.'**
  String collectionNameTooLong(int max);

  /// No description provided for @filterStories.
  ///
  /// In en, this message translates to:
  /// **'Filter this shelf'**
  String get filterStories;

  /// No description provided for @allStories.
  ///
  /// In en, this message translates to:
  /// **'All stories'**
  String get allStories;

  /// No description provided for @favoriteStories.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoriteStories;

  /// No description provided for @noStoriesInFilter.
  ///
  /// In en, this message translates to:
  /// **'No stories match this filter yet.'**
  String get noStoriesInFilter;

  /// No description provided for @generationCenterTitle.
  ///
  /// In en, this message translates to:
  /// **'Local generation center'**
  String get generationCenterTitle;

  /// No description provided for @generationCenterBody.
  ///
  /// In en, this message translates to:
  /// **'See what works offline now and safely retry requests saved before generation.'**
  String get generationCenterBody;

  /// No description provided for @openGenerationCenter.
  ///
  /// In en, this message translates to:
  /// **'Open generation center'**
  String get openGenerationCenter;

  /// No description provided for @generationQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved generation queue'**
  String get generationQueueTitle;

  /// No description provided for @generationQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No story requests are waiting or failed.'**
  String get generationQueueEmpty;

  /// No description provided for @demoGeneratorStatus.
  ///
  /// In en, this message translates to:
  /// **'Offline demo generator'**
  String get demoGeneratorStatus;

  /// No description provided for @readyOffline.
  ///
  /// In en, this message translates to:
  /// **'Ready offline'**
  String get readyOffline;

  /// No description provided for @ollamaStatus.
  ///
  /// In en, this message translates to:
  /// **'Ollama story model'**
  String get ollamaStatus;

  /// No description provided for @comfyUiStatus.
  ///
  /// In en, this message translates to:
  /// **'ComfyUI illustrations'**
  String get comfyUiStatus;

  /// No description provided for @notConnectedYet.
  ///
  /// In en, this message translates to:
  /// **'Not connected yet'**
  String get notConnectedYet;

  /// No description provided for @pcRequirementStatus.
  ///
  /// In en, this message translates to:
  /// **'The demo works with the PC switched off. Local AI stories need the PC, its bridge, and its model running; saved books always open offline.'**
  String get pcRequirementStatus;

  /// No description provided for @generationQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued and saved'**
  String get generationQueued;

  /// No description provided for @generationRunning.
  ///
  /// In en, this message translates to:
  /// **'Generating now'**
  String get generationRunning;

  /// No description provided for @generationFailed.
  ///
  /// In en, this message translates to:
  /// **'Attempt failed — safe to retry'**
  String get generationFailed;

  /// No description provided for @retryGeneration.
  ///
  /// In en, this message translates to:
  /// **'Retry generation'**
  String get retryGeneration;

  /// No description provided for @cancelGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this request?'**
  String get cancelGenerationTitle;

  /// No description provided for @cancelGenerationBody.
  ///
  /// In en, this message translates to:
  /// **'The pending request will be removed. Already saved stories are not affected.'**
  String get cancelGenerationBody;

  /// No description provided for @removeFromQueue.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get removeFromQueue;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Save PDF'**
  String get exportPdf;

  /// No description provided for @exportPdfDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save story as PDF'**
  String get exportPdfDialogTitle;

  /// No description provided for @exportingPdf.
  ///
  /// In en, this message translates to:
  /// **'Creating PDF…'**
  String get exportingPdf;

  /// No description provided for @pdfSaved.
  ///
  /// In en, this message translates to:
  /// **'PDF saved'**
  String get pdfSaved;

  /// No description provided for @pdfSaveCancelled.
  ///
  /// In en, this message translates to:
  /// **'PDF save cancelled'**
  String get pdfSaveCancelled;

  /// No description provided for @pdfExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save the PDF'**
  String get pdfExportFailed;

  /// No description provided for @exportPdfOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'PDF options'**
  String get exportPdfOptionsTitle;

  /// No description provided for @includePhotoOnCover.
  ///
  /// In en, this message translates to:
  /// **'Include {name}\'s photo on the cover'**
  String includePhotoOnCover(String name);

  /// No description provided for @exportPdfPhotoNotice.
  ///
  /// In en, this message translates to:
  /// **'A saved PDF is not encrypted and leaves the app.'**
  String get exportPdfPhotoNotice;

  /// No description provided for @pdfForHero.
  ///
  /// In en, this message translates to:
  /// **'for {name}'**
  String pdfForHero(String name);

  /// No description provided for @pdfBelongsTo.
  ///
  /// In en, this message translates to:
  /// **'This book belongs to {name}'**
  String pdfBelongsTo(String name);

  /// No description provided for @pdfMadeOn.
  ///
  /// In en, this message translates to:
  /// **'Made on {date}'**
  String pdfMadeOn(String date);

  /// No description provided for @pdfPageBadge.
  ///
  /// In en, this message translates to:
  /// **'Page {number} of {total}'**
  String pdfPageBadge(int number, int total);

  /// No description provided for @pdfMoralHeading.
  ///
  /// In en, this message translates to:
  /// **'The heart of this story'**
  String get pdfMoralHeading;

  /// No description provided for @pdfTheEnd.
  ///
  /// In en, this message translates to:
  /// **'The End'**
  String get pdfTheEnd;

  /// No description provided for @narrationSettings.
  ///
  /// In en, this message translates to:
  /// **'Narration settings'**
  String get narrationSettings;

  /// No description provided for @narrationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Reading speed'**
  String get narrationSpeed;

  /// No description provided for @slowSpeed.
  ///
  /// In en, this message translates to:
  /// **'Slow'**
  String get slowSpeed;

  /// No description provided for @normalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get normalSpeed;

  /// No description provided for @fastSpeed.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get fastSpeed;

  /// No description provided for @narrationScope.
  ///
  /// In en, this message translates to:
  /// **'Read aloud'**
  String get narrationScope;

  /// No description provided for @currentPage.
  ///
  /// In en, this message translates to:
  /// **'Current page'**
  String get currentPage;

  /// No description provided for @remainingStory.
  ///
  /// In en, this message translates to:
  /// **'From this page to the end'**
  String get remainingStory;

  /// No description provided for @applyNarrationSettings.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyNarrationSettings;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @sleepTimerOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get sleepTimerOff;

  /// No description provided for @sleepTimerMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String sleepTimerMinutes(int minutes);

  /// No description provided for @sleepTimerRemaining.
  ///
  /// In en, this message translates to:
  /// **'Narration stops in about {minutes} min.'**
  String sleepTimerRemaining(int minutes);

  /// No description provided for @kingdomStyleTitle.
  ///
  /// In en, this message translates to:
  /// **'Kingdom style'**
  String get kingdomStyleTitle;

  /// No description provided for @kingdomStyleBody.
  ///
  /// In en, this message translates to:
  /// **'Choose the castle, photo frame, backdrop, and symbol of {name}\'s kingdom.'**
  String kingdomStyleBody(String name);

  /// No description provided for @kingdomStyleSaved.
  ///
  /// In en, this message translates to:
  /// **'Kingdom style saved for {name}'**
  String kingdomStyleSaved(String name);

  /// No description provided for @kingdomCastle.
  ///
  /// In en, this message translates to:
  /// **'Castle'**
  String get kingdomCastle;

  /// No description provided for @castleClassicTowers.
  ///
  /// In en, this message translates to:
  /// **'Classic towers'**
  String get castleClassicTowers;

  /// No description provided for @castleRoundDomes.
  ///
  /// In en, this message translates to:
  /// **'Round domes'**
  String get castleRoundDomes;

  /// No description provided for @castleCrystalSpires.
  ///
  /// In en, this message translates to:
  /// **'Crystal spires'**
  String get castleCrystalSpires;

  /// No description provided for @castleForestTreehouse.
  ///
  /// In en, this message translates to:
  /// **'Forest treehouse'**
  String get castleForestTreehouse;

  /// No description provided for @kingdomAvatarFrame.
  ///
  /// In en, this message translates to:
  /// **'Photo frame'**
  String get kingdomAvatarFrame;

  /// No description provided for @avatarFrameNone.
  ///
  /// In en, this message translates to:
  /// **'Simple circle'**
  String get avatarFrameNone;

  /// No description provided for @avatarFrameStars.
  ///
  /// In en, this message translates to:
  /// **'Stars'**
  String get avatarFrameStars;

  /// No description provided for @avatarFrameHearts.
  ///
  /// In en, this message translates to:
  /// **'Hearts'**
  String get avatarFrameHearts;

  /// No description provided for @avatarFrameLaurel.
  ///
  /// In en, this message translates to:
  /// **'Laurel wreath'**
  String get avatarFrameLaurel;

  /// No description provided for @kingdomBackdrop.
  ///
  /// In en, this message translates to:
  /// **'Backdrop'**
  String get kingdomBackdrop;

  /// No description provided for @backdropNightSky.
  ///
  /// In en, this message translates to:
  /// **'Night sky'**
  String get backdropNightSky;

  /// No description provided for @backdropMeadow.
  ///
  /// In en, this message translates to:
  /// **'Meadow'**
  String get backdropMeadow;

  /// No description provided for @backdropOcean.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get backdropOcean;

  /// No description provided for @backdropSunset.
  ///
  /// In en, this message translates to:
  /// **'Sunset'**
  String get backdropSunset;

  /// No description provided for @kingdomSymbol.
  ///
  /// In en, this message translates to:
  /// **'Favourite symbol'**
  String get kingdomSymbol;

  /// No description provided for @symbolStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get symbolStar;

  /// No description provided for @symbolRocket.
  ///
  /// In en, this message translates to:
  /// **'Rocket'**
  String get symbolRocket;

  /// No description provided for @symbolCrown.
  ///
  /// In en, this message translates to:
  /// **'Crown'**
  String get symbolCrown;

  /// No description provided for @symbolButterfly.
  ///
  /// In en, this message translates to:
  /// **'Butterfly'**
  String get symbolButterfly;

  /// No description provided for @symbolDragon.
  ///
  /// In en, this message translates to:
  /// **'Dragon'**
  String get symbolDragon;

  /// No description provided for @symbolFlower.
  ///
  /// In en, this message translates to:
  /// **'Flower'**
  String get symbolFlower;

  /// No description provided for @symbolFootball.
  ///
  /// In en, this message translates to:
  /// **'Football'**
  String get symbolFootball;

  /// No description provided for @symbolMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get symbolMusic;

  /// No description provided for @symbolBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get symbolBook;

  /// No description provided for @symbolPaw.
  ///
  /// In en, this message translates to:
  /// **'Paw'**
  String get symbolPaw;

  /// No description provided for @symbolRainbow.
  ///
  /// In en, this message translates to:
  /// **'Rainbow'**
  String get symbolRainbow;

  /// No description provided for @symbolSparkles.
  ///
  /// In en, this message translates to:
  /// **'Sparkles'**
  String get symbolSparkles;

  /// No description provided for @readingComfortTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading comfort'**
  String get readingComfortTitle;

  /// No description provided for @readingComfortBody.
  ///
  /// In en, this message translates to:
  /// **'Choose how story pages look while {name} reads.'**
  String readingComfortBody(String name);

  /// No description provided for @readerTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readerTextSize;

  /// No description provided for @textSizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get textSizeSmall;

  /// No description provided for @textSizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get textSizeMedium;

  /// No description provided for @textSizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get textSizeLarge;

  /// No description provided for @textSizeExtraLarge.
  ///
  /// In en, this message translates to:
  /// **'Extra large'**
  String get textSizeExtraLarge;

  /// No description provided for @easyReadingFont.
  ///
  /// In en, this message translates to:
  /// **'Easy-reading font'**
  String get easyReadingFont;

  /// No description provided for @easyReadingFontHint.
  ///
  /// In en, this message translates to:
  /// **'Uses letter shapes made for reading practice in English, Swedish, and Somali stories. Arabic stories keep their usual letters.'**
  String get easyReadingFontHint;

  /// No description provided for @readingComfortSaved.
  ///
  /// In en, this message translates to:
  /// **'Reading comfort saved for {name}'**
  String readingComfortSaved(String name);

  /// No description provided for @bedtimeMode.
  ///
  /// In en, this message translates to:
  /// **'Bedtime mode'**
  String get bedtimeMode;

  /// No description provided for @turnOffBedtimeMode.
  ///
  /// In en, this message translates to:
  /// **'Turn off bedtime mode'**
  String get turnOffBedtimeMode;

  /// No description provided for @bedtimeSleepTimerApplied.
  ///
  /// In en, this message translates to:
  /// **'Bedtime mode set a {minutes} min sleep timer.'**
  String bedtimeSleepTimerApplied(int minutes);

  /// No description provided for @readingBadgesTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading badges'**
  String get readingBadgesTitle;

  /// No description provided for @readingBadgesBody.
  ///
  /// In en, this message translates to:
  /// **'Badges {name} earns by finishing stories. No streaks and no daily goals.'**
  String readingBadgesBody(String name);

  /// No description provided for @storiesFinished.
  ///
  /// In en, this message translates to:
  /// **'Stories finished: {count}'**
  String storiesFinished(int count);

  /// No description provided for @badgeFirstStory.
  ///
  /// In en, this message translates to:
  /// **'First story'**
  String get badgeFirstStory;

  /// No description provided for @badgeFiveStories.
  ///
  /// In en, this message translates to:
  /// **'Five stories'**
  String get badgeFiveStories;

  /// No description provided for @badgeTenStories.
  ///
  /// In en, this message translates to:
  /// **'Ten stories'**
  String get badgeTenStories;

  /// No description provided for @badgeTwentyFiveStories.
  ///
  /// In en, this message translates to:
  /// **'Twenty-five stories'**
  String get badgeTwentyFiveStories;

  /// No description provided for @badgeEarned.
  ///
  /// In en, this message translates to:
  /// **'New badge earned: {badge}'**
  String badgeEarned(String badge);

  /// No description provided for @nextBadgeProgress.
  ///
  /// In en, this message translates to:
  /// **'{count} more to go until {badge}.'**
  String nextBadgeProgress(int count, String badge);

  /// No description provided for @allBadgesEarned.
  ///
  /// In en, this message translates to:
  /// **'Every badge earned. Wonderful reading!'**
  String get allBadgesEarned;

  /// No description provided for @shareStoryFile.
  ///
  /// In en, this message translates to:
  /// **'Save story file'**
  String get shareStoryFile;

  /// No description provided for @storyFileNotice.
  ///
  /// In en, this message translates to:
  /// **'The story file is encrypted with this password. The child\'s photo is never included.'**
  String get storyFileNotice;

  /// No description provided for @createStoryPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a story file password'**
  String get createStoryPasswordTitle;

  /// No description provided for @enterStoryPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the story file password'**
  String get enterStoryPasswordTitle;

  /// No description provided for @storyFilePassword.
  ///
  /// In en, this message translates to:
  /// **'Story file password'**
  String get storyFilePassword;

  /// No description provided for @confirmStoryFilePassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm story file password'**
  String get confirmStoryFilePassword;

  /// No description provided for @storyFilePasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'The story file passwords do not match.'**
  String get storyFilePasswordMismatch;

  /// No description provided for @saveStoryFileDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Save encrypted Iam - hero story'**
  String get saveStoryFileDialogTitle;

  /// No description provided for @storyFileSaved.
  ///
  /// In en, this message translates to:
  /// **'Encrypted story file saved'**
  String get storyFileSaved;

  /// No description provided for @storyFileSaveCancelled.
  ///
  /// In en, this message translates to:
  /// **'Story file save cancelled'**
  String get storyFileSaveCancelled;

  /// No description provided for @importStoryFile.
  ///
  /// In en, this message translates to:
  /// **'Import story file'**
  String get importStoryFile;

  /// No description provided for @importStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Import this story?'**
  String get importStoryTitle;

  /// No description provided for @importStoryPages.
  ///
  /// In en, this message translates to:
  /// **'Pages: {count}'**
  String importStoryPages(int count);

  /// No description provided for @importStoryHero.
  ///
  /// In en, this message translates to:
  /// **'Hero in the file: {name}'**
  String importStoryHero(String name);

  /// No description provided for @importStoryChooseProfile.
  ///
  /// In en, this message translates to:
  /// **'Add the story to'**
  String get importStoryChooseProfile;

  /// No description provided for @importStoryAction.
  ///
  /// In en, this message translates to:
  /// **'Import story'**
  String get importStoryAction;

  /// No description provided for @storyImported.
  ///
  /// In en, this message translates to:
  /// **'Story imported: {title}'**
  String storyImported(String title);

  /// No description provided for @storyAlreadyOnDevice.
  ///
  /// In en, this message translates to:
  /// **'This story is already on this device.'**
  String get storyAlreadyOnDevice;

  /// No description provided for @importStoryNeedsProfile.
  ///
  /// In en, this message translates to:
  /// **'Add a hero profile before importing a story.'**
  String get importStoryNeedsProfile;

  /// No description provided for @storyFileWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'The password is wrong or the story file was changed.'**
  String get storyFileWrongPassword;

  /// No description provided for @storyFileInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a supported Iam - hero story file.'**
  String get storyFileInvalid;

  /// No description provided for @storyFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This story file is too large to open safely.'**
  String get storyFileTooLarge;

  /// No description provided for @storyFileReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The selected story file could not be read.'**
  String get storyFileReadFailed;

  /// No description provided for @storyFileFailed.
  ///
  /// In en, this message translates to:
  /// **'The story file action could not be completed.'**
  String get storyFileFailed;

  /// No description provided for @storyFileNewerVersion.
  ///
  /// In en, this message translates to:
  /// **'This story file was created by a newer version of the app.'**
  String get storyFileNewerVersion;

  /// No description provided for @aiConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'AI connection'**
  String get aiConnectionTitle;

  /// No description provided for @aiConnectionBody.
  ///
  /// In en, this message translates to:
  /// **'Choose whether new stories come from the offline sample or from the AI running on your own family PC.'**
  String get aiConnectionBody;

  /// No description provided for @aiConnectionParentNotice.
  ///
  /// In en, this message translates to:
  /// **'These controls are for parents only. Children never see the PC address or the pairing.'**
  String get aiConnectionParentNotice;

  /// No description provided for @storyGeneratorMode.
  ///
  /// In en, this message translates to:
  /// **'Story generator'**
  String get storyGeneratorMode;

  /// No description provided for @demoGeneratorMode.
  ///
  /// In en, this message translates to:
  /// **'Demo · offline sample'**
  String get demoGeneratorMode;

  /// No description provided for @localAiGeneratorMode.
  ///
  /// In en, this message translates to:
  /// **'Local AI on the PC'**
  String get localAiGeneratorMode;

  /// No description provided for @storyGeneratorModeSaved.
  ///
  /// In en, this message translates to:
  /// **'Story generator updated'**
  String get storyGeneratorModeSaved;

  /// No description provided for @bridgeAddress.
  ///
  /// In en, this message translates to:
  /// **'PC bridge address'**
  String get bridgeAddress;

  /// No description provided for @bridgeAddressHint.
  ///
  /// In en, this message translates to:
  /// **'http://127.0.0.1:8765'**
  String get bridgeAddressHint;

  /// No description provided for @bridgeAddressInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a full address, for example http://192.168.1.20:8765.'**
  String get bridgeAddressInvalid;

  /// No description provided for @saveBridgeAddress.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get saveBridgeAddress;

  /// No description provided for @bridgeAddressSaved.
  ///
  /// In en, this message translates to:
  /// **'PC bridge address saved'**
  String get bridgeAddressSaved;

  /// No description provided for @testBridgeConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testBridgeConnection;

  /// No description provided for @bridgeReachable.
  ///
  /// In en, this message translates to:
  /// **'The PC bridge answered. Version {version}.'**
  String bridgeReachable(String version);

  /// No description provided for @bridgeStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get bridgeStatusReady;

  /// No description provided for @bridgeStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get bridgeStatusUnavailable;

  /// No description provided for @bridgeLibraryStatus.
  ///
  /// In en, this message translates to:
  /// **'PC story library'**
  String get bridgeLibraryStatus;

  /// No description provided for @pairWithPc.
  ///
  /// In en, this message translates to:
  /// **'Pair with PC'**
  String get pairWithPc;

  /// No description provided for @pairDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair this device'**
  String get pairDeviceTitle;

  /// No description provided for @pairDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Look at the PC screen: it shows a 6-digit code for two minutes. Type that code here together with a name for this device.'**
  String get pairDeviceBody;

  /// No description provided for @pairingCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code from the PC'**
  String get pairingCode;

  /// No description provided for @pairingCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6 digits shown on the PC.'**
  String get pairingCodeInvalid;

  /// No description provided for @pairedDeviceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name for this device'**
  String get pairedDeviceNameLabel;

  /// No description provided for @pairedDeviceNameHint.
  ///
  /// In en, this message translates to:
  /// **'Family tablet'**
  String get pairedDeviceNameHint;

  /// No description provided for @pairedDeviceNameInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a name of up to {max} characters.'**
  String pairedDeviceNameInvalid(int max);

  /// No description provided for @confirmPairing.
  ///
  /// In en, this message translates to:
  /// **'Pair device'**
  String get confirmPairing;

  /// No description provided for @devicePaired.
  ///
  /// In en, this message translates to:
  /// **'Device paired with the PC'**
  String get devicePaired;

  /// No description provided for @devicePairedAs.
  ///
  /// In en, this message translates to:
  /// **'Paired with the PC as {name}'**
  String devicePairedAs(String name);

  /// No description provided for @deviceNotPaired.
  ///
  /// In en, this message translates to:
  /// **'This device is not paired with the PC yet.'**
  String get deviceNotPaired;

  /// No description provided for @forgetPairedDevice.
  ///
  /// In en, this message translates to:
  /// **'Forget this device'**
  String get forgetPairedDevice;

  /// No description provided for @forgetPairedDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'Forget this pairing?'**
  String get forgetPairedDeviceTitle;

  /// No description provided for @forgetPairedDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'This device stops using the PC until it is paired again. Remove it on the PC as well if it should not stay listed there.'**
  String get forgetPairedDeviceBody;

  /// No description provided for @pairedDeviceForgotten.
  ///
  /// In en, this message translates to:
  /// **'Pairing removed from this device'**
  String get pairedDeviceForgotten;

  /// No description provided for @openAiConnectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Open AI connection settings'**
  String get openAiConnectionSettings;

  /// No description provided for @localAiModeNotice.
  ///
  /// In en, this message translates to:
  /// **'Stories are written by the AI on your family PC. The PC, its bridge, and its model must be running.'**
  String get localAiModeNotice;

  /// No description provided for @generateLocalAiStory.
  ///
  /// In en, this message translates to:
  /// **'Generate story on the PC'**
  String get generateLocalAiStory;

  /// No description provided for @localAiSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Sending the request to the PC…'**
  String get localAiSubmitting;

  /// No description provided for @localAiQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the PC to start.'**
  String get localAiQueued;

  /// No description provided for @localAiQueuedPosition.
  ///
  /// In en, this message translates to:
  /// **'Waiting on the PC · {position} in line.'**
  String localAiQueuedPosition(int position);

  /// No description provided for @localAiWriting.
  ///
  /// In en, this message translates to:
  /// **'The PC is writing the story…'**
  String get localAiWriting;

  /// No description provided for @localAiChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the finished pages…'**
  String get localAiChecking;

  /// No description provided for @bridgeUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The PC did not answer. Check that the bridge is running and that the address is correct.'**
  String get bridgeUnreachable;

  /// No description provided for @bridgeTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The PC took too long to answer.'**
  String get bridgeTimedOut;

  /// No description provided for @bridgeNotPaired.
  ///
  /// In en, this message translates to:
  /// **'Pair this device with the PC before generating a story there.'**
  String get bridgeNotPaired;

  /// No description provided for @bridgeUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'The PC refused this device. Pair it again.'**
  String get bridgeUnauthorized;

  /// No description provided for @bridgeRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many pairing requests. Wait a minute and try again.'**
  String get bridgeRateLimited;

  /// No description provided for @bridgePairingNotFound.
  ///
  /// In en, this message translates to:
  /// **'That pairing is no longer waiting. Start a new one.'**
  String get bridgePairingNotFound;

  /// No description provided for @bridgePairingExpired.
  ///
  /// In en, this message translates to:
  /// **'The code expired. Ask the PC for a new one.'**
  String get bridgePairingExpired;

  /// No description provided for @bridgeInvalidPairingCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not correct. Five wrong codes cancel the pairing.'**
  String get bridgeInvalidPairingCode;

  /// No description provided for @bridgeInvalidRequest.
  ///
  /// In en, this message translates to:
  /// **'The PC refused this story request.'**
  String get bridgeInvalidRequest;

  /// No description provided for @bridgeJobNotFound.
  ///
  /// In en, this message translates to:
  /// **'The PC no longer knows this story request.'**
  String get bridgeJobNotFound;

  /// No description provided for @bridgeGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'The PC could not finish the story. Nothing was saved.'**
  String get bridgeGenerationFailed;

  /// No description provided for @bridgeGenerationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Story generation was cancelled. Nothing was saved.'**
  String get bridgeGenerationCancelled;

  /// No description provided for @bridgeInvalidResponse.
  ///
  /// In en, this message translates to:
  /// **'The PC answered with something this app cannot read.'**
  String get bridgeInvalidResponse;

  /// No description provided for @bridgeProblem.
  ///
  /// In en, this message translates to:
  /// **'The PC bridge reported a problem.'**
  String get bridgeProblem;

  /// No description provided for @bridgeStoryNotFound.
  ///
  /// In en, this message translates to:
  /// **'The PC no longer has this story.'**
  String get bridgeStoryNotFound;

  /// No description provided for @librarySyncTitle.
  ///
  /// In en, this message translates to:
  /// **'Offline story library'**
  String get librarySyncTitle;

  /// No description provided for @librarySyncBody.
  ///
  /// In en, this message translates to:
  /// **'Bring the family\'s stories from the PC onto this device so they can be read when the PC is off.'**
  String get librarySyncBody;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @librarySyncRunning.
  ///
  /// In en, this message translates to:
  /// **'Syncing with the PC…'**
  String get librarySyncRunning;

  /// No description provided for @librarySyncNever.
  ///
  /// In en, this message translates to:
  /// **'This device has not synced with the PC yet.'**
  String get librarySyncNever;

  /// No description provided for @librarySyncLastRun.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {moment}'**
  String librarySyncLastRun(String moment);

  /// No description provided for @librarySyncResult.
  ///
  /// In en, this message translates to:
  /// **'{added} new · {updated} updated · {removed} removed'**
  String librarySyncResult(int added, int updated, int removed);

  /// No description provided for @librarySyncUpToDate.
  ///
  /// In en, this message translates to:
  /// **'This device already matches the PC.'**
  String get librarySyncUpToDate;

  /// No description provided for @librarySyncPendingProfilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a hero profile'**
  String get librarySyncPendingProfilesTitle;

  /// No description provided for @librarySyncPendingProfile.
  ///
  /// In en, this message translates to:
  /// **'{count} stories for {name} stay on the PC: this device has no profile for that child.'**
  String librarySyncPendingProfile(int count, String name);

  /// No description provided for @librarySyncPendingProfilesBody.
  ///
  /// In en, this message translates to:
  /// **'A child\'s profile belongs to the device it was created on. Restore that device\'s backup here, or create stories for this child from this device, and their stories will sync too.'**
  String get librarySyncPendingProfilesBody;

  /// No description provided for @removedStoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Stories removed from this device'**
  String get removedStoriesTitle;

  /// No description provided for @removedStoriesBody.
  ///
  /// In en, this message translates to:
  /// **'{count} stories were removed from this device only. They are still on the PC, and sync leaves them alone until you ask for them.'**
  String removedStoriesBody(int count);

  /// No description provided for @redownloadRemovedStories.
  ///
  /// In en, this message translates to:
  /// **'Download them again'**
  String get redownloadRemovedStories;

  /// No description provided for @redownloadRemovedStoriesDone.
  ///
  /// In en, this message translates to:
  /// **'The next sync will bring those stories back'**
  String get redownloadRemovedStoriesDone;

  /// No description provided for @deleteBridgeStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Where should this story be deleted?'**
  String get deleteBridgeStoryTitle;

  /// No description provided for @deleteBridgeStoryBody.
  ///
  /// In en, this message translates to:
  /// **'This story is also in the library on the family PC, so there are two different things you can do.'**
  String get deleteBridgeStoryBody;

  /// No description provided for @removeStoryFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove from this device'**
  String get removeStoryFromDevice;

  /// No description provided for @removeStoryFromDeviceDetail.
  ///
  /// In en, this message translates to:
  /// **'Deletes the copy here. The story stays on the PC, and this device will not download it again until you ask for it.'**
  String get removeStoryFromDeviceDetail;

  /// No description provided for @deleteStoryEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Delete everywhere'**
  String get deleteStoryEverywhere;

  /// No description provided for @deleteStoryEverywhereDetail.
  ///
  /// In en, this message translates to:
  /// **'Deletes the story on the PC and on every device in the family. This cannot be undone, and the PC has to be reachable.'**
  String get deleteStoryEverywhereDetail;

  /// No description provided for @storyRemovedFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Story removed from this device'**
  String get storyRemovedFromDevice;

  /// No description provided for @storyDeletedEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Story deleted on the PC and on every device'**
  String get storyDeletedEverywhere;

  /// No description provided for @storyAlreadyDeletedEverywhere.
  ///
  /// In en, this message translates to:
  /// **'That story had already been deleted for the whole family'**
  String get storyAlreadyDeletedEverywhere;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @illustrateStory.
  ///
  /// In en, this message translates to:
  /// **'Illustrate this story'**
  String get illustrateStory;

  /// No description provided for @illustrateStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Make pictures for this story?'**
  String get illustrateStoryTitle;

  /// No description provided for @illustrateStoryBody.
  ///
  /// In en, this message translates to:
  /// **'The family PC draws one picture for every page. That takes a few minutes per page, so leave the PC on until it is finished. You can stop at any time and the pictures that are already done are kept.'**
  String get illustrateStoryBody;

  /// No description provided for @startIllustrating.
  ///
  /// In en, this message translates to:
  /// **'Make the pictures'**
  String get startIllustrating;

  /// No description provided for @stopIllustrating.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopIllustrating;

  /// No description provided for @illustrationsSendingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Sending the hero photo to the PC…'**
  String get illustrationsSendingPhoto;

  /// No description provided for @illustrationsSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Asking the PC to start drawing…'**
  String get illustrationsSubmitting;

  /// No description provided for @illustrationsDrawingAny.
  ///
  /// In en, this message translates to:
  /// **'The PC is drawing the pictures…'**
  String get illustrationsDrawingAny;

  /// No description provided for @illustrationsDrawing.
  ///
  /// In en, this message translates to:
  /// **'Drawing picture {done} of {total}…'**
  String illustrationsDrawing(int done, int total);

  /// No description provided for @illustrationsDownloading.
  ///
  /// In en, this message translates to:
  /// **'Bringing the finished pictures to this device…'**
  String get illustrationsDownloading;

  /// No description provided for @illustrationsReady.
  ///
  /// In en, this message translates to:
  /// **'{count} pictures are ready.'**
  String illustrationsReady(int count);

  /// No description provided for @illustrationsPartlyReady.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} pictures are ready. The PC could not draw the rest.'**
  String illustrationsPartlyReady(int done, int total);

  /// No description provided for @illustrationsNoneDrawn.
  ///
  /// In en, this message translates to:
  /// **'The PC could not draw any pictures.'**
  String get illustrationsNoneDrawn;

  /// No description provided for @illustrationsAlreadyDone.
  ///
  /// In en, this message translates to:
  /// **'Every page already has its picture.'**
  String get illustrationsAlreadyDone;

  /// No description provided for @illustrationsStopped.
  ///
  /// In en, this message translates to:
  /// **'Drawing stopped. The pictures that were finished are kept.'**
  String get illustrationsStopped;

  /// No description provided for @illustrationsNotFetched.
  ///
  /// In en, this message translates to:
  /// **'{count} pictures could not be brought to this device.'**
  String illustrationsNotFetched(int count);

  /// No description provided for @referencePhotoSkipped.
  ///
  /// In en, this message translates to:
  /// **'The hero photo could not be used, so the faces in the pictures are not their own.'**
  String get referencePhotoSkipped;

  /// No description provided for @librarySyncPictures.
  ///
  /// In en, this message translates to:
  /// **'{count} new pictures'**
  String librarySyncPictures(int count);

  /// No description provided for @bridgeProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'The PC does not know this child yet.'**
  String get bridgeProfileNotFound;

  /// No description provided for @bridgePhotoTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large for the PC.'**
  String get bridgePhotoTooLarge;

  /// No description provided for @bridgeUnsupportedImage.
  ///
  /// In en, this message translates to:
  /// **'The PC can only use a JPEG or a PNG photo.'**
  String get bridgeUnsupportedImage;

  /// No description provided for @bridgeIllustrationNotFound.
  ///
  /// In en, this message translates to:
  /// **'The PC no longer has that picture.'**
  String get bridgeIllustrationNotFound;

  /// No description provided for @bridgeIllustrationNotReady.
  ///
  /// In en, this message translates to:
  /// **'That picture has not been made yet.'**
  String get bridgeIllustrationNotReady;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'so', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'so':
      return AppLocalizationsSo();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
