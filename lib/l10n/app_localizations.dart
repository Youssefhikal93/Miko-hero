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
  /// **'Miko-hero'**
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
  /// **'Create private, illustrated stories where your daughter is the hero.'**
  String get welcomeBody;

  /// No description provided for @createFirstStory.
  ///
  /// In en, this message translates to:
  /// **'Create her first story'**
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
  /// **'Set up her hero profile'**
  String get profileIncompleteTitle;

  /// No description provided for @profileIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Add her name, age, and a reference photo before creating a story.'**
  String get profileIncompleteBody;

  /// No description provided for @setUpProfile.
  ///
  /// In en, this message translates to:
  /// **'Set up profile'**
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

  /// No description provided for @profileIntro.
  ///
  /// In en, this message translates to:
  /// **'This information stays on this device and is never committed to the app\'s source code.'**
  String get profileIntro;

  /// No description provided for @daughterName.
  ///
  /// In en, this message translates to:
  /// **'Daughter\'s name'**
  String get daughterName;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

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
  /// **'Enter her name.'**
  String get nameRequired;

  /// No description provided for @ageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 1 to 17.'**
  String get ageInvalid;

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
  /// **'Create a story'**
  String get createStoryTitle;

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
  /// **'Soft picture book'**
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
  /// **'Local AI is not connected yet. Demo mode creates a clearly marked sample story so the complete app flow can be tested for free.'**
  String get demoModeNotice;

  /// No description provided for @profileNeeded.
  ///
  /// In en, this message translates to:
  /// **'Complete the hero profile first.'**
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
  /// **'Her story library'**
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
  /// **'Profile details, photos, and stories stay in local device storage. No analytics or paid cloud service is used.'**
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
  /// **'The profile, photo, and every story will be permanently deleted from this device.'**
  String get deleteAllBody;

  /// No description provided for @allDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'All local data was deleted'**
  String get allDataDeleted;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About Miko-hero'**
  String get aboutTitle;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'A private family storybook. Local Ollama and ComfyUI connections will be added in a later phase.'**
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
