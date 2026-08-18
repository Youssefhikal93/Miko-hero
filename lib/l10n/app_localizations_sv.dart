// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appName => 'Iam - hero';

  @override
  String get home => 'Hem';

  @override
  String get create => 'Skapa';

  @override
  String get library => 'Bibliotek';

  @override
  String get settings => 'Inställningar';

  @override
  String get welcomeTitle => 'Ett nytt äventyr börjar här';

  @override
  String get welcomeBody =>
      'Skapa privata, illustrerade berättelser där varje barn blir hjälten.';

  @override
  String get createFirstStory => 'Skapa en första berättelse';

  @override
  String get createAnotherStory => 'Skapa en ny berättelse';

  @override
  String get recentStories => 'Senaste berättelser';

  @override
  String get profileIncompleteTitle => 'Lägg till en hjälteprofil';

  @override
  String get profileIncompleteBody =>
      'Lägg till barnets namn, ålder, välj flicka eller pojke och lägg till ett referensfoto innan du skapar en berättelse.';

  @override
  String get setUpProfile => 'Lägg till profil';

  @override
  String get editProfile => 'Redigera hjälteprofil';

  @override
  String get profileTitle => 'Hjälteprofil';

  @override
  String get profilesTitle => 'Hjälteprofiler';

  @override
  String get profilesSubtitle =>
      'Lägg till en privat profil för varje barn som kan vara hjälte i en berättelse.';

  @override
  String get addProfile => 'Lägg till profil';

  @override
  String get manageProfiles => 'Hantera hjälteprofiler';

  @override
  String profileCount(int count) {
    return 'Profiler: $count';
  }

  @override
  String get noProfilesTitle => 'Inga hjälteprofiler ännu';

  @override
  String get noProfilesBody =>
      'Lägg till den första barnprofilen för att skapa personliga berättelser.';

  @override
  String get profileIntro =>
      'Barnets information stannar på enheten och sparas aldrig i appens källkod.';

  @override
  String get childName => 'Barnets namn';

  @override
  String get age => 'Ålder';

  @override
  String get genderTitle => 'Är hjälten en flicka eller pojke?';

  @override
  String get girl => 'Flicka';

  @override
  String get boy => 'Pojke';

  @override
  String get genderRequired => 'Välj flicka eller pojke.';

  @override
  String get genderNotSet => 'Flicka/pojke har inte valts';

  @override
  String get referencePhoto => 'Referensfoto';

  @override
  String get choosePhoto => 'Välj foto';

  @override
  String get replacePhoto => 'Byt foto';

  @override
  String get removePhoto => 'Ta bort foto';

  @override
  String get saveProfile => 'Spara profil';

  @override
  String get profileSaved => 'Profilen sparades';

  @override
  String get nameRequired => 'Ange barnets namn.';

  @override
  String get ageInvalid => 'Ange en ålder mellan 1 och 17.';

  @override
  String get photoTooLarge => 'Välj ett foto som är mindre än 2 MB.';

  @override
  String get photoReadFailed => 'Det valda fotot kunde inte läsas.';

  @override
  String get photoRequired => 'Välj ett referensfoto.';

  @override
  String get createStoryTitle => 'Skapa en berättelse';

  @override
  String get chooseHeroProfile => 'Välj en hjälteprofil';

  @override
  String get selectHeroProfile => 'Välj ett barn';

  @override
  String get profileSelectionRequired =>
      'Välj vilket barn som ska vara hjälten.';

  @override
  String get storyLanguage => 'Berättelsens språk';

  @override
  String get theme => 'Äventyrets tema';

  @override
  String get themeHint => 'Till exempel: en månträdgård';

  @override
  String get moral => 'Lärdom eller värde';

  @override
  String get moralHint => 'Till exempel: vänlighet och mod';

  @override
  String get storyLength => 'Berättelsens längd';

  @override
  String get illustrationStyle => 'Illustrationsstil';

  @override
  String get shortLength => 'Kort · 6 sidor';

  @override
  String get mediumLength => 'Mellan · 8 sidor';

  @override
  String get longLength => 'Lång · 10 sidor';

  @override
  String get pictureBookStyle => 'Mjuk bilderbok';

  @override
  String get watercolorStyle => 'Akvarell';

  @override
  String get threeDStyle => 'Färgstark 3D';

  @override
  String get generateStory => 'Skapa demoberättelse';

  @override
  String get demoModeNotice =>
      'Lokal AI är inte ansluten ännu. Demoläget skapar en tydligt markerad exempelberättelse så att hela appflödet kan testas gratis.';

  @override
  String get profileNeeded => 'Lägg först till minst en hjälteprofil.';

  @override
  String get themeRequired => 'Beskriv äventyrets tema.';

  @override
  String get moralRequired => 'Lägg till en lärdom eller ett värde.';

  @override
  String get generatingTitle => 'Bygger äventyret';

  @override
  String get generatingBody =>
      'Skriver sidor och förbereder den privata lokala boken…';

  @override
  String get storyCreated => 'Berättelsen är klar';

  @override
  String get libraryTitle => 'Familjens berättelsebibliotek';

  @override
  String get librarySubtitle =>
      'Färdiga berättelser lagras endast på den här enheten.';

  @override
  String get emptyLibraryTitle => 'Bokhyllan väntar';

  @override
  String get emptyLibraryBody => 'Skapa ett första äventyr så visas det här.';

  @override
  String get openStory => 'Öppna berättelse';

  @override
  String get delete => 'Ta bort';

  @override
  String get deleteStoryTitle => 'Ta bort berättelsen?';

  @override
  String get deleteStoryBody => 'Berättelsen tas bort permanent från enheten.';

  @override
  String get cancel => 'Avbryt';

  @override
  String get confirmDelete => 'Ta bort permanent';

  @override
  String get readStory => 'Läs berättelsen';

  @override
  String get previousPage => 'Föregående';

  @override
  String get nextPage => 'Nästa';

  @override
  String pageProgress(int current, int total) {
    return 'Sida $current av $total';
  }

  @override
  String get playNarration => 'Spela berättarröst';

  @override
  String get stopNarration => 'Stoppa berättarröst';

  @override
  String get narrationUnavailable =>
      'Ingen kompatibel röst är installerad för språket.';

  @override
  String get settingsTitle => 'Inställningar och integritet';

  @override
  String get appLanguage => 'Appspråk';

  @override
  String get privacyTitle => 'Lokalt och privat';

  @override
  String get privacyBody =>
      'Profiluppgifter, foton och berättelser stannar i enhetens lokala lagring. Ingen analys eller betald molntjänst används.';

  @override
  String get deleteAllData => 'Ta bort all lokal data';

  @override
  String get deleteAllTitle => 'Ta bort allt?';

  @override
  String get deleteAllBody =>
      'Alla profiler, foton och berättelser tas bort permanent från enheten.';

  @override
  String get allDataDeleted => 'All lokal data togs bort';

  @override
  String get aboutTitle => 'Om Iam - hero';

  @override
  String get aboutBody =>
      'En privat familjebilderbok. Lokala anslutningar till Ollama och ComfyUI läggs till i en senare fas.';

  @override
  String get english => 'Engelska';

  @override
  String get arabic => 'Arabiska';

  @override
  String get swedish => 'Svenska';

  @override
  String get somali => 'Somaliska';

  @override
  String get somethingWentWrong => 'Något gick fel.';

  @override
  String get retry => 'Försök igen';

  @override
  String get demoBadge => 'DEMO';

  @override
  String yearsOld(int age) {
    return '$age år';
  }

  @override
  String storyByHero(String name) {
    return 'Ett äventyr med $name i huvudrollen';
  }

  @override
  String get myKingdom => 'Mitt kungarike';

  @override
  String get kingdomTitle => 'Mitt kungarike';

  @override
  String get kingdomSubtitle =>
      'Välj en hjälte, uppdatera profilen och ge varje barn sin egen appfärg.';

  @override
  String get activeHero => 'Aktiv hjälte';

  @override
  String get chooseHero => 'Välj ett barn';

  @override
  String get editHeroProfile => 'Redigera namn och profil';

  @override
  String get addAnotherHero => 'Lägg till en hjälte';

  @override
  String get themeColor => 'Kungarikets färg';

  @override
  String themeColorHint(String name) {
    return 'Färgen sparas endast i profilen för $name.';
  }

  @override
  String get goldenTheme => 'Guld';

  @override
  String get roseTheme => 'Rosa';

  @override
  String get purpleTheme => 'Lila';

  @override
  String get cyanTheme => 'Cyan';

  @override
  String get greenTheme => 'Grön';

  @override
  String get customColor => 'Egen färg';

  @override
  String get customColorTitle => 'Välj en egen färg';

  @override
  String get hue => 'Färg';

  @override
  String get intensity => 'Intensitet';

  @override
  String get brightness => 'Ljusstyrka';

  @override
  String get applyColor => 'Använd färgen';

  @override
  String profileThemeSaved(String name) {
    return 'Färgen sparades för $name';
  }
}
