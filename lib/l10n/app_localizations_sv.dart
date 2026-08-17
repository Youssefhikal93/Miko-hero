// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appName => 'Miko-hero';

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
      'Skapa privata, illustrerade berättelser där din dotter är hjälten.';

  @override
  String get createFirstStory => 'Skapa hennes första berättelse';

  @override
  String get createAnotherStory => 'Skapa en ny berättelse';

  @override
  String get recentStories => 'Senaste berättelser';

  @override
  String get profileIncompleteTitle => 'Skapa hennes hjälteprofil';

  @override
  String get profileIncompleteBody =>
      'Lägg till namn, ålder och ett referensfoto innan du skapar en berättelse.';

  @override
  String get setUpProfile => 'Skapa profil';

  @override
  String get editProfile => 'Redigera hjälteprofil';

  @override
  String get profileTitle => 'Hjälteprofil';

  @override
  String get profileIntro =>
      'Informationen stannar på enheten och sparas aldrig i appens källkod.';

  @override
  String get daughterName => 'Dotterns namn';

  @override
  String get age => 'Ålder';

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
  String get nameRequired => 'Ange hennes namn.';

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
  String get profileNeeded => 'Slutför hjälteprofilen först.';

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
  String get libraryTitle => 'Hennes berättelsebibliotek';

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
      'Profilen, fotot och alla berättelser tas bort permanent från enheten.';

  @override
  String get allDataDeleted => 'All lokal data togs bort';

  @override
  String get aboutTitle => 'Om Miko-hero';

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
}
