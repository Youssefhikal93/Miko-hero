// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Somali (`so`).
class AppLocalizationsSo extends AppLocalizations {
  AppLocalizationsSo([String locale = 'so']) : super(locale);

  @override
  String get appName => 'Iam - hero';

  @override
  String get home => 'Hoyga';

  @override
  String get create => 'Abuur';

  @override
  String get library => 'Maktabadda';

  @override
  String get settings => 'Dejinta';

  @override
  String get createFirstStory => 'Abuur sheekada ugu horreysa';

  @override
  String get profileIncompleteTitle => 'Ku dar bog halyey';

  @override
  String get profileIncompleteBody =>
      'Ku dar magaca ilmaha iyo da\'da, dooro gabar ama wiil, dabadeedna ku dar sawir tixraac ah ka hor intaadan sheeko abuurin.';

  @override
  String get setUpProfile => 'Ku dar bog';

  @override
  String get readingAs => 'Waxaad u akhrinaysaa';

  @override
  String get greetingMorning => 'Subax wanaagsan.';

  @override
  String get greetingAfternoon => 'Galab wanaagsan.';

  @override
  String get greetingEvening => 'Fiid wanaagsan.';

  @override
  String get greetingNight => 'Habeen wanaagsan.';

  @override
  String greetingContinueStory(String title) {
    return '$title weli waxay sugaysaa in la dhammaystiro.';
  }

  @override
  String get greetingDraftsWaiting =>
      'Sheekooyin cusub waxay sugayaan in waalid akhriyo.';

  @override
  String get greetingCreateStory => 'Sheekada caawa weli lama qorin.';

  @override
  String get keepReading => 'Sii wad akhriska';

  @override
  String get newStory => 'Sheeko cusub';

  @override
  String readingBadgesEarned(int earned, int total) {
    return '$earned ka $total';
  }

  @override
  String draftsWaitingForReview(int count) {
    return 'Qoraallo dib-u-eegis sugaya: $count';
  }

  @override
  String get draftsWaitingHint => 'Waalidiinta keliya · khaanadda kama muuqato';

  @override
  String get onTheShelf => 'Khaanadda buugta';

  @override
  String get seeAll => 'Arag dhammaan';

  @override
  String get editProfile => 'Wax ka beddel bogga halyeyga';

  @override
  String get profileTitle => 'Bogga halyeyga';

  @override
  String get profilesTitle => 'Bogagga halyeeyada';

  @override
  String get profilesSubtitle =>
      'Ku dar bog gaar ah ilmo kasta oo halyey ka noqon kara sheeko.';

  @override
  String get addProfile => 'Ku dar bog';

  @override
  String get manageProfiles => 'Maamul bogagga halyeeyada';

  @override
  String profileCount(int count) {
    return 'Bogagga: $count';
  }

  @override
  String get noProfilesTitle => 'Weli bog halyey ma jiro';

  @override
  String get noProfilesBody =>
      'Ku dar bogga ilmaha ugu horreeya si aad u bilowdo sheekooyin gaar ah.';

  @override
  String get profileIntro =>
      'Macluumaadka ilmahan wuxuu ku ekaanayaa qalabkan, lagumana kaydiyo koodhka app-ka.';

  @override
  String get childName => 'Magaca ilmaha';

  @override
  String get age => 'Da\'da';

  @override
  String get genderTitle => 'Halyeygani ma gabar baa mise wiil?';

  @override
  String get girl => 'Gabar';

  @override
  String get boy => 'Wiil';

  @override
  String get genderRequired => 'Dooro gabar ama wiil.';

  @override
  String get genderNotSet => 'Gabar/wiil lama dooran';

  @override
  String get referencePhoto => 'Sawirka tixraaca';

  @override
  String get choosePhoto => 'Dooro sawir';

  @override
  String get replacePhoto => 'Beddel sawirka';

  @override
  String get removePhoto => 'Ka saar sawirka';

  @override
  String get saveProfile => 'Kaydi bogga';

  @override
  String get profileSaved => 'Bogga waa la kaydiyay';

  @override
  String get nameRequired => 'Geli magaca ilmaha.';

  @override
  String get ageInvalid => 'Geli da\' u dhexeysa 1 iyo 17.';

  @override
  String get birthDate => 'Taariikhda dhalashada';

  @override
  String get chooseBirthDate => 'Dooro taariikhda dhalashada';

  @override
  String get changeBirthDate => 'Beddel taariikhda';

  @override
  String get birthDateHelper =>
      'Da\'da sheekooyinka lagu isticmaalo waxay is-cusboonaysiisaa maalin walba oo dhalasho.';

  @override
  String birthDateLegacyAge(int age) {
    return 'Da\'da la kaydiyay: $age. Dooro taariikh dhalasho si ay sax u sii ahaato.';
  }

  @override
  String get birthDateRequired => 'Dooro taariikhda dhalashada ilmaha.';

  @override
  String get photoTooLarge => 'Dooro sawir ka yar 2 MB.';

  @override
  String get photoReadFailed => 'Sawirka la doortay lama akhrin karin.';

  @override
  String get photoRequired => 'Dooro sawir tixraac ah.';

  @override
  String get createStoryTitle => 'Sheeko cusub';

  @override
  String get whoIsTheHero => 'Yaa ah halyeyga?';

  @override
  String get add => 'Ku dar';

  @override
  String heroAgeGender(int age, String gender) {
    return '$age · $gender';
  }

  @override
  String get whatHappens => 'Maxaa dhacaya?';

  @override
  String get lessonHint => 'Iyo casharka ay barayso';

  @override
  String get howLong => 'Intee le\'eg?';

  @override
  String get pages => 'bog';

  @override
  String get lookAndLanguage => 'Muuqaalka iyo luqadda';

  @override
  String get storyLanguageEnglish => 'English';

  @override
  String get storyLanguageArabic => 'العربية';

  @override
  String get storyLanguageSwedish => 'Svenska';

  @override
  String get storyLanguageSomali => 'Soomaali';

  @override
  String get writeTheStory => 'Qor sheekada';

  @override
  String get demoGeneratorLabel => 'Tijaabo';

  @override
  String get localAiGeneratorLabel => 'AI maxalli ah';

  @override
  String get profileSelectionRequired => 'Dooro ilmaha noqonaya halyeyga.';

  @override
  String get theme => 'Mawduuca tacaburka';

  @override
  String get themeHint => 'Tusaale: beer dayaxa ku taal';

  @override
  String get moral => 'Casharka ama qiimaha';

  @override
  String get pictureBookStyle => 'Buug sawir';

  @override
  String get watercolorStyle => 'Midab-biyood';

  @override
  String get threeDStyle => '3D midabbo badan';

  @override
  String get demoModeNotice =>
      'Habka tijaabadu wuxuu abuuraa sheeko tusaale ah oo si cad loo calaamadeeyay, PC la\'aan iyo AI la\'aan. Ku beddel abuuraha sheekada AI-ga maxalliga ah ee goobaha si loogu qoro PC-ga qoyska.';

  @override
  String get themeRequired => 'Sharax mawduuca tacaburka.';

  @override
  String get moralRequired => 'Ku dar cashar ama qiime.';

  @override
  String get generatingTitle => 'Tacaburka ayaa la dhisayaa';

  @override
  String get generatingBody =>
      'Bogagga ayaa la qorayaa, buugga gaarka ahna waa la diyaarinayaa…';

  @override
  String get storyCreated => 'Sheekadu waa diyaar';

  @override
  String get libraryTitle => 'Khaanadda buugaagta';

  @override
  String get librarySubtitle => 'Waxaa lagu kaydiyaa qalabkan oo keliya';

  @override
  String get libraryStoredWithPc =>
      'Waa la isku waafajiyaa kombiyuutarka qoyska';

  @override
  String get searchStoryTitles => 'Raadi cinwaannada';

  @override
  String get clearStorySearch => 'Nadiifi raadinta';

  @override
  String get emptyLibraryTitle => 'Khaanadda buugtu way sugaysaa';

  @override
  String get emptyLibraryBody =>
      'Abuur tacaburkii ugu horreeyay, halkan ayuuna ka muuqan doonaa.';

  @override
  String get openStory => 'Fur sheekada';

  @override
  String get delete => 'Tirtir';

  @override
  String get deleteStoryTitle => 'Ma tirtirtaa sheekadan?';

  @override
  String get deleteStoryBody =>
      'Sheekada si joogto ah ayaa looga tirtiri doonaa qalabkan.';

  @override
  String get cancel => 'Jooji';

  @override
  String get confirmDelete => 'Si joogto ah u tirtir';

  @override
  String get readStory => 'Akhri sheekada';

  @override
  String get previousPage => 'Hore';

  @override
  String get nextPage => 'Xiga';

  @override
  String pageProgress(int current, int total) {
    return 'Bogga $current ee $total';
  }

  @override
  String get readToMe => 'Ii akhri';

  @override
  String get playNarration => 'Daar akhriska';

  @override
  String get pauseNarration => 'Hakad akhriska';

  @override
  String get resumeNarration => 'Sii wad akhriska';

  @override
  String get stopNarration => 'Jooji akhriska';

  @override
  String get narrationUnavailable =>
      'Cod ku habboon luqaddan kuma rakibna qalabka.';

  @override
  String get settingsTitle => 'Dejinta iyo gaar ahaanshaha';

  @override
  String get appLanguage => 'Luqadda app-ka';

  @override
  String get privacyTitle => 'Maxalli iyo gaar ah';

  @override
  String get privacyBody =>
      'Xogta bogagga, sawirrada iyo sheekooyinka waxay ku jiraan kaydka qalabka ilaa aad gacanta uga dhoofiso kayd sirgaxan. Falanqayn ama adeeg daruureed oo lacag leh lama isticmaalo.';

  @override
  String get deleteAllData => 'Tirtir dhammaan xogta maxalliga ah';

  @override
  String get deleteAllTitle => 'Wax walba ma tirtirtaa?';

  @override
  String get deleteAllBody =>
      'Dhammaan bogagga, sawirrada, iyo sheekooyinka si joogto ah ayaa looga tirtiri doonaa qalabkan.';

  @override
  String get allDataDeleted => 'Dhammaan xogta maxalliga ah waa la tirtiray';

  @override
  String get aboutTitle => 'Ku saabsan Iam - hero';

  @override
  String get aboutBody =>
      'Buug sheeko qoys oo gaar ah. Sheekooyinka waxaa qora moodel Ollama ah, sawirradana waxaa sawira ComfyUI, labaduba PC-gaaga ayay ku shaqeeyaan.';

  @override
  String get english => 'Ingiriisi';

  @override
  String get arabic => 'Carabi';

  @override
  String get swedish => 'Iswiidhish';

  @override
  String get somali => 'Soomaali';

  @override
  String get somethingWentWrong => 'Waxbaa khaldamay.';

  @override
  String get retry => 'Mar kale isku day';

  @override
  String get demoBadge => 'TIJAABO';

  @override
  String yearsOld(int age) {
    return '$age sano jir';
  }

  @override
  String storyByHero(String name) {
    return 'Tacabur ay $name halyey ka tahay';
  }

  @override
  String get myKingdom => 'Boqortooyadayda';

  @override
  String get kingdomTitle => 'Boqortooyadayda';

  @override
  String get kingdomSubtitle =>
      'Dooro halyey, wax ka beddel boggiisa, ilmo kastana sii midab app oo u gaar ah.';

  @override
  String get activeHero => 'Halyeyga hadda';

  @override
  String get chooseHero => 'Dooro ilmo';

  @override
  String get editHeroProfile => 'Beddel magaca iyo bogga';

  @override
  String get addAnotherHero => 'Ku dar halyey kale';

  @override
  String get themeColor => 'Midabka boqortooyada';

  @override
  String themeColorHint(String name) {
    return 'Midabkan waxaa lagu kaydiyaa bogga $name oo keliya.';
  }

  @override
  String get goldenTheme => 'Dahabi';

  @override
  String get roseTheme => 'Casaan khafiif ah';

  @override
  String get purpleTheme => 'Guduud';

  @override
  String get cyanTheme => 'Buluug-cagaar';

  @override
  String get greenTheme => 'Cagaar';

  @override
  String get customColor => 'Midab gaar ah';

  @override
  String get customColorTitle => 'Dooro midab gaar ah';

  @override
  String get hue => 'Midabka';

  @override
  String get intensity => 'Xoogga midabka';

  @override
  String get brightness => 'Iftiinka';

  @override
  String get applyColor => 'Isticmaal midabkan';

  @override
  String profileThemeSaved(String name) {
    return 'Midabka $name waa la kaydiyay';
  }

  @override
  String get parentSecurityTitle => 'Ilaalinta waalidka';

  @override
  String get parentSecurityBody =>
      'PIN maxalli ah oo ikhtiyaari ah ayaa ilaaliya bogagga, Boqortooyadayda, dejinta iyo tirtirka. Ma beddelayo amniga qalabka.';

  @override
  String get parentPin => 'PIN-ka waalidka';

  @override
  String get parentPinConfigured => 'PIN waalid ayaa ka shaqaynaya qalabkan.';

  @override
  String get parentPinNotConfigured =>
      'PIN waalid lama dejin. Xakamaynta waalidka way furan tahay.';

  @override
  String get setParentPin => 'Deji PIN waalid';

  @override
  String get changeParentPin => 'Beddel PIN';

  @override
  String get removeParentPin => 'Ka saar PIN';

  @override
  String get lockParentArea => 'Hadda quful';

  @override
  String get parentAreaLocked => 'Qaybta waalidka waa qufulan tahay';

  @override
  String get enterParentPin =>
      'Geli PIN-ka waalidka ee maxalliga ah si aad u sii waddo.';

  @override
  String get incorrectParentPin => 'PIN-kaasi waa khalad.';

  @override
  String get unlock => 'Fur qufulka';

  @override
  String get newParentPin => 'PIN cusub';

  @override
  String get confirmParentPin => 'Xaqiiji PIN';

  @override
  String get parentPinRequirements => 'Isticmaal 4 ilaa 8 lambar.';

  @override
  String get parentPinMismatch => 'PIN-yadu isma laha.';

  @override
  String get saveParentPin => 'Kaydi PIN';

  @override
  String get parentPinSaved => 'PIN-ka waalidka waa la kaydiyay';

  @override
  String get parentPinRemoved => 'PIN-ka waalidka waa laga saaray';

  @override
  String get removeParentPinTitle => 'Ma ka saartaa PIN-ka waalidka?';

  @override
  String get removeParentPinBody =>
      'Xakamaynta waalidku way furnaan doontaa ilaa PIN cusub la dejiyo.';

  @override
  String parentPinLockedSeconds(int seconds) {
    return 'Isku dayo aad u badan. Isku day mar kale $seconds ilbiriqsi ka dib.';
  }

  @override
  String parentPinLockedMinutes(int minutes) {
    return 'Isku dayo aad u badan. Isku day mar kale $minutes daqiiqo ka dib.';
  }

  @override
  String get changeParentPinTitle => 'Beddel PIN-ka waalidka';

  @override
  String get currentParentPin => 'PIN-ka hadda';

  @override
  String get parentPinChanged => 'PIN-ka waalidka waa la beddelay';

  @override
  String get forgotParentPinBody =>
      'Ma jirto hab lagu soo celiyo PIN-ka. Haddii PIN-ka la illoobo, xulashada kaliya waa in la tirtiro dhammaan xogta app-ka; kadibna kayd sirgaxan wuxuu soo celinayaa xogta qoyska, maxaa yeelay kaydku waligiis PIN-ka kuma jiro.';

  @override
  String get encryptedBackupTitle => 'Kayd sirgaxan';

  @override
  String get encryptedBackupBody =>
      'Kaydi fayl eray-sir leh oo ku soo celi qalab kale. Erayga sirta lama kaydiyo, si ammaan ah u xafid.';

  @override
  String get exportEncryptedBackup => 'Dhoofi kaydka';

  @override
  String get restoreEncryptedBackup => 'Soo celi kaydka';

  @override
  String get createBackupPasswordTitle => 'Samee erayga sirta kaydka';

  @override
  String get enterBackupPasswordTitle => 'Geli erayga sirta kaydka';

  @override
  String get backupPassword => 'Erayga sirta kaydka';

  @override
  String get confirmBackupPassword => 'Xaqiiji erayga sirta';

  @override
  String get backupPasswordRequirements =>
      'Isticmaal ugu yaraan 8 xaraf. Eraygan sirta ah dib looma heli karo.';

  @override
  String get backupPasswordMismatch => 'Erayada sirta ahi isma laha.';

  @override
  String get continueAction => 'Sii wad';

  @override
  String get backupReadyTitle => 'Kaydka sirgaxan waa diyaar';

  @override
  String get backupReadyBody =>
      'Dooro Soo dejiso kaydka si aad u kaydiso faylka sirgaxan.';

  @override
  String get downloadBackup => 'Soo dejiso kaydka';

  @override
  String get saveBackupDialogTitle => 'Kaydi nuqulka sirgaxan ee Iam - hero';

  @override
  String get backupSaved => 'Kaydka sirgaxan waa la kaydiyay';

  @override
  String restoreFileName(String name) {
    return 'Faylka la doortay: $name';
  }

  @override
  String get confirmRestoreTitle => 'Ma beddeshaa xogta qoyska ee qalabkan?';

  @override
  String confirmRestoreBody(int profiles, int stories) {
    return 'Kaydkani wuxuu leeyahay $profiles bog iyo $stories sheeko. Soo celintu waxay beddelaysaa bogagga, sheekooyinka, halyeyga firfircoon iyo luqadda app-ka.';
  }

  @override
  String get restoreNow => 'Hadda soo celi';

  @override
  String get backupRestored => 'Kaydka sirgaxan waa la soo celiyay';

  @override
  String get backupWrongPassword =>
      'Erayga sirta waa khalad ama kaydka waa la beddelay.';

  @override
  String get backupInvalid => 'Kani ma aha kayd Iam - hero oo la taageero.';

  @override
  String get backupTooLarge =>
      'Kaydkani aad buu u weyn yahay in si ammaan ah loo furo.';

  @override
  String get backupFileReadFailed => 'Kaydka la doortay lama akhrin karin.';

  @override
  String get backupFailed => 'Hawsha kaydka lama dhammaystiri karin.';

  @override
  String get backupNewerVersion =>
      'Kaydkan waxaa sameeyay nooc app ah oo ka cusub kan.';

  @override
  String get storyPreferencesTitle => 'Doorbidka sheekada iyo badbaadada';

  @override
  String storyPreferencesBody(String name) {
    return 'Dooro waxa dhiirrigeliya sheekooyinka $name iyo waxa AI-ga maxalliga ahi ka fogaanayo.';
  }

  @override
  String get editStoryPreferences => 'Beddel doorbidka sheekada';

  @override
  String get defaultStoryLanguage => 'Luqadda sheekada ee caadiga ah';

  @override
  String defaultStoryLanguageValue(String language) {
    return 'Luqadda caadiga ah: $language';
  }

  @override
  String get favoriteThings => 'Waxyaabaha uu jecel yahay';

  @override
  String get favoriteThingsHint => 'Tusaale: tareenno, bisado, xiddigo';

  @override
  String favoriteThingsValue(String value) {
    return 'Waxyaabaha la jecel yahay: $value';
  }

  @override
  String get recurringWorld => 'Dunida soo noqnoqota';

  @override
  String get recurringWorldHint => 'Tusaale: Boqortooyada Daruurta Dahabka';

  @override
  String recurringWorldValue(String value) {
    return 'Dunida soo noqnoqota: $value';
  }

  @override
  String get safetyControls => 'Mawduucyada laga fogaado';

  @override
  String get safetyControlsHint =>
      'Ka-reebitaannadan waxaa loo gudbin doonaa samaynta sheeko iyo sawir ee maxalliga ah mustaqbalka.';

  @override
  String safetyRulesValue(int count) {
    return 'Ka-reebitaannada badbaadada: $count';
  }

  @override
  String get avoidFrighteningContent => 'Waxyaabo cabsi leh';

  @override
  String get avoidViolence => 'Rabshad ama dhaawac';

  @override
  String get avoidBullying => 'Cagajuglayn ama ka-saarid';

  @override
  String get avoidGriefAndLoss => 'Murugo ama lumis';

  @override
  String get savePreferences => 'Kaydi doorbidka';

  @override
  String storyPreferencesSaved(String name) {
    return 'Doorbidka sheekada ee $name waa la kaydiyay';
  }

  @override
  String savedPreferencesInUse(String name, int count) {
    return 'Waxaa la isticmaalayaa doorbidka $name iyo $count ka-reebitaan badbaado.';
  }

  @override
  String get reviewStoriesTitle => 'Dib-u-eegista sheekada ee waalidka';

  @override
  String get reviewStoriesBody =>
      'Qabyada la sameeyay kama muuqato maktabadda ilmaha ilaa aad akhrido oo ansixiso.';

  @override
  String get reviewStoryTitle => 'Dib u eeg sheekadan';

  @override
  String get reviewStoryBody =>
      'Hubi codsiga iyo bog kasta ka hor inta sheekadu ka muuqan maktabadda.';

  @override
  String reviewDraftCount(int count) {
    return 'Dib u eeg qabyada ($count)';
  }

  @override
  String get approveStory => 'Ansixi sheekada';

  @override
  String get storyApproved =>
      'Sheekada waa la ansixiyay oo maktabadda lagu daray';

  @override
  String get deleteDraft => 'Tirtir qabyada';

  @override
  String get deleteDraftTitle => 'Ma tirtirtaa qabyadan?';

  @override
  String get deleteDraftBody =>
      'Qabyadan la sameeyay si joogto ah ayaa qalabka looga tirtirayaa.';

  @override
  String reviewHero(String value) {
    return 'Halyeyga: $value';
  }

  @override
  String reviewTheme(String value) {
    return 'Mawduuca: $value';
  }

  @override
  String reviewMoral(String value) {
    return 'Casharka: $value';
  }

  @override
  String reviewPageNumber(int number) {
    return 'Bogga $number';
  }

  @override
  String get noDrafts => 'Sheeko dib-u-eegis sugaysa ma jirto.';

  @override
  String get moreStoryActions => 'Ficillo kale oo sheekada';

  @override
  String storyPageCount(int count) {
    return '$count bogag';
  }

  @override
  String get addFavorite => 'Ku dar kuwa la jecel yahay';

  @override
  String get removeFavorite => 'Ka saar kuwa la jecel yahay';

  @override
  String get manageCollections => 'Maamul ururinta';

  @override
  String collectionsHint(int max) {
    return 'Geli ilaa $max magac ururin, kuna kala saar hakad ama sadar cusub.';
  }

  @override
  String get collectionNames => 'Magacyada ururinta';

  @override
  String get collectionNamesHint => 'Waqtiga hurdada, Tacaburrada hawada';

  @override
  String get saveCollections => 'Kaydi ururinta';

  @override
  String tooManyCollections(int max) {
    return 'Isticmaal ugu badnaan $max ururin.';
  }

  @override
  String collectionNameTooLong(int max) {
    return 'Magac kasta oo ururin ahi ha ahaado $max xaraf ama ka yar.';
  }

  @override
  String allStoriesCount(int count) {
    return 'Dhammaan $count';
  }

  @override
  String get favoriteStories => 'Kuwa la jecel yahay';

  @override
  String get noStoriesInFilter =>
      'Weli sheeko ku habboon kala-saarkan ma jirto.';

  @override
  String get noStoriesMatchSearch =>
      'Khaanaddan kuma jiro cinwaan raadintaas u dhigma.';

  @override
  String get generationCenterTitle => 'Xarunta samaynta maxalliga ah';

  @override
  String get generationCenterBody =>
      'Arag waxa hadda offline u shaqeeya oo si ammaan ah dib ugu celi codsiyada la kaydiyay ka hor samaynta.';

  @override
  String get openGenerationCenter => 'Fur xarunta samaynta';

  @override
  String get generationQueueTitle => 'Safka samaynta ee kaydsan';

  @override
  String get generationQueueEmpty =>
      'Codsi sheeko oo sugaya ama fashilmay ma jiro.';

  @override
  String get demoGeneratorStatus => 'Sameeyaha tijaabada offline';

  @override
  String get readyOffline => 'Offline ayuu diyaar yahay';

  @override
  String get ollamaStatus => 'Qaabka sheekada Ollama';

  @override
  String get comfyUiStatus => 'Sawirrada ComfyUI';

  @override
  String get notConnectedYet => 'Weli lama xirin';

  @override
  String get pcRequirementStatus =>
      'Tijaabadu way shaqaysaa marka PC-gu damsan yahay. Sheekooyinka AI-ga maxalliga ah waxay u baahan yihiin in PC-ga, buundadiisa iyo moodelkiisu shaqaynayaan; buugaagta kaydsan had iyo jeer offline ayay u furmaan.';

  @override
  String get generationQueued => 'Saf ku jira oo kaydsan';

  @override
  String get generationRunning => 'Hadda ayaa la samaynayaa';

  @override
  String get generationFailed =>
      'Isku daygu wuu fashilmay — si ammaan ah dib ugu celi';

  @override
  String get retryGeneration => 'Dib u samee';

  @override
  String get cancelGenerationTitle => 'Ma ka saartaa codsigan?';

  @override
  String get cancelGenerationBody =>
      'Codsiga sugaya waa laga saarayaa. Sheekooyinka hore loo kaydiyay waxba ma gaarayaan.';

  @override
  String get removeFromQueue => 'Ka saar safka';

  @override
  String get exportPdf => 'Keydi PDF';

  @override
  String get exportPdfDialogTitle => 'Sheekada PDF ahaan u keydi';

  @override
  String get exportingPdf => 'PDF ayaa la diyaarinayaa…';

  @override
  String get pdfSaved => 'PDF waa la keydiyay';

  @override
  String get pdfSaveCancelled => 'Keydinta PDF waa la joojiyay';

  @override
  String get pdfExportFailed => 'PDF lama keydin karin';

  @override
  String get exportPdfOptionsTitle => 'Doorashooyinka PDF';

  @override
  String includePhotoOnCover(String name) {
    return 'Ku dar sawirka $name daboolka';
  }

  @override
  String get exportPdfPhotoNotice =>
      'PDF-ka la kaydiyay sir kuma jiro oo app-ka wuu ka baxayaa.';

  @override
  String pdfForHero(String name) {
    return 'loogu talagalay $name';
  }

  @override
  String pdfBelongsTo(String name) {
    return 'Buuggan waxaa iska leh $name';
  }

  @override
  String pdfMadeOn(String date) {
    return 'Waxaa la sameeyay $date';
  }

  @override
  String pdfPageBadge(int number, int total) {
    return 'Bogga $number ee $total';
  }

  @override
  String get pdfMoralHeading => 'Wadnaha sheekadan';

  @override
  String get pdfTheEnd => 'Dhammaad';

  @override
  String get narrationSettings => 'Dejinta akhrinta codka';

  @override
  String get narrationSpeed => 'Xawaaraha akhrinta';

  @override
  String get slowSpeed => 'Gaabis';

  @override
  String get normalSpeed => 'Caadi';

  @override
  String get fastSpeed => 'Degdeg';

  @override
  String get narrationScope => 'Kor u akhri';

  @override
  String get currentPage => 'Bogga hadda';

  @override
  String get remainingStory => 'Boggan ilaa dhammaadka';

  @override
  String get applyNarrationSettings => 'Dhaqan geli';

  @override
  String get sleepTimer => 'Waqtiga hurdada';

  @override
  String get sleepTimerOff => 'Damin';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes daqiiqo';
  }

  @override
  String sleepTimerRemaining(int minutes) {
    return 'Akhrisku wuxuu joogsan doonaa qiyaastii $minutes daqiiqo.';
  }

  @override
  String get kingdomStyleTitle => 'Qaabka boqortooyada';

  @override
  String kingdomStyleBody(String name) {
    return 'Dooro qalcadda, qaybta sawirka, gadaasha iyo calaamadda boqortooyada $name.';
  }

  @override
  String kingdomStyleSaved(String name) {
    return 'Qaabka boqortooyada waa loo keydiyay $name';
  }

  @override
  String get kingdomCastle => 'Qalcad';

  @override
  String get castleClassicTowers => 'Munaarado hore';

  @override
  String get castleRoundDomes => 'Qubado wareegsan';

  @override
  String get castleCrystalSpires => 'Fiiqyo dhalaalaya';

  @override
  String get castleForestTreehouse => 'Guri geed oo kaynta ku yaal';

  @override
  String get kingdomAvatarFrame => 'Qaybta sawirka';

  @override
  String get avatarFrameNone => 'Goobaabin fudud';

  @override
  String get avatarFrameStars => 'Xiddigo';

  @override
  String get avatarFrameHearts => 'Wadnayaal';

  @override
  String get avatarFrameLaurel => 'Taaj caleemo ah';

  @override
  String get kingdomBackdrop => 'Gadaasha';

  @override
  String get backdropNightSky => 'Cirka habeenkii';

  @override
  String get backdropMeadow => 'Doog cagaaran';

  @override
  String get backdropOcean => 'Badweyn';

  @override
  String get backdropSunset => 'Qorrax dhac';

  @override
  String get kingdomSymbol => 'Calaamadda la jecel yahay';

  @override
  String get symbolStar => 'Xiddig';

  @override
  String get symbolRocket => 'Gantaal';

  @override
  String get symbolCrown => 'Taaj';

  @override
  String get symbolButterfly => 'Balanbaalis';

  @override
  String get symbolDragon => 'Masduulaa';

  @override
  String get symbolFlower => 'Ubax';

  @override
  String get symbolFootball => 'Kubbadda cagta';

  @override
  String get symbolMusic => 'Muusik';

  @override
  String get symbolBook => 'Buug';

  @override
  String get symbolPaw => 'Cago xayawaan';

  @override
  String get symbolRainbow => 'Qaanso roobaad';

  @override
  String get symbolSparkles => 'Dhalaal';

  @override
  String get readingComfortTitle => 'Raaxada akhriska';

  @override
  String readingComfortBody(String name) {
    return 'Dooro sida bogagga sheekada u muuqdaan marka $name akhrinayo.';
  }

  @override
  String get readerTextSize => 'Cabbirka qoraalka';

  @override
  String get textSizeSmall => 'Yar';

  @override
  String get textSizeMedium => 'Dhexdhexaad';

  @override
  String get textSizeLarge => 'Weyn';

  @override
  String get textSizeExtraLarge => 'Aad u weyn';

  @override
  String get easyReadingFont => 'Far akhris fudud';

  @override
  String get easyReadingFontHint =>
      'Waxay isticmaashaa xarfo loo sameeyay tababarka akhriska ee sheekooyinka Ingiriisiga, Iswidhishka iyo Soomaaliga. Sheekooyinka Carabiga waxay sii haystaan xarfahooda caadiga ah.';

  @override
  String readingComfortSaved(String name) {
    return 'Raaxada akhriska ee $name waa la kaydiyay';
  }

  @override
  String get bedtimeMode => 'Habka waqtiga hurdada';

  @override
  String get turnOffBedtimeMode => 'Dami habka waqtiga hurdada';

  @override
  String bedtimeSleepTimerApplied(int minutes) {
    return 'Habka waqtiga hurdada wuxuu dejiyay saacad hurdo $minutes daqiiqo ah.';
  }

  @override
  String get readingBadgesTitle => 'Calaamadaha akhriska';

  @override
  String readingBadgesBody(String name) {
    return 'Calaamadaha $name ku helo dhammaystirka sheekooyinka. Ma leh tiro-maalmeed ama himilo maalinle.';
  }

  @override
  String storiesFinished(int count) {
    return 'Sheekooyinka la dhammeeyay: $count';
  }

  @override
  String get badgeFirstStory => 'Sheekada koowaad';

  @override
  String get badgeFiveStories => 'Shan sheeko';

  @override
  String get badgeTenStories => 'Toban sheeko';

  @override
  String get badgeTwentyFiveStories => 'Shan iyo labaatan sheeko';

  @override
  String badgeEarned(String badge) {
    return 'Calaamad cusub: $badge';
  }

  @override
  String nextBadgeProgress(int count, String badge) {
    return 'Waxaa hadhay $count inta lagu gaarayo $badge.';
  }

  @override
  String get allBadgesEarned =>
      'Dhammaan calaamadaha waa la helay. Akhris cajiib ah!';

  @override
  String get shareStoryFile => 'Kaydi faylka sheekada';

  @override
  String get storyFileNotice =>
      'Faylka sheekada waxaa lagu sirgaliyay erayga sirtan, sawirka ilmaha marnaba lama darin.';

  @override
  String get createStoryPasswordTitle => 'Samee eray sir oo faylka sheekada';

  @override
  String get enterStoryPasswordTitle => 'Geli erayga sirta ee faylka sheekada';

  @override
  String get storyFilePassword => 'Erayga sirta ee faylka sheekada';

  @override
  String get confirmStoryFilePassword =>
      'Xaqiiji erayga sirta ee faylka sheekada';

  @override
  String get storyFilePasswordMismatch =>
      'Erayada sirta ee faylka sheekada isku mid ma aha.';

  @override
  String get saveStoryFileDialogTitle =>
      'Kaydi sheekada sirgaxan ee Iam - hero';

  @override
  String get storyFileSaved => 'Faylka sheekada sirgaxan waa la kaydiyay';

  @override
  String get storyFileSaveCancelled =>
      'Kaydinta faylka sheekada waa la joojiyay';

  @override
  String get importStoryFile => 'Soo deji faylka sheekada';

  @override
  String get importStoryTitle => 'Ma soo dejinaysaa sheekadan?';

  @override
  String importStoryPages(int count) {
    return 'Bogag: $count';
  }

  @override
  String importStoryHero(String name) {
    return 'Halyeyga faylka: $name';
  }

  @override
  String get importStoryChooseProfile => 'Sheekada ku dar';

  @override
  String get importStoryAction => 'Soo deji sheekada';

  @override
  String storyImported(String title) {
    return 'Sheekada waa la soo dejiyay: $title';
  }

  @override
  String get storyAlreadyOnDevice =>
      'Sheekadan mar hore waa ku jirtaa qalabkan.';

  @override
  String get importStoryNeedsProfile =>
      'Ku dar bog halyey ka hor inta aad sheeko soo dejin.';

  @override
  String get storyFileWrongPassword =>
      'Erayga sirta waa khalad ama faylka sheekada waa la beddelay.';

  @override
  String get storyFileInvalid =>
      'Kani ma aha fayl sheeko Iam - hero oo la taageero.';

  @override
  String get storyFileTooLarge =>
      'Faylkan sheekada aad buu u weyn yahay in si ammaan ah loo furo.';

  @override
  String get storyFileReadFailed =>
      'Faylka sheekada la doortay lama akhrin karin.';

  @override
  String get storyFileFailed =>
      'Hawsha faylka sheekada lama dhammaystiri karin.';

  @override
  String get storyFileNewerVersion =>
      'Faylkan sheekada waxaa sameeyay nooc app ah oo ka cusub kan.';

  @override
  String get aiConnectionTitle => 'Xiriirka AI-ga';

  @override
  String get aiConnectionBody =>
      'Dooro in sheekooyinka cusub ka yimaadaan tusaalaha offline mise AI-ga ku shaqeeya PC-ga qoyska.';

  @override
  String get aiConnectionParentNotice =>
      'Xakamayntanu waxay u gaar tahay waalidiinta oo keliya. Carruurtu waligood ma arkaan cinwaanka PC-ga ama xiriirinta.';

  @override
  String get storyGeneratorMode => 'Abuuraha sheekada';

  @override
  String get demoGeneratorMode => 'Tijaabo · tusaale offline';

  @override
  String get localAiGeneratorMode => 'AI maxalli ah oo PC-ga ku jira';

  @override
  String get storyGeneratorModeSaved =>
      'Abuuraha sheekada waa la cusboonaysiiyay';

  @override
  String get bridgeAddress => 'Cinwaanka buundada PC-ga';

  @override
  String get bridgeAddressHint => 'http://127.0.0.1:8765';

  @override
  String get bridgeAddressInvalid =>
      'Geli cinwaan buuxa, tusaale http://192.168.1.20:8765.';

  @override
  String get saveBridgeAddress => 'Kaydi cinwaanka';

  @override
  String get bridgeAddressSaved => 'Cinwaanka buundada PC-ga waa la kaydiyay';

  @override
  String get testBridgeConnection => 'Tijaabi xiriirka';

  @override
  String bridgeReachable(String version) {
    return 'Buundada PC-gu way jawaabtay. Nooca $version.';
  }

  @override
  String get bridgeStatusReady => 'Diyaar';

  @override
  String get bridgeStatusUnavailable => 'Lama helo';

  @override
  String get bridgeLibraryStatus => 'Maktabadda sheekooyinka PC-ga';

  @override
  String get pairWithPc => 'Ku xir PC-ga';

  @override
  String get pairDeviceTitle => 'Xir qalabkan';

  @override
  String get pairDeviceBody =>
      'Eeg shaashadda PC-ga: waxay muujinaysaa koodh 6 lambar ah muddo laba daqiiqo ah. Halkan ku qor koodhka iyo magac qalabkan.';

  @override
  String get pairingCode => 'Koodhka 6-da lambar ee PC-ga';

  @override
  String get pairingCodeInvalid => 'Geli lixda lambar ee PC-ga lagu muujiyay.';

  @override
  String get pairedDeviceNameLabel => 'Magaca qalabkan';

  @override
  String get pairedDeviceNameHint => 'Tabletka qoyska';

  @override
  String pairedDeviceNameInvalid(int max) {
    return 'Geli magac aan ka badnayn $max xaraf.';
  }

  @override
  String get confirmPairing => 'Xir qalabka';

  @override
  String get devicePaired => 'Qalabka waa lagu xiray PC-ga';

  @override
  String devicePairedAs(String name) {
    return 'Lagu xiray PC-ga magaca $name';
  }

  @override
  String get deviceNotPaired => 'Qalabkan weli lagama xirin PC-ga.';

  @override
  String get forgetPairedDevice => 'Iloow qalabkan';

  @override
  String get forgetPairedDeviceTitle => 'Ma illoobaysaa xiriirintan?';

  @override
  String get forgetPairedDeviceBody =>
      'Qalabkani wuu joojinayaa isticmaalka PC-ga ilaa mar kale la xiro. Sidoo kale PC-ga ka saar haddii aanad rabin inuu liiska ku sii jiro.';

  @override
  String get pairedDeviceForgotten => 'Xiriirinta waa laga saaray qalabkan';

  @override
  String get openAiConnectionSettings => 'Fur goobaha xiriirka AI-ga';

  @override
  String get localAiModeNotice =>
      'Sheekooyinka waxaa qora AI-ga PC-ga qoyska. PC-ga, buundadiisa iyo moodelkiisu waa inay shaqaynayaan.';

  @override
  String get localAiSubmitting => 'Codsiga waxaa loo dirayaa PC-ga…';

  @override
  String get localAiQueued => 'Sugaya in PC-gu bilaabo.';

  @override
  String localAiQueuedPosition(int position) {
    return 'Sugaya PC-ga · kaalinta $position safka.';
  }

  @override
  String get localAiWriting => 'PC-gu wuxuu qorayaa sheekada…';

  @override
  String get localAiChecking => 'Waxaa la hubinayaa bogagga dhammaaday…';

  @override
  String get bridgeUnreachable =>
      'PC-gu ma jawaabin. Hubi in buundadu shaqaynayso iyo in cinwaanku sax yahay.';

  @override
  String get bridgeBlockedByBrowser =>
      'Browser-ku uma oggolaan boggan inuu la xiriiro PC-ga. PC-ga laftiisa, ama qalab Tailscale ku shaqeeyo, fur dejinta bogga ee browser-ka, u deji \"Local network access\" Oggolow, kadibna dib u kici bogga. Haddii ay weli fashilanto, hubi in buundadu shaqaynayso iyo in cinwaanku sax yahay.';

  @override
  String get bridgeTimedOut =>
      'PC-gu wuxuu qaatay waqti aad u dheer inuu jawaabo.';

  @override
  String get bridgeNotPaired =>
      'Qalabkan ku xir PC-ga ka hor inta aanad sheeko halkaas ka samayn.';

  @override
  String get bridgeUnauthorized =>
      'PC-gu wuu diiday qalabkan. Mar kale ku xir.';

  @override
  String get bridgeRateLimited =>
      'Codsiyo xiriirin ah oo aad u badan. Sug daqiiqad kadibna isku day.';

  @override
  String get bridgePairingNotFound =>
      'Xiriirintaas hadda ma sugayso. Mid cusub bilow.';

  @override
  String get bridgePairingExpired =>
      'Koodhku wuu dhacay. PC-ga ka codso mid cusub.';

  @override
  String get bridgeInvalidPairingCode =>
      'Koodhkaas sax ma aha. Shan koodh oo khaldan ayaa xiriirinta joojinaysa.';

  @override
  String get bridgeInvalidRequest => 'PC-gu wuu diiday codsigan sheeko.';

  @override
  String get bridgeJobNotFound => 'PC-gu hadda ma garanayo codsigan sheeko.';

  @override
  String get bridgeGenerationFailed =>
      'PC-gu ma dhammaystiri karin sheekada. Waxba lama kaydin.';

  @override
  String get bridgeGenerationCancelled =>
      'Samaynta sheekada waa la joojiyay. Waxba lama kaydin.';

  @override
  String get bridgeInvalidResponse =>
      'PC-gu wuxuu ku jawaabay wax uusan app-ku akhrin karin.';

  @override
  String get bridgeProblem => 'Buundada PC-gu waxay soo sheegtay dhibaato.';

  @override
  String get bridgeStoryNotFound => 'PC-gu hadda ma haysto sheekadan.';

  @override
  String get librarySyncTitle => 'Maktabad sheeko offline ah';

  @override
  String get librarySyncBody =>
      'Sheekooyinka qoyska ka soo dejiso PC-ga qalabkan si loo akhriyi karo xataa marka PC-gu damsan yahay.';

  @override
  String get syncNow => 'Isku hab hadda';

  @override
  String get librarySyncRunning => 'Waa la isku habaynayaa PC-ga…';

  @override
  String get librarySyncNever => 'Qalabkan weli lama isku habayn PC-ga.';

  @override
  String librarySyncLastRun(String moment) {
    return 'Isku habaynta ugu dambeysay: $moment';
  }

  @override
  String librarySyncResult(int added, int updated, int removed) {
    return '$added cusub · $updated cusboonaysiiyay · $removed laga saaray';
  }

  @override
  String get librarySyncUpToDate => 'Qalabkan horeba wuu la mid yahay PC-ga.';

  @override
  String get librarySyncPendingProfilesTitle => 'Sugaya bogga halyeeyga';

  @override
  String librarySyncPendingProfile(int count, String name) {
    return '$count sheeko oo $name leeyahay waxay ku hadhayaan PC-ga: qalabkan bog uma laha ilmahaas.';
  }

  @override
  String get librarySyncPendingProfilesBody =>
      'Bogga ilmaha wuxuu ka tirsan yahay qalabkii lagu abuuray. Halkan ku soo celi kaydka qalabkaas, ama sheekooyin ilmahaas u samee qalabkan, markaas sheekooyinkiisana way isku habayn doonaan.';

  @override
  String get removedStoriesTitle => 'Sheekooyin laga saaray qalabkan';

  @override
  String removedStoriesBody(int count) {
    return '$count sheeko waxaa laga saaray oo keliya qalabkan. Weli waxay ku jiraan PC-ga, isku habayntuna kama soo dejinayso ilaa aad codsato.';
  }

  @override
  String get redownloadRemovedStories => 'Mar kale soo dejiso';

  @override
  String get redownloadRemovedStoriesDone =>
      'Isku habaynta soo socota ayaa sheekooyinkaas soo celinaysa';

  @override
  String get deleteBridgeStoryTitle => 'Xagee sheekada laga tirtirayo?';

  @override
  String get deleteBridgeStoryBody =>
      'Sheekadan waxay sidoo kale ku jirtaa maktabadda PC-ga qoyska, sidaas darteed laba dooro oo kala duwan ayaa jira.';

  @override
  String get removeStoryFromDevice => 'Ka saar qalabkan';

  @override
  String get removeStoryFromDeviceDetail =>
      'Waxay tirtiraysaa nuqulka halkan. Sheekadu waxay ku sii jirtaa PC-ga, qalabkanna mar dambe kama soo dejinayo ilaa aad codsato.';

  @override
  String get deleteStoryEverywhere => 'Meel kasta ka tirtir';

  @override
  String get deleteStoryEverywhereDetail =>
      'Waxay sheekada ka tirtiraysaa PC-ga iyo qalab kasta oo qoyska. Lama noqon karo, PC-guna waa inuu la xiriirayo.';

  @override
  String get storyRemovedFromDevice => 'Sheekada waa laga saaray qalabkan';

  @override
  String get storyDeletedEverywhere =>
      'Sheekada waa laga tirtiray PC-ga iyo qalab kasta';

  @override
  String get storyAlreadyDeletedEverywhere =>
      'Sheekadaas horeba waa loo tirtiray qoyska oo dhan';

  @override
  String get close => 'Xir';

  @override
  String get illustrateStory => 'Sawirro u samee sheekadan';

  @override
  String get illustrateStoryTitle => 'Ma sawirro u samaynaysaa sheekadan?';

  @override
  String get illustrateStoryBody =>
      'PC-ga qoyska wuxuu bog kasta u sawiraa hal sawir. Bog kasta waxay qaadataa dhowr daqiiqo, sidaas darteed PC-ga sii shid ilaa uu dhammaysto. Waqti kasta waad joojin kartaa, sawirradii diyaar noqday na way sii hadhayaan.';

  @override
  String get startIllustrating => 'Samee sawirrada';

  @override
  String get stopIllustrating => 'Jooji';

  @override
  String get illustrationsSendingPhoto =>
      'Sawirka halyeeyga waxaa loo dirayaa PC-ga…';

  @override
  String get illustrationsSubmitting =>
      'PC-ga waxaa laga codsanayaa inuu sawirka bilaabo…';

  @override
  String get illustrationsDrawingAny => 'PC-gu wuxuu sawirayaa sawirrada…';

  @override
  String illustrationsDrawing(int done, int total) {
    return 'Waxaa la sawirayaa sawirka $done ee $total…';
  }

  @override
  String get illustrationsDownloading =>
      'Sawirrada dhammaaday waxaa loo soo dejinayaa qalabkan…';

  @override
  String illustrationsReady(int count) {
    return '$count sawir diyaar bay yihiin.';
  }

  @override
  String illustrationsPartlyReady(int done, int total) {
    return '$done sawir oo $total ah diyaar bay yihiin. PC-gu ma sawiri karin kuwa kale.';
  }

  @override
  String get illustrationsNoneDrawn => 'PC-gu sawir midna ma sawiri karin.';

  @override
  String get illustrationsAlreadyDone =>
      'Bog kastaa horeba wuxuu leeyahay sawirkiisa.';

  @override
  String get illustrationsStopped =>
      'Sawirku waa istaagay. Sawirradii dhammaaday way sii hadhayaan.';

  @override
  String illustrationsNotFetched(int count) {
    return '$count sawir lama soo dejin karin qalabkan.';
  }

  @override
  String get referencePhotoSkipped =>
      'Sawirka halyeeyga lama isticmaali karin, sidaas darteed wejiyada sawirrada ku jira kuwiisa ma aha.';

  @override
  String librarySyncPictures(int count) {
    return '$count sawir cusub';
  }

  @override
  String get bridgeProfileNotFound => 'PC-gu weli ma garanayo ilmahan.';

  @override
  String get bridgePhotoTooLarge => 'Sawirkaas aad buu u weyn yahay PC-ga.';

  @override
  String get bridgeUnsupportedImage =>
      'PC-gu wuxuu keliya isticmaali karaa sawir JPEG ama PNG ah.';

  @override
  String get bridgeIllustrationNotFound => 'PC-gu hadda ma haysto sawirkaas.';

  @override
  String get bridgeIllustrationNotReady => 'Sawirkaas weli lama samayn.';
}
