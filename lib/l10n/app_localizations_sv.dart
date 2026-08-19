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
  String get birthDate => 'Födelsedatum';

  @override
  String get chooseBirthDate => 'Välj födelsedatum';

  @override
  String get changeBirthDate => 'Ändra datum';

  @override
  String get birthDateHelper =>
      'Åldern som används i berättelserna uppdateras vid varje födelsedag.';

  @override
  String birthDateLegacyAge(int age) {
    return 'Sparad ålder: $age. Välj ett födelsedatum så att den håller sig rätt.';
  }

  @override
  String get birthDateRequired => 'Välj barnets födelsedatum.';

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
  String get pauseNarration => 'Pausa berättarröst';

  @override
  String get resumeNarration => 'Fortsätt berättarröst';

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
      'Profiluppgifter, foton och berättelser stannar i enhetens lokala lagring om du inte exporterar en krypterad säkerhetskopia manuellt. Ingen analys eller betald molntjänst används.';

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

  @override
  String get parentSecurityTitle => 'Föräldraskydd';

  @override
  String get parentSecurityBody =>
      'En valfri lokal PIN-kod skyddar profiler, Mitt kungarike, inställningar och radering. Den ersätter inte enhetens säkerhet.';

  @override
  String get parentPin => 'Föräldra-PIN';

  @override
  String get parentPinConfigured =>
      'En föräldra-PIN är aktiverad på den här enheten.';

  @override
  String get parentPinNotConfigured =>
      'Ingen föräldra-PIN är inställd. Föräldrakontrollerna är öppna.';

  @override
  String get setParentPin => 'Ställ in PIN';

  @override
  String get changeParentPin => 'Byt PIN';

  @override
  String get removeParentPin => 'Ta bort PIN';

  @override
  String get lockParentArea => 'Lås nu';

  @override
  String get parentAreaLocked => 'Föräldraområdet är låst';

  @override
  String get enterParentPin =>
      'Ange den lokala föräldra-PIN-koden för att fortsätta.';

  @override
  String get incorrectParentPin => 'PIN-koden är fel.';

  @override
  String get unlock => 'Lås upp';

  @override
  String get newParentPin => 'Ny PIN';

  @override
  String get confirmParentPin => 'Bekräfta PIN';

  @override
  String get parentPinRequirements => 'Använd 4 till 8 siffror.';

  @override
  String get parentPinMismatch => 'PIN-koderna stämmer inte överens.';

  @override
  String get saveParentPin => 'Spara PIN';

  @override
  String get parentPinSaved => 'Föräldra-PIN sparades';

  @override
  String get parentPinRemoved => 'Föräldra-PIN togs bort';

  @override
  String get removeParentPinTitle => 'Ta bort föräldra-PIN?';

  @override
  String get removeParentPinBody =>
      'Föräldrakontrollerna förblir öppna på enheten tills en ny PIN ställs in.';

  @override
  String parentPinLockedSeconds(int seconds) {
    return 'För många försök. Försök igen om $seconds s.';
  }

  @override
  String parentPinLockedMinutes(int minutes) {
    return 'För många försök. Försök igen om $minutes min.';
  }

  @override
  String get changeParentPinTitle => 'Byt föräldra-PIN';

  @override
  String get currentParentPin => 'Nuvarande PIN';

  @override
  String get parentPinChanged => 'Föräldra-PIN ändrad';

  @override
  String get forgotParentPinBody =>
      'Det finns ingen återställning av PIN-koden. Om koden glöms bort är enda alternativet att radera all appdata; en krypterad säkerhetskopia återställer sedan familjens innehåll, eftersom en säkerhetskopia aldrig innehåller PIN-koden.';

  @override
  String get encryptedBackupTitle => 'Krypterad säkerhetskopia';

  @override
  String get encryptedBackupBody =>
      'Spara en lösenordsskyddad fil och återställ den på en annan enhet. Lösenordet sparas aldrig, så förvara det säkert.';

  @override
  String get exportEncryptedBackup => 'Exportera kopia';

  @override
  String get restoreEncryptedBackup => 'Återställ kopia';

  @override
  String get createBackupPasswordTitle => 'Skapa ett lösenord';

  @override
  String get enterBackupPasswordTitle => 'Ange säkerhetskopians lösenord';

  @override
  String get backupPassword => 'Lösenord för säkerhetskopian';

  @override
  String get confirmBackupPassword => 'Bekräfta lösenordet';

  @override
  String get backupPasswordRequirements =>
      'Använd minst 8 tecken. Lösenordet kan inte återställas.';

  @override
  String get backupPasswordMismatch => 'Lösenorden stämmer inte överens.';

  @override
  String get continueAction => 'Fortsätt';

  @override
  String get backupReadyTitle => 'Den krypterade kopian är klar';

  @override
  String get backupReadyBody =>
      'Välj Hämta säkerhetskopia för att spara den krypterade filen.';

  @override
  String get downloadBackup => 'Hämta säkerhetskopia';

  @override
  String get saveBackupDialogTitle => 'Spara krypterad Iam - hero-kopia';

  @override
  String get backupSaved => 'Den krypterade säkerhetskopian sparades';

  @override
  String restoreFileName(String name) {
    return 'Vald fil: $name';
  }

  @override
  String get confirmRestoreTitle => 'Ersätta lokala familjedata?';

  @override
  String confirmRestoreBody(int profiles, int stories) {
    return 'Kopian innehåller $profiles profiler och $stories berättelser. Återställning ersätter profiler, berättelser, aktiv hjälte och appspråk på den här enheten.';
  }

  @override
  String get restoreNow => 'Återställ nu';

  @override
  String get backupRestored => 'Den krypterade säkerhetskopian återställdes';

  @override
  String get backupWrongPassword =>
      'Lösenordet är fel eller säkerhetskopian har ändrats.';

  @override
  String get backupInvalid =>
      'Det här är inte en säkerhetskopia som stöds av Iam - hero.';

  @override
  String get backupTooLarge =>
      'Säkerhetskopian är för stor för att öppnas säkert.';

  @override
  String get backupFileReadFailed =>
      'Den valda säkerhetskopian kunde inte läsas.';

  @override
  String get backupFailed => 'Säkerhetskopieringen kunde inte slutföras.';

  @override
  String get backupNewerVersion =>
      'Den här säkerhetskopian skapades av en nyare version av appen.';

  @override
  String get storyPreferencesTitle => 'Berättelseval och trygghet';

  @override
  String storyPreferencesBody(String name) {
    return 'Välj vad som inspirerar ${name}s berättelser och vad lokal AI ska undvika.';
  }

  @override
  String get editStoryPreferences => 'Redigera berättelseval';

  @override
  String get defaultStoryLanguage => 'Förvalt berättelsespråk';

  @override
  String defaultStoryLanguageValue(String language) {
    return 'Förvalt språk: $language';
  }

  @override
  String get favoriteThings => 'Favoritsaker';

  @override
  String get favoriteThingsHint => 'Till exempel: tåg, katter, stjärnor';

  @override
  String favoriteThingsValue(String value) {
    return 'Favoritsaker: $value';
  }

  @override
  String get recurringWorld => 'Återkommande värld';

  @override
  String get recurringWorldHint => 'Till exempel: Det gyllene molnriket';

  @override
  String recurringWorldValue(String value) {
    return 'Återkommande värld: $value';
  }

  @override
  String get safetyControls => 'Ämnen att undvika';

  @override
  String get safetyControlsHint =>
      'Undantagen skickas till framtida lokal berättelse- och bildgenerering.';

  @override
  String safetyRulesValue(int count) {
    return 'Trygghetsundantag: $count';
  }

  @override
  String get avoidFrighteningContent => 'Skrämmande innehåll';

  @override
  String get avoidViolence => 'Våld eller skada';

  @override
  String get avoidBullying => 'Mobbning eller uteslutning';

  @override
  String get avoidGriefAndLoss => 'Sorg eller förlust';

  @override
  String get savePreferences => 'Spara inställningar';

  @override
  String storyPreferencesSaved(String name) {
    return 'Berättelseval sparades för $name';
  }

  @override
  String savedPreferencesInUse(String name, int count) {
    return 'Använder ${name}s sparade val och $count trygghetsundantag.';
  }

  @override
  String get reviewStoriesTitle => 'Förälders berättelsegranskning';

  @override
  String get reviewStoriesBody =>
      'Skapade utkast hålls utanför barnets bibliotek tills du har läst och godkänt dem.';

  @override
  String get reviewStoryTitle => 'Granska berättelsen';

  @override
  String get reviewStoryBody =>
      'Kontrollera önskemålet och varje sida innan berättelsen blir synlig i biblioteket.';

  @override
  String reviewDraftCount(int count) {
    return 'Granska utkast ($count)';
  }

  @override
  String get approveStory => 'Godkänn berättelse';

  @override
  String get storyApproved =>
      'Berättelsen godkändes och lades till i biblioteket';

  @override
  String get deleteDraft => 'Ta bort utkast';

  @override
  String get deleteDraftTitle => 'Ta bort utkastet?';

  @override
  String get deleteDraftBody =>
      'Det skapade utkastet tas bort permanent från enheten.';

  @override
  String reviewHero(String value) {
    return 'Hjälte: $value';
  }

  @override
  String reviewTheme(String value) {
    return 'Tema: $value';
  }

  @override
  String reviewMoral(String value) {
    return 'Lärdom: $value';
  }

  @override
  String reviewPageNumber(int number) {
    return 'Sida $number';
  }

  @override
  String get noDrafts => 'Inga berättelser väntar på granskning.';

  @override
  String get addFavorite => 'Lägg till som favorit';

  @override
  String get removeFavorite => 'Ta bort från favoriter';

  @override
  String get manageCollections => 'Hantera samlingar';

  @override
  String collectionsHint(int max) {
    return 'Ange upp till $max samlingsnamn, åtskilda med kommatecken eller nya rader.';
  }

  @override
  String get collectionNames => 'Samlingsnamn';

  @override
  String get collectionNamesHint => 'God natt, Rymdäventyr';

  @override
  String get saveCollections => 'Spara samlingar';

  @override
  String tooManyCollections(int max) {
    return 'Använd högst $max samlingar.';
  }

  @override
  String collectionNameTooLong(int max) {
    return 'Varje samlingsnamn får vara högst $max tecken.';
  }

  @override
  String get filterStories => 'Filtrera bokhyllan';

  @override
  String get allStories => 'Alla berättelser';

  @override
  String get favoriteStories => 'Favoriter';

  @override
  String get noStoriesInFilter => 'Inga berättelser matchar filtret ännu.';

  @override
  String get generationCenterTitle => 'Lokalt skapandecenter';

  @override
  String get generationCenterBody =>
      'Se vad som fungerar offline nu och försök säkert igen med önskemål som sparats före skapandet.';

  @override
  String get openGenerationCenter => 'Öppna skapandecentret';

  @override
  String get generationQueueTitle => 'Sparad skapandekö';

  @override
  String get generationQueueEmpty =>
      'Inga berättelseönskemål väntar eller har misslyckats.';

  @override
  String get demoGeneratorStatus => 'Offline-demogenerator';

  @override
  String get readyOffline => 'Redo offline';

  @override
  String get ollamaStatus => 'Ollama-berättelsemodell';

  @override
  String get comfyUiStatus => 'ComfyUI-illustrationer';

  @override
  String get notConnectedYet => 'Inte ansluten ännu';

  @override
  String get pcRequirementStatus =>
      'Demon fungerar när datorn är avstängd. När lokal AI ansluts senare måste datorn och modellerna vara igång för nya AI-berättelser; sparade böcker öppnas fortfarande offline.';

  @override
  String get generationQueued => 'I kö och sparad';

  @override
  String get generationRunning => 'Skapas nu';

  @override
  String get generationFailed =>
      'Försöket misslyckades — säkert att försöka igen';

  @override
  String get retryGeneration => 'Försök skapa igen';

  @override
  String get cancelGenerationTitle => 'Ta bort önskemålet?';

  @override
  String get cancelGenerationBody =>
      'Det väntande önskemålet tas bort. Redan sparade berättelser påverkas inte.';

  @override
  String get removeFromQueue => 'Ta bort från kön';

  @override
  String get exportPdf => 'Spara PDF';

  @override
  String get exportPdfDialogTitle => 'Spara berättelsen som PDF';

  @override
  String get exportingPdf => 'Skapar PDF…';

  @override
  String get pdfSaved => 'PDF-filen sparades';

  @override
  String get pdfSaveCancelled => 'Sparandet av PDF avbröts';

  @override
  String get pdfExportFailed => 'Det gick inte att spara PDF-filen';

  @override
  String get exportPdfOptionsTitle => 'PDF-alternativ';

  @override
  String includePhotoOnCover(String name) {
    return 'Ta med ${name}s foto på omslaget';
  }

  @override
  String get exportPdfPhotoNotice =>
      'En sparad PDF är inte krypterad och lämnar appen.';

  @override
  String get narrationSettings => 'Berättarinställningar';

  @override
  String get narrationSpeed => 'Läshastighet';

  @override
  String get slowSpeed => 'Långsam';

  @override
  String get normalSpeed => 'Normal';

  @override
  String get fastSpeed => 'Snabb';

  @override
  String get narrationScope => 'Läs upp';

  @override
  String get currentPage => 'Aktuell sida';

  @override
  String get remainingStory => 'Från den här sidan till slutet';

  @override
  String get applyNarrationSettings => 'Tillämpa';

  @override
  String get sleepTimer => 'Insomningstimer';

  @override
  String get sleepTimerOff => 'Av';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String sleepTimerRemaining(int minutes) {
    return 'Berättarrösten slutar om cirka $minutes min.';
  }

  @override
  String get kingdomStyleTitle => 'Kungarikets stil';

  @override
  String kingdomStyleBody(String name) {
    return 'Välj slott, fotoram, bakgrund och symbol för ${name}s kungarike.';
  }

  @override
  String kingdomStyleSaved(String name) {
    return 'Kungarikets stil sparad för $name';
  }

  @override
  String get kingdomCastle => 'Slott';

  @override
  String get castleClassicTowers => 'Klassiska torn';

  @override
  String get castleRoundDomes => 'Runda kupoler';

  @override
  String get castleCrystalSpires => 'Kristallspiror';

  @override
  String get castleForestTreehouse => 'Trädkoja i skogen';

  @override
  String get kingdomAvatarFrame => 'Fotoram';

  @override
  String get avatarFrameNone => 'Enkel cirkel';

  @override
  String get avatarFrameStars => 'Stjärnor';

  @override
  String get avatarFrameHearts => 'Hjärtan';

  @override
  String get avatarFrameLaurel => 'Lagerkrans';

  @override
  String get kingdomBackdrop => 'Bakgrund';

  @override
  String get backdropNightSky => 'Natthimmel';

  @override
  String get backdropMeadow => 'Äng';

  @override
  String get backdropOcean => 'Hav';

  @override
  String get backdropSunset => 'Solnedgång';

  @override
  String get kingdomSymbol => 'Favoritsymbol';

  @override
  String get symbolStar => 'Stjärna';

  @override
  String get symbolRocket => 'Raket';

  @override
  String get symbolCrown => 'Krona';

  @override
  String get symbolButterfly => 'Fjäril';

  @override
  String get symbolDragon => 'Drake';

  @override
  String get symbolFlower => 'Blomma';

  @override
  String get symbolFootball => 'Fotboll';

  @override
  String get symbolMusic => 'Musik';

  @override
  String get symbolBook => 'Bok';

  @override
  String get symbolPaw => 'Tass';

  @override
  String get symbolRainbow => 'Regnbåge';

  @override
  String get symbolSparkles => 'Gnistror';

  @override
  String get readingComfortTitle => 'Läskomfort';

  @override
  String readingComfortBody(String name) {
    return 'Välj hur berättelsesidorna ser ut när $name läser.';
  }

  @override
  String get readerTextSize => 'Textstorlek';

  @override
  String get textSizeSmall => 'Liten';

  @override
  String get textSizeMedium => 'Mellan';

  @override
  String get textSizeLarge => 'Stor';

  @override
  String get textSizeExtraLarge => 'Extra stor';

  @override
  String get easyReadingFont => 'Lättläst typsnitt';

  @override
  String get easyReadingFontHint =>
      'Använder bokstavsformer gjorda för lästräning i berättelser på engelska, svenska och somaliska. Arabiska berättelser behåller sina vanliga bokstäver.';

  @override
  String readingComfortSaved(String name) {
    return 'Läskomforten sparades för $name';
  }

  @override
  String get bedtimeMode => 'Godnattläge';

  @override
  String get turnOffBedtimeMode => 'Stäng av godnattläget';

  @override
  String bedtimeSleepTimerApplied(int minutes) {
    return 'Godnattläget satte en sovtimer på $minutes min.';
  }

  @override
  String get readingBadgesTitle => 'Läsmärken';

  @override
  String readingBadgesBody(String name) {
    return 'Märken som $name får genom att läsa ut berättelser. Inga serier och inga dagliga mål.';
  }

  @override
  String storiesFinished(int count) {
    return 'Utlästa berättelser: $count';
  }

  @override
  String get badgeFirstStory => 'Första berättelsen';

  @override
  String get badgeFiveStories => 'Fem berättelser';

  @override
  String get badgeTenStories => 'Tio berättelser';

  @override
  String get badgeTwentyFiveStories => 'Tjugofem berättelser';

  @override
  String badgeEarned(String badge) {
    return 'Nytt märke: $badge';
  }

  @override
  String nextBadgeProgress(int count, String badge) {
    return '$count kvar till $badge.';
  }

  @override
  String get allBadgesEarned => 'Alla märken tagna. Fantastisk läsning!';

  @override
  String get shareStoryFile => 'Spara berättelsefil';

  @override
  String get storyFileNotice =>
      'Berättelsefilen krypteras med det här lösenordet. Barnets foto följer aldrig med.';

  @override
  String get createStoryPasswordTitle =>
      'Skapa ett lösenord för berättelsefilen';

  @override
  String get enterStoryPasswordTitle => 'Ange lösenordet för berättelsefilen';

  @override
  String get storyFilePassword => 'Lösenord för berättelsefil';

  @override
  String get confirmStoryFilePassword =>
      'Bekräfta lösenordet för berättelsefilen';

  @override
  String get storyFilePasswordMismatch =>
      'Lösenorden för berättelsefilen matchar inte.';

  @override
  String get saveStoryFileDialogTitle =>
      'Spara krypterad Iam - hero-berättelse';

  @override
  String get storyFileSaved => 'Den krypterade berättelsefilen sparades';

  @override
  String get storyFileSaveCancelled => 'Sparandet av berättelsefilen avbröts';

  @override
  String get importStoryFile => 'Importera berättelsefil';

  @override
  String get importStoryTitle => 'Importera den här berättelsen?';

  @override
  String importStoryPages(int count) {
    return 'Sidor: $count';
  }

  @override
  String importStoryHero(String name) {
    return 'Hjälte i filen: $name';
  }

  @override
  String get importStoryChooseProfile => 'Lägg berättelsen hos';

  @override
  String get importStoryAction => 'Importera berättelse';

  @override
  String storyImported(String title) {
    return 'Berättelsen importerades: $title';
  }

  @override
  String get storyAlreadyOnDevice =>
      'Den här berättelsen finns redan på enheten.';

  @override
  String get importStoryNeedsProfile =>
      'Lägg till en hjälteprofil innan du importerar en berättelse.';

  @override
  String get storyFileWrongPassword =>
      'Lösenordet är fel eller berättelsefilen har ändrats.';

  @override
  String get storyFileInvalid =>
      'Det här är inte en berättelsefil som stöds av Iam - hero.';

  @override
  String get storyFileTooLarge =>
      'Berättelsefilen är för stor för att öppnas säkert.';

  @override
  String get storyFileReadFailed =>
      'Den valda berättelsefilen kunde inte läsas.';

  @override
  String get storyFileFailed =>
      'Åtgärden med berättelsefilen kunde inte slutföras.';

  @override
  String get storyFileNewerVersion =>
      'Den här berättelsefilen skapades av en nyare version av appen.';
}
