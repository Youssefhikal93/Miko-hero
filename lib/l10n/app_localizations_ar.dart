// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'Iam - hero';

  @override
  String get home => 'الرئيسية';

  @override
  String get create => 'إنشاء';

  @override
  String get library => 'المكتبة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get createFirstStory => 'أنشئ القصة الأولى';

  @override
  String get profileIncompleteTitle => 'أضف ملف بطل';

  @override
  String get profileIncompleteBody =>
      'أضف اسم الطفل وعمره واختر فتاة أو فتى وأضف صورة مرجعية قبل إنشاء القصة.';

  @override
  String get setUpProfile => 'إضافة ملف';

  @override
  String get readingAs => 'القراءة باسم';

  @override
  String get greetingMorning => 'صباح الخير.';

  @override
  String get greetingAfternoon => 'طاب نهارك.';

  @override
  String get greetingEvening => 'مساء الخير.';

  @override
  String get greetingNight => 'طابت ليلتك.';

  @override
  String greetingContinueStory(String title) {
    return '$title تنتظر أن تُكمَل.';
  }

  @override
  String get greetingDraftsWaiting => 'قصص جديدة تنتظر أن يقرأها أحد الوالدين.';

  @override
  String get greetingCreateStory => 'قصة هذه الليلة لم تُكتب بعد.';

  @override
  String get keepReading => 'تابع القراءة';

  @override
  String get newStory => 'قصة جديدة';

  @override
  String readingBadgesEarned(int earned, int total) {
    return '$earned من $total';
  }

  @override
  String draftsWaitingForReview(int count) {
    return 'مسودات بانتظار المراجعة: $count';
  }

  @override
  String get draftsWaitingHint => 'للوالدين فقط · لا تظهر على الرف';

  @override
  String get onTheShelf => 'على الرف';

  @override
  String get seeAll => 'عرض الكل';

  @override
  String get editProfile => 'تعديل ملف البطل';

  @override
  String get profileTitle => 'ملف البطل';

  @override
  String get profilesTitle => 'ملفات الأبطال';

  @override
  String get profilesSubtitle =>
      'أضف ملفًا خاصًا لكل طفل يمكنه أن يكون بطل قصة.';

  @override
  String get addProfile => 'إضافة ملف';

  @override
  String get manageProfiles => 'إدارة ملفات الأبطال';

  @override
  String profileCount(int count) {
    return 'الملفات: $count';
  }

  @override
  String get noProfilesTitle => 'لا توجد ملفات أبطال بعد';

  @override
  String get noProfilesBody => 'أضف ملف الطفل الأول لبدء إنشاء قصص مخصصة.';

  @override
  String get profileIntro =>
      'تبقى معلومات هذا الطفل على الجهاز ولا تُحفظ أبدًا في الشفرة المصدرية للتطبيق.';

  @override
  String get childName => 'اسم الطفل';

  @override
  String get age => 'العمر';

  @override
  String get genderTitle => 'هل هذا البطل فتاة أم فتى؟';

  @override
  String get girl => 'فتاة';

  @override
  String get boy => 'فتى';

  @override
  String get genderRequired => 'اختر فتاة أو فتى.';

  @override
  String get genderNotSet => 'لم يتم اختيار فتاة أو فتى';

  @override
  String get referencePhoto => 'الصورة المرجعية';

  @override
  String get choosePhoto => 'اختيار صورة';

  @override
  String get replacePhoto => 'تغيير الصورة';

  @override
  String get removePhoto => 'حذف الصورة';

  @override
  String get saveProfile => 'حفظ الملف';

  @override
  String get profileSaved => 'تم حفظ الملف';

  @override
  String get nameRequired => 'أدخل اسم الطفل.';

  @override
  String get ageInvalid => 'أدخل عمرًا من 1 إلى 17.';

  @override
  String get birthDate => 'تاريخ الميلاد';

  @override
  String get chooseBirthDate => 'اختر تاريخ الميلاد';

  @override
  String get changeBirthDate => 'تغيير التاريخ';

  @override
  String get birthDateHelper =>
      'يتحدّث العمر المستخدم في القصص تلقائيًا في كل عيد ميلاد.';

  @override
  String birthDateLegacyAge(int age) {
    return 'العمر المحفوظ: $age. اختر تاريخ ميلاد ليبقى صحيحًا.';
  }

  @override
  String get birthDateRequired => 'اختر تاريخ ميلاد الطفل.';

  @override
  String get photoTooLarge => 'اختر صورة أصغر من 2 ميغابايت.';

  @override
  String get photoReadFailed => 'تعذرت قراءة الصورة المحددة.';

  @override
  String get photoRequired => 'اختر صورة مرجعية.';

  @override
  String get createStoryTitle => 'قصة جديدة';

  @override
  String get whoIsTheHero => 'من هو البطل؟';

  @override
  String get add => 'إضافة';

  @override
  String heroAgeGender(int age, String gender) {
    return '$age · $gender';
  }

  @override
  String get whatHappens => 'ماذا يحدث؟';

  @override
  String get lessonHint => 'والدرس الذي تعلّمه';

  @override
  String get howLong => 'ما طولها؟';

  @override
  String get pages => 'صفحات';

  @override
  String get lookAndLanguage => 'الشكل واللغة';

  @override
  String get storyLanguageEnglish => 'English';

  @override
  String get storyLanguageArabic => 'العربية';

  @override
  String get storyLanguageSwedish => 'Svenska';

  @override
  String get storyLanguageSomali => 'Soomaali';

  @override
  String get writeTheStory => 'اكتب القصة';

  @override
  String get demoGeneratorLabel => 'تجريبي';

  @override
  String get localAiGeneratorLabel => 'ذكاء اصطناعي محلي';

  @override
  String get profileSelectionRequired => 'اختر الطفل الذي سيكون بطل القصة.';

  @override
  String get theme => 'موضوع المغامرة';

  @override
  String get themeHint => 'مثال: حديقة على القمر';

  @override
  String get moral => 'الدرس أو القيمة';

  @override
  String get pictureBookStyle => 'كتاب مصور';

  @override
  String get watercolorStyle => 'ألوان مائية';

  @override
  String get threeDStyle => 'ثلاثي الأبعاد ملون';

  @override
  String get demoModeNotice =>
      'ينشئ الوضع التجريبي قصة نموذجية مميزة بوضوح دون كمبيوتر ودون ذكاء اصطناعي. غيّر مولّد القصص إلى الذكاء الاصطناعي المحلي في الإعدادات للكتابة على كمبيوتر العائلة.';

  @override
  String get themeRequired => 'صف موضوع المغامرة.';

  @override
  String get moralRequired => 'أضف درسًا أو قيمة.';

  @override
  String get generatingTitle => 'نبني المغامرة';

  @override
  String get generatingBody => 'نكتب الصفحات ونجهز الكتاب المحلي الخاص…';

  @override
  String get storyCreated => 'القصة جاهزة';

  @override
  String get libraryTitle => 'الرف';

  @override
  String get librarySubtitle => 'محفوظة على هذا الجهاز فقط';

  @override
  String get libraryStoredWithPc => 'متزامنة مع حاسوب العائلة';

  @override
  String get searchStoryTitles => 'ابحث في العناوين';

  @override
  String get clearStorySearch => 'مسح البحث';

  @override
  String get emptyLibraryTitle => 'رف الكتب بانتظارك';

  @override
  String get emptyLibraryBody => 'أنشئ المغامرة الأولى وستظهر هنا.';

  @override
  String get openStory => 'فتح القصة';

  @override
  String get delete => 'حذف';

  @override
  String get deleteStoryTitle => 'حذف هذه القصة؟';

  @override
  String get deleteStoryBody => 'ستُحذف القصة نهائيًا من هذا الجهاز.';

  @override
  String get cancel => 'إلغاء';

  @override
  String get confirmDelete => 'حذف نهائي';

  @override
  String get readStory => 'قراءة القصة';

  @override
  String get previousPage => 'السابق';

  @override
  String get nextPage => 'التالي';

  @override
  String pageProgress(int current, int total) {
    return 'الصفحة $current من $total';
  }

  @override
  String get readToMe => 'اقرأ لي';

  @override
  String get playNarration => 'تشغيل السرد';

  @override
  String get pauseNarration => 'إيقاف السرد مؤقتًا';

  @override
  String get resumeNarration => 'متابعة السرد';

  @override
  String get stopNarration => 'إيقاف السرد';

  @override
  String get narrationUnavailable => 'لا يوجد صوت متوافق مثبت لهذه اللغة.';

  @override
  String get settingsTitle => 'الإعدادات والخصوصية';

  @override
  String get appLanguage => 'لغة التطبيق';

  @override
  String get privacyTitle => 'محلي وخاص';

  @override
  String get privacyBody =>
      'تبقى بيانات الملفات والصور والقصص في التخزين المحلي لهذا الجهاز ما لم تُصدّر نسخة احتياطية مشفرة يدوياً. لا تُستخدم تحليلات أو خدمة سحابية مدفوعة.';

  @override
  String get deleteAllData => 'حذف جميع البيانات المحلية';

  @override
  String get deleteAllTitle => 'حذف كل شيء؟';

  @override
  String get deleteAllBody =>
      'سيتم حذف جميع الملفات والصور والقصص نهائيًا من هذا الجهاز.';

  @override
  String get allDataDeleted => 'تم حذف جميع البيانات المحلية';

  @override
  String get aboutTitle => 'عن Iam - hero';

  @override
  String get aboutBody =>
      'كتاب قصص عائلي خاص. تُكتب القصص بنموذج Ollama محلي وتُرسم الصور بواسطة ComfyUI، وكلاهما على كمبيوترك.';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get swedish => 'السويدية';

  @override
  String get somali => 'الصومالية';

  @override
  String get somethingWentWrong => 'حدث خطأ ما.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get demoBadge => 'تجريبي';

  @override
  String yearsOld(int age) {
    return 'العمر $age سنوات';
  }

  @override
  String storyByHero(String name) {
    return 'مغامرة من بطولة $name';
  }

  @override
  String get myKingdom => 'مملكتي';

  @override
  String get kingdomTitle => 'مملكتي';

  @override
  String get kingdomSubtitle =>
      'اختر بطلاً، وعدّل ملفه، وامنح كل طفل لوناً خاصاً للتطبيق.';

  @override
  String get activeHero => 'البطل الحالي';

  @override
  String get chooseHero => 'اختر طفلاً';

  @override
  String get editHeroProfile => 'تعديل الاسم والملف';

  @override
  String get addAnotherHero => 'إضافة بطل آخر';

  @override
  String get themeColor => 'لون المملكة';

  @override
  String themeColorHint(String name) {
    return 'يُحفظ هذا اللون في ملف $name فقط.';
  }

  @override
  String get goldenTheme => 'ذهبي';

  @override
  String get roseTheme => 'وردي';

  @override
  String get purpleTheme => 'بنفسجي';

  @override
  String get cyanTheme => 'سماوي';

  @override
  String get greenTheme => 'أخضر';

  @override
  String get customColor => 'لون مخصص';

  @override
  String get customColorTitle => 'اختر لوناً مخصصاً';

  @override
  String get hue => 'اللون';

  @override
  String get intensity => 'قوة اللون';

  @override
  String get brightness => 'السطوع';

  @override
  String get applyColor => 'استخدام هذا اللون';

  @override
  String profileThemeSaved(String name) {
    return 'تم حفظ لون $name';
  }

  @override
  String get parentSecurityTitle => 'حماية الوالدين';

  @override
  String get parentSecurityBody =>
      'يحمي رمز PIN محلي اختياري الملفات ومملكتي والإعدادات والحذف. وهو لا يغني عن حماية الجهاز.';

  @override
  String get parentPin => 'رمز PIN للوالدين';

  @override
  String get parentPinConfigured => 'رمز PIN للوالدين مفعّل على هذا الجهاز.';

  @override
  String get parentPinNotConfigured =>
      'لم يتم تعيين رمز PIN. أدوات الوالدين مفتوحة حالياً.';

  @override
  String get setParentPin => 'تعيين رمز PIN';

  @override
  String get changeParentPin => 'تغيير الرمز';

  @override
  String get removeParentPin => 'إزالة الرمز';

  @override
  String get lockParentArea => 'القفل الآن';

  @override
  String get parentAreaLocked => 'قسم الوالدين مقفل';

  @override
  String get enterParentPin => 'أدخل رمز PIN المحلي للمتابعة.';

  @override
  String get incorrectParentPin => 'رمز PIN غير صحيح.';

  @override
  String get unlock => 'فتح القفل';

  @override
  String get newParentPin => 'رمز PIN جديد';

  @override
  String get confirmParentPin => 'تأكيد رمز PIN';

  @override
  String get parentPinRequirements => 'استخدم من 4 إلى 8 أرقام.';

  @override
  String get parentPinMismatch => 'رمزا PIN غير متطابقين.';

  @override
  String get saveParentPin => 'حفظ الرمز';

  @override
  String get parentPinSaved => 'تم حفظ رمز PIN للوالدين';

  @override
  String get parentPinRemoved => 'تمت إزالة رمز PIN للوالدين';

  @override
  String get removeParentPinTitle => 'هل تريد إزالة رمز PIN؟';

  @override
  String get removeParentPinBody =>
      'ستبقى أدوات الوالدين مفتوحة على هذا الجهاز حتى تعيين رمز جديد.';

  @override
  String parentPinLockedSeconds(int seconds) {
    return 'محاولات كثيرة. أعد المحاولة بعد $seconds ثانية.';
  }

  @override
  String parentPinLockedMinutes(int minutes) {
    return 'محاولات كثيرة. أعد المحاولة بعد $minutes دقيقة.';
  }

  @override
  String get changeParentPinTitle => 'تغيير رمز الوالدين';

  @override
  String get currentParentPin => 'الرمز الحالي';

  @override
  String get parentPinChanged => 'تم تغيير رمز الوالدين';

  @override
  String get forgotParentPinBody =>
      'لا توجد طريقة لاستعادة الرمز. إذا نُسي الرمز فالخيار الوحيد هو حذف كل بيانات التطبيق، ثم تعيد نسخة احتياطية مشفّرة محتوى العائلة لأن النسخة الاحتياطية لا تحتوي الرمز أبدًا.';

  @override
  String get encryptedBackupTitle => 'نسخة احتياطية مشفرة';

  @override
  String get encryptedBackupBody =>
      'احفظ ملفاً محمياً بكلمة مرور واستعده على جهاز آخر. لا تُحفظ كلمة مرور النسخة، فاحتفظ بها بأمان.';

  @override
  String get exportEncryptedBackup => 'تصدير نسخة';

  @override
  String get restoreEncryptedBackup => 'استعادة نسخة';

  @override
  String get createBackupPasswordTitle => 'إنشاء كلمة مرور للنسخة';

  @override
  String get enterBackupPasswordTitle => 'أدخل كلمة مرور النسخة';

  @override
  String get backupPassword => 'كلمة مرور النسخة';

  @override
  String get confirmBackupPassword => 'تأكيد كلمة مرور النسخة';

  @override
  String get backupPasswordRequirements =>
      'استخدم 8 محارف على الأقل. لا يمكن استعادة كلمة المرور هذه.';

  @override
  String get backupPasswordMismatch => 'كلمتا المرور غير متطابقتين.';

  @override
  String get continueAction => 'متابعة';

  @override
  String get backupReadyTitle => 'النسخة المشفرة جاهزة';

  @override
  String get backupReadyBody => 'اختر تنزيل النسخة لحفظ الملف المشفر.';

  @override
  String get downloadBackup => 'تنزيل النسخة';

  @override
  String get saveBackupDialogTitle => 'حفظ نسخة Iam - hero المشفرة';

  @override
  String get backupSaved => 'تم حفظ النسخة الاحتياطية المشفرة';

  @override
  String restoreFileName(String name) {
    return 'الملف المحدد: $name';
  }

  @override
  String get confirmRestoreTitle => 'استبدال بيانات العائلة المحلية؟';

  @override
  String confirmRestoreBody(int profiles, int stories) {
    return 'تحتوي النسخة على $profiles ملفات و$stories قصص. ستستبدل الاستعادة الملفات والقصص والبطل النشط ولغة التطبيق على هذا الجهاز.';
  }

  @override
  String get restoreNow => 'استعادة الآن';

  @override
  String get backupRestored => 'تمت استعادة النسخة المشفرة';

  @override
  String get backupWrongPassword => 'كلمة المرور خاطئة أو تم تعديل النسخة.';

  @override
  String get backupInvalid => 'هذا الملف ليس نسخة Iam - hero مدعومة.';

  @override
  String get backupTooLarge => 'النسخة كبيرة جداً ولا يمكن فتحها بأمان.';

  @override
  String get backupFileReadFailed => 'تعذرت قراءة النسخة المحددة.';

  @override
  String get backupFailed => 'تعذر إكمال إجراء النسخة الاحتياطية.';

  @override
  String get backupNewerVersion =>
      'أُنشئت هذه النسخة الاحتياطية بإصدار أحدث من التطبيق.';

  @override
  String get storyPreferencesTitle => 'تفضيلات القصة والأمان';

  @override
  String storyPreferencesBody(String name) {
    return 'اختر ما يلهم قصص $name وما يجب على الذكاء الاصطناعي المحلي تجنبه.';
  }

  @override
  String get editStoryPreferences => 'تعديل تفضيلات القصة';

  @override
  String get defaultStoryLanguage => 'لغة القصة الافتراضية';

  @override
  String defaultStoryLanguageValue(String language) {
    return 'اللغة الافتراضية: $language';
  }

  @override
  String get favoriteThings => 'الأشياء المفضلة';

  @override
  String get favoriteThingsHint => 'مثال: القطارات والقطط والنجوم';

  @override
  String favoriteThingsValue(String value) {
    return 'الأشياء المفضلة: $value';
  }

  @override
  String get recurringWorld => 'العالم المتكرر';

  @override
  String get recurringWorldHint => 'مثال: مملكة السحابة الذهبية';

  @override
  String recurringWorldValue(String value) {
    return 'العالم المتكرر: $value';
  }

  @override
  String get safetyControls => 'مواضيع يجب تجنبها';

  @override
  String get safetyControlsHint =>
      'ستُمرر هذه الاستثناءات إلى توليد القصص والصور المحلي مستقبلاً.';

  @override
  String safetyRulesValue(int count) {
    return 'استثناءات الأمان: $count';
  }

  @override
  String get avoidFrighteningContent => 'محتوى مخيف';

  @override
  String get avoidViolence => 'العنف أو الإصابة';

  @override
  String get avoidBullying => 'التنمر أو الاستبعاد';

  @override
  String get avoidGriefAndLoss => 'الحزن أو الفقد';

  @override
  String get savePreferences => 'حفظ التفضيلات';

  @override
  String storyPreferencesSaved(String name) {
    return 'تم حفظ تفضيلات قصص $name';
  }

  @override
  String savedPreferencesInUse(String name, int count) {
    return 'تُستخدم تفضيلات $name المحفوظة و$count من استثناءات الأمان.';
  }

  @override
  String get reviewStoriesTitle => 'مراجعة الوالدين للقصص';

  @override
  String get reviewStoriesBody =>
      'تبقى المسودات المولدة خارج مكتبة الطفل حتى تقرأها وتوافق عليها.';

  @override
  String get reviewStoryTitle => 'مراجعة هذه القصة';

  @override
  String get reviewStoryBody =>
      'راجع الطلب وكل صفحة قبل إظهار القصة في المكتبة.';

  @override
  String reviewDraftCount(int count) {
    return 'مراجعة المسودات ($count)';
  }

  @override
  String get approveStory => 'الموافقة على القصة';

  @override
  String get storyApproved => 'تمت الموافقة على القصة وإضافتها إلى المكتبة';

  @override
  String get deleteDraft => 'حذف المسودة';

  @override
  String get deleteDraftTitle => 'حذف هذه المسودة؟';

  @override
  String get deleteDraftBody => 'ستُحذف هذه المسودة المولدة نهائياً من الجهاز.';

  @override
  String reviewHero(String value) {
    return 'البطل: $value';
  }

  @override
  String reviewTheme(String value) {
    return 'الموضوع: $value';
  }

  @override
  String reviewMoral(String value) {
    return 'القيمة: $value';
  }

  @override
  String reviewPageNumber(int number) {
    return 'الصفحة $number';
  }

  @override
  String get noDrafts => 'لا توجد قصص بانتظار المراجعة.';

  @override
  String get moreStoryActions => 'إجراءات أخرى للقصة';

  @override
  String storyPageCount(int count) {
    return '$count صفحات';
  }

  @override
  String get addFavorite => 'إضافة إلى المفضلة';

  @override
  String get removeFavorite => 'إزالة من المفضلة';

  @override
  String get manageCollections => 'إدارة المجموعات';

  @override
  String collectionsHint(int max) {
    return 'أدخل حتى $max أسماء مجموعات، وافصل بينها بفواصل أو أسطر جديدة.';
  }

  @override
  String get collectionNames => 'أسماء المجموعات';

  @override
  String get collectionNamesHint => 'وقت النوم، مغامرات الفضاء';

  @override
  String get saveCollections => 'حفظ المجموعات';

  @override
  String tooManyCollections(int max) {
    return 'استخدم $max مجموعات كحد أقصى.';
  }

  @override
  String collectionNameTooLong(int max) {
    return 'يجب ألا يتجاوز اسم المجموعة $max محرفاً.';
  }

  @override
  String allStoriesCount(int count) {
    return 'الكل $count';
  }

  @override
  String get favoriteStories => 'المفضلة';

  @override
  String get noStoriesInFilter => 'لا توجد قصص تطابق هذا المرشح بعد.';

  @override
  String get noStoriesMatchSearch => 'لا يوجد عنوان في هذا الرف يطابق البحث.';

  @override
  String get generationCenterTitle => 'مركز التوليد المحلي';

  @override
  String get generationCenterBody =>
      'اعرف ما يعمل دون اتصال الآن وأعد بأمان محاولة الطلبات المحفوظة قبل التوليد.';

  @override
  String get openGenerationCenter => 'فتح مركز التوليد';

  @override
  String get generationQueueTitle => 'قائمة انتظار التوليد المحفوظة';

  @override
  String get generationQueueEmpty => 'لا توجد طلبات قصص منتظرة أو فاشلة.';

  @override
  String get demoGeneratorStatus => 'مولّد العرض دون اتصال';

  @override
  String get readyOffline => 'جاهز دون اتصال';

  @override
  String get ollamaStatus => 'نموذج القصص Ollama';

  @override
  String get comfyUiStatus => 'رسومات ComfyUI';

  @override
  String get notConnectedYet => 'غير متصل بعد';

  @override
  String get pcRequirementStatus =>
      'يعمل العرض التجريبي والكمبيوتر مطفأ. تحتاج قصص الذكاء الاصطناعي المحلي إلى تشغيل الكمبيوتر وجسره ونموذجه؛ وتبقى الكتب المحفوظة متاحة دائماً دون اتصال.';

  @override
  String get generationQueued => 'في الانتظار ومحفوظ';

  @override
  String get generationRunning => 'يتم التوليد الآن';

  @override
  String get generationFailed => 'فشلت المحاولة — يمكن إعادتها بأمان';

  @override
  String get retryGeneration => 'إعادة محاولة التوليد';

  @override
  String get cancelGenerationTitle => 'إزالة هذا الطلب؟';

  @override
  String get cancelGenerationBody =>
      'سيُزال الطلب المنتظر. لن تتأثر القصص المحفوظة.';

  @override
  String get removeFromQueue => 'إزالة من القائمة';

  @override
  String get exportPdf => 'حفظ PDF';

  @override
  String get exportPdfDialogTitle => 'حفظ القصة بصيغة PDF';

  @override
  String get exportingPdf => 'جارٍ إنشاء ملف PDF…';

  @override
  String get pdfSaved => 'تم حفظ ملف PDF';

  @override
  String get pdfSaveCancelled => 'تم إلغاء حفظ ملف PDF';

  @override
  String get pdfExportFailed => 'تعذر حفظ ملف PDF';

  @override
  String get exportPdfOptionsTitle => 'خيارات ملف PDF';

  @override
  String includePhotoOnCover(String name) {
    return 'أضف صورة $name على الغلاف';
  }

  @override
  String get exportPdfPhotoNotice =>
      'ملف PDF المحفوظ غير مشفّر ويخرج من التطبيق.';

  @override
  String pdfForHero(String name) {
    return 'إلى $name';
  }

  @override
  String pdfBelongsTo(String name) {
    return 'هذا الكتاب يخص $name';
  }

  @override
  String pdfMadeOn(String date) {
    return 'صُنع في $date';
  }

  @override
  String pdfPageBadge(int number, int total) {
    return 'صفحة $number من $total';
  }

  @override
  String get pdfMoralHeading => 'قلب هذه القصة';

  @override
  String get pdfTheEnd => 'النهاية';

  @override
  String get narrationSettings => 'إعدادات القراءة الصوتية';

  @override
  String get narrationSpeed => 'سرعة القراءة';

  @override
  String get slowSpeed => 'بطيئة';

  @override
  String get normalSpeed => 'عادية';

  @override
  String get fastSpeed => 'سريعة';

  @override
  String get narrationScope => 'القراءة بصوت عالٍ';

  @override
  String get currentPage => 'الصفحة الحالية';

  @override
  String get remainingStory => 'من هذه الصفحة حتى النهاية';

  @override
  String get applyNarrationSettings => 'تطبيق';

  @override
  String get sleepTimer => 'مؤقّت النوم';

  @override
  String get sleepTimerOff => 'متوقّف';

  @override
  String sleepTimerMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String sleepTimerRemaining(int minutes) {
    return 'سيتوقّف السرد بعد $minutes دقيقة تقريبًا.';
  }

  @override
  String get kingdomStyleTitle => 'طراز المملكة';

  @override
  String kingdomStyleBody(String name) {
    return 'اختر القلعة وإطار الصورة والخلفية والرمز لمملكة $name.';
  }

  @override
  String kingdomStyleSaved(String name) {
    return 'تم حفظ طراز المملكة لـ $name';
  }

  @override
  String get kingdomCastle => 'القلعة';

  @override
  String get castleClassicTowers => 'أبراج كلاسيكية';

  @override
  String get castleRoundDomes => 'قباب مستديرة';

  @override
  String get castleCrystalSpires => 'أبراج بلّورية';

  @override
  String get castleForestTreehouse => 'بيت الشجرة في الغابة';

  @override
  String get kingdomAvatarFrame => 'إطار الصورة';

  @override
  String get avatarFrameNone => 'دائرة بسيطة';

  @override
  String get avatarFrameStars => 'نجوم';

  @override
  String get avatarFrameHearts => 'قلوب';

  @override
  String get avatarFrameLaurel => 'إكليل غار';

  @override
  String get kingdomBackdrop => 'الخلفية';

  @override
  String get backdropNightSky => 'سماء الليل';

  @override
  String get backdropMeadow => 'مرج أخضر';

  @override
  String get backdropOcean => 'المحيط';

  @override
  String get backdropSunset => 'غروب الشمس';

  @override
  String get kingdomSymbol => 'الرمز المفضّل';

  @override
  String get symbolStar => 'نجمة';

  @override
  String get symbolRocket => 'صاروخ';

  @override
  String get symbolCrown => 'تاج';

  @override
  String get symbolButterfly => 'فراشة';

  @override
  String get symbolDragon => 'تنّين';

  @override
  String get symbolFlower => 'زهرة';

  @override
  String get symbolFootball => 'كرة قدم';

  @override
  String get symbolMusic => 'موسيقى';

  @override
  String get symbolBook => 'كتاب';

  @override
  String get symbolPaw => 'مخلب';

  @override
  String get symbolRainbow => 'قوس قزح';

  @override
  String get symbolSparkles => 'بريق';

  @override
  String get readingComfortTitle => 'راحة القراءة';

  @override
  String readingComfortBody(String name) {
    return 'اختر كيف تظهر صفحات القصة أثناء قراءة $name.';
  }

  @override
  String get readerTextSize => 'حجم النص';

  @override
  String get textSizeSmall => 'صغير';

  @override
  String get textSizeMedium => 'متوسط';

  @override
  String get textSizeLarge => 'كبير';

  @override
  String get textSizeExtraLarge => 'كبير جداً';

  @override
  String get easyReadingFont => 'خط سهل القراءة';

  @override
  String get easyReadingFontHint =>
      'يستخدم أشكال حروف مصممة لتمرين القراءة في القصص الإنجليزية والسويدية والصومالية. تحتفظ القصص العربية بحروفها المعتادة.';

  @override
  String readingComfortSaved(String name) {
    return 'تم حفظ راحة القراءة لـ $name';
  }

  @override
  String get bedtimeMode => 'وضع وقت النوم';

  @override
  String get turnOffBedtimeMode => 'إيقاف وضع وقت النوم';

  @override
  String bedtimeSleepTimerApplied(int minutes) {
    return 'ضبط وضع وقت النوم مؤقت نوم مدته $minutes دقيقة.';
  }

  @override
  String get readingBadgesTitle => 'أوسمة القراءة';

  @override
  String readingBadgesBody(String name) {
    return 'أوسمة يحصل عليها $name بإكمال القصص. بلا سلاسل ولا أهداف يومية.';
  }

  @override
  String storiesFinished(int count) {
    return 'القصص المكتملة: $count';
  }

  @override
  String get badgeFirstStory => 'أول قصة';

  @override
  String get badgeFiveStories => 'خمس قصص';

  @override
  String get badgeTenStories => 'عشر قصص';

  @override
  String get badgeTwentyFiveStories => 'خمس وعشرون قصة';

  @override
  String badgeEarned(String badge) {
    return 'وسام جديد: $badge';
  }

  @override
  String nextBadgeProgress(int count, String badge) {
    return 'بقي $count للوصول إلى $badge.';
  }

  @override
  String get allBadgesEarned => 'تم الحصول على كل الأوسمة. قراءة رائعة!';

  @override
  String get shareStoryFile => 'حفظ ملف القصة';

  @override
  String get storyFileNotice =>
      'ملف القصة مشفر بكلمة المرور هذه، وصورة الطفل لا تُضمَّن أبداً.';

  @override
  String get createStoryPasswordTitle => 'إنشاء كلمة مرور لملف القصة';

  @override
  String get enterStoryPasswordTitle => 'أدخل كلمة مرور ملف القصة';

  @override
  String get storyFilePassword => 'كلمة مرور ملف القصة';

  @override
  String get confirmStoryFilePassword => 'تأكيد كلمة مرور ملف القصة';

  @override
  String get storyFilePasswordMismatch => 'كلمتا مرور ملف القصة غير متطابقتين.';

  @override
  String get saveStoryFileDialogTitle => 'حفظ قصة Iam - hero المشفرة';

  @override
  String get storyFileSaved => 'تم حفظ ملف القصة المشفر';

  @override
  String get storyFileSaveCancelled => 'تم إلغاء حفظ ملف القصة';

  @override
  String get importStoryFile => 'استيراد ملف قصة';

  @override
  String get importStoryTitle => 'استيراد هذه القصة؟';

  @override
  String importStoryPages(int count) {
    return 'الصفحات: $count';
  }

  @override
  String importStoryHero(String name) {
    return 'البطل في الملف: $name';
  }

  @override
  String get importStoryChooseProfile => 'أضف القصة إلى';

  @override
  String get importStoryAction => 'استيراد القصة';

  @override
  String storyImported(String title) {
    return 'تم استيراد القصة: $title';
  }

  @override
  String get storyAlreadyOnDevice => 'هذه القصة موجودة على هذا الجهاز بالفعل.';

  @override
  String get importStoryNeedsProfile => 'أضف ملف بطل قبل استيراد قصة.';

  @override
  String get storyFileWrongPassword =>
      'كلمة المرور خاطئة أو تم تعديل ملف القصة.';

  @override
  String get storyFileInvalid => 'هذا الملف ليس ملف قصة Iam - hero مدعوماً.';

  @override
  String get storyFileTooLarge => 'ملف القصة كبير جداً ولا يمكن فتحه بأمان.';

  @override
  String get storyFileReadFailed => 'تعذرت قراءة ملف القصة المحدد.';

  @override
  String get storyFileFailed => 'تعذر إكمال إجراء ملف القصة.';

  @override
  String get storyFileNewerVersion =>
      'أُنشئ ملف القصة هذا بإصدار أحدث من التطبيق.';

  @override
  String get aiConnectionTitle => 'اتصال الذكاء الاصطناعي';

  @override
  String get aiConnectionBody =>
      'اختر ما إذا كانت القصص الجديدة تأتي من النموذج التجريبي دون اتصال أم من الذكاء الاصطناعي العامل على كمبيوتر العائلة.';

  @override
  String get aiConnectionParentNotice =>
      'هذه الإعدادات للوالدين فقط. لا يرى الأطفال عنوان الكمبيوتر ولا الاقتران أبداً.';

  @override
  String get storyGeneratorMode => 'مولّد القصص';

  @override
  String get demoGeneratorMode => 'تجريبي · نموذج دون اتصال';

  @override
  String get localAiGeneratorMode => 'ذكاء اصطناعي محلي على الكمبيوتر';

  @override
  String get storyGeneratorModeSaved => 'تم تحديث مولّد القصص';

  @override
  String get bridgeAddress => 'عنوان جسر الكمبيوتر';

  @override
  String get bridgeAddressHint => 'http://127.0.0.1:8765';

  @override
  String get bridgeAddressInvalid =>
      'أدخل عنواناً كاملاً، مثل http://192.168.1.20:8765.';

  @override
  String get saveBridgeAddress => 'حفظ العنوان';

  @override
  String get bridgeAddressSaved => 'تم حفظ عنوان جسر الكمبيوتر';

  @override
  String get testBridgeConnection => 'اختبار الاتصال';

  @override
  String bridgeReachable(String version) {
    return 'استجاب جسر الكمبيوتر. الإصدار $version.';
  }

  @override
  String get bridgeStatusReady => 'جاهز';

  @override
  String get bridgeStatusUnavailable => 'غير متاح';

  @override
  String get bridgeLibraryStatus => 'مكتبة القصص على الكمبيوتر';

  @override
  String get pairWithPc => 'الاقتران بالكمبيوتر';

  @override
  String get pairDeviceTitle => 'اقتران هذا الجهاز';

  @override
  String get pairDeviceBody =>
      'انظر إلى شاشة الكمبيوتر: تعرض رمزاً من ٦ أرقام لمدة دقيقتين. اكتب الرمز هنا مع اسم لهذا الجهاز.';

  @override
  String get pairingCode => 'الرمز المكوّن من ٦ أرقام على الكمبيوتر';

  @override
  String get pairingCodeInvalid => 'أدخل الأرقام الستة الظاهرة على الكمبيوتر.';

  @override
  String get pairedDeviceNameLabel => 'اسم هذا الجهاز';

  @override
  String get pairedDeviceNameHint => 'لوح العائلة';

  @override
  String pairedDeviceNameInvalid(int max) {
    return 'أدخل اسماً لا يتجاوز $max حرفاً.';
  }

  @override
  String get confirmPairing => 'اقتران الجهاز';

  @override
  String get devicePaired => 'تم اقتران الجهاز بالكمبيوتر';

  @override
  String devicePairedAs(String name) {
    return 'مقترن بالكمبيوتر باسم $name';
  }

  @override
  String get deviceNotPaired => 'هذا الجهاز غير مقترن بالكمبيوتر بعد.';

  @override
  String get forgetPairedDevice => 'نسيان هذا الجهاز';

  @override
  String get forgetPairedDeviceTitle => 'هل تريد نسيان هذا الاقتران؟';

  @override
  String get forgetPairedDeviceBody =>
      'سيتوقف هذا الجهاز عن استخدام الكمبيوتر حتى يُقترن من جديد. احذفه من الكمبيوتر أيضاً إن لم ترغب ببقائه في قائمته.';

  @override
  String get pairedDeviceForgotten => 'تمت إزالة الاقتران من هذا الجهاز';

  @override
  String get pairedDevicesTitle => 'الأجهزة المقترنة بالكمبيوتر';

  @override
  String get pairedDevicesBody =>
      'كل جهاز مذكور هنا يصل إلى الكمبيوتر. إن أزلت جهازاً فعليه الاقتران من جديد.';

  @override
  String get pairedDevicesEmpty => 'لا يعرض الكمبيوتر أي جهاز مقترن.';

  @override
  String pairedDeviceThisDevice(String name) {
    return '$name · هذا الجهاز';
  }

  @override
  String pairedDeviceSince(String date) {
    return 'اقترن في $date';
  }

  @override
  String pairedDeviceLastSeen(String date) {
    return 'آخر ظهور $date';
  }

  @override
  String get pairedDeviceNeverSeen => 'لم يُستخدم منذ الاقتران';

  @override
  String get removePairedDevice => 'إزالة';

  @override
  String removePairedDeviceTitle(String name) {
    return 'هل تزيل $name؟';
  }

  @override
  String get removePairedDeviceBody =>
      'سيفقد ذلك الجهاز الوصول إلى الكمبيوتر فوراً. يمكنه الاقتران من جديد برمز جديد.';

  @override
  String pairedDeviceRemoved(String name) {
    return 'لم يعد $name قادراً على الوصول إلى الكمبيوتر';
  }

  @override
  String get openAiConnectionSettings => 'فتح إعدادات اتصال الذكاء الاصطناعي';

  @override
  String get localAiModeNotice =>
      'يكتب القصص الذكاء الاصطناعي على كمبيوتر العائلة. يجب أن يكون الكمبيوتر وجسره ونموذجه قيد التشغيل.';

  @override
  String get localAiSubmitting => 'جارٍ إرسال الطلب إلى الكمبيوتر…';

  @override
  String get localAiQueued => 'في انتظار أن يبدأ الكمبيوتر.';

  @override
  String localAiQueuedPosition(int position) {
    return 'في انتظار الكمبيوتر · الترتيب $position في الطابور.';
  }

  @override
  String get localAiWriting => 'الكمبيوتر يكتب القصة…';

  @override
  String get localAiChecking => 'جارٍ فحص الصفحات المكتملة…';

  @override
  String get bridgeUnreachable =>
      'لم يستجب الكمبيوتر. تأكد من تشغيل الجسر ومن صحة العنوان.';

  @override
  String get bridgeBlockedByBrowser =>
      'لم يسمح المتصفح لهذه الصفحة بالاتصال بالكمبيوتر. على الكمبيوتر نفسه، أو على جهاز يعمل عليه Tailscale، افتح إعدادات الموقع في المتصفح لهذه الصفحة، واضبط \"الوصول إلى الشبكة المحلية\" على السماح، ثم أعد تحميل الصفحة. إن استمر الفشل، تأكد من تشغيل الجسر ومن صحة العنوان.';

  @override
  String get bridgeTimedOut => 'استغرق الكمبيوتر وقتاً طويلاً للرد.';

  @override
  String get bridgeNotPaired =>
      'اقرن هذا الجهاز بالكمبيوتر قبل إنشاء قصة عليه.';

  @override
  String get bridgeUnauthorized => 'رفض الكمبيوتر هذا الجهاز. أعد الاقتران.';

  @override
  String get bridgeRateLimited =>
      'طلبات اقتران كثيرة جداً. انتظر دقيقة ثم أعد المحاولة.';

  @override
  String get bridgePairingNotFound =>
      'لم يعد هذا الاقتران قيد الانتظار. ابدأ اقتراناً جديداً.';

  @override
  String get bridgePairingExpired =>
      'انتهت صلاحية الرمز. اطلب رمزاً جديداً من الكمبيوتر.';

  @override
  String get bridgeInvalidPairingCode =>
      'الرمز غير صحيح. خمس محاولات خاطئة تلغي الاقتران.';

  @override
  String get bridgeInvalidRequest => 'رفض الكمبيوتر طلب القصة هذا.';

  @override
  String get bridgeDeviceNotFound => 'لم يعد الكمبيوتر يعرف ذلك الجهاز.';

  @override
  String get bridgeCannotRemoveThisDevice =>
      'استخدم «نسيان هذا الجهاز» لإلغاء اقتران هذا الجهاز.';

  @override
  String get bridgeJobNotFound => 'لم يعد الكمبيوتر يعرف طلب القصة هذا.';

  @override
  String get bridgeGenerationFailed =>
      'تعذر على الكمبيوتر إكمال القصة. لم يُحفظ أي شيء.';

  @override
  String get bridgeGenerationCancelled =>
      'تم إلغاء إنشاء القصة. لم يُحفظ أي شيء.';

  @override
  String get bridgeInvalidResponse =>
      'رد الكمبيوتر بشيء لا يستطيع التطبيق قراءته.';

  @override
  String get bridgeProblem => 'أبلغ جسر الكمبيوتر عن مشكلة.';

  @override
  String get bridgeStoryNotFound => 'لم تبقَ هذه القصة على الكمبيوتر.';

  @override
  String get librarySyncTitle => 'مكتبة القصص دون اتصال';

  @override
  String get librarySyncBody =>
      'أنزِل قصص العائلة من الكمبيوتر إلى هذا الجهاز لتُقرأ حتى عندما يكون الكمبيوتر مغلقاً.';

  @override
  String get syncNow => 'مزامنة الآن';

  @override
  String get librarySyncRunning => 'جارٍ المزامنة مع الكمبيوتر…';

  @override
  String get librarySyncNever => 'لم يزامن هذا الجهاز مع الكمبيوتر بعد.';

  @override
  String librarySyncLastRun(String moment) {
    return 'آخر مزامنة: $moment';
  }

  @override
  String librarySyncResult(int added, int updated, int removed) {
    return '$added جديدة · $updated محدَّثة · $removed محذوفة';
  }

  @override
  String get librarySyncUpToDate => 'هذا الجهاز مطابق للكمبيوتر بالفعل.';

  @override
  String get librarySyncPendingProfilesTitle => 'في انتظار ملف بطل';

  @override
  String librarySyncPendingProfile(int count, String name) {
    return '$count قصص لـ $name تبقى على الكمبيوتر: لا يوجد ملف لهذا الطفل على هذا الجهاز.';
  }

  @override
  String get librarySyncPendingProfilesBody =>
      'ملف الطفل يخص الجهاز الذي أُنشئ عليه. استعِد نسخة ذلك الجهاز الاحتياطية هنا، أو أنشئ قصصاً لهذا الطفل من هذا الجهاز، وستُزامن قصصه أيضاً.';

  @override
  String get removedStoriesTitle => 'قصص أُزيلت من هذا الجهاز';

  @override
  String removedStoriesBody(int count) {
    return 'أُزيلت $count قصص من هذا الجهاز فقط. ما زالت على الكمبيوتر، ولن تنزلها المزامنة حتى تطلبها.';
  }

  @override
  String get redownloadRemovedStories => 'أنزلها من جديد';

  @override
  String get redownloadRemovedStoriesDone => 'ستعيد المزامنة القادمة تلك القصص';

  @override
  String get deleteBridgeStoryTitle => 'من أين تُحذف هذه القصة؟';

  @override
  String get deleteBridgeStoryBody =>
      'هذه القصة موجودة أيضاً في مكتبة كمبيوتر العائلة، لذلك هناك خياران مختلفان.';

  @override
  String get removeStoryFromDevice => 'إزالة من هذا الجهاز';

  @override
  String get removeStoryFromDeviceDetail =>
      'تحذف النسخة الموجودة هنا. تبقى القصة على الكمبيوتر، ولن ينزلها هذا الجهاز حتى تطلبها.';

  @override
  String get deleteStoryEverywhere => 'الحذف من كل مكان';

  @override
  String get deleteStoryEverywhereDetail =>
      'تحذف القصة من الكمبيوتر ومن كل أجهزة العائلة. لا يمكن التراجع، ويجب أن يكون الكمبيوتر متاحاً.';

  @override
  String get storyRemovedFromDevice => 'أُزيلت القصة من هذا الجهاز';

  @override
  String get storyDeletedEverywhere =>
      'حُذفت القصة من الكمبيوتر ومن كل الأجهزة';

  @override
  String get storyAlreadyDeletedEverywhere =>
      'كانت هذه القصة محذوفة للعائلة كلها من قبل';

  @override
  String get close => 'إغلاق';

  @override
  String get illustrateStory => 'رسم صور لهذه القصة';

  @override
  String get illustrateStoryTitle => 'هل تريد رسم صور لهذه القصة؟';

  @override
  String get illustrateStoryBody =>
      'يرسم كمبيوتر العائلة صورة لكل صفحة. يستغرق ذلك بضع دقائق للصفحة، لذلك اترك الكمبيوتر مشتغلاً حتى ينتهي. يمكنك التوقف في أي وقت، والصور الجاهزة تبقى محفوظة.';

  @override
  String get startIllustrating => 'ابدأ رسم الصور';

  @override
  String get stopIllustrating => 'إيقاف';

  @override
  String get illustrationsSendingPhoto =>
      'جارٍ إرسال صورة البطل إلى الكمبيوتر…';

  @override
  String get illustrationsSubmitting =>
      'جارٍ الطلب من الكمبيوتر أن يبدأ الرسم…';

  @override
  String get illustrationsDrawingAny => 'الكمبيوتر يرسم الصور…';

  @override
  String illustrationsDrawing(int done, int total) {
    return 'جارٍ رسم الصورة $done من $total…';
  }

  @override
  String get illustrationsDownloading =>
      'جارٍ إنزال الصور الجاهزة إلى هذا الجهاز…';

  @override
  String illustrationsReady(int count) {
    return '$count صور جاهزة.';
  }

  @override
  String illustrationsPartlyReady(int done, int total) {
    return '$done من $total صور جاهزة. لم يستطع الكمبيوتر رسم الباقي.';
  }

  @override
  String get illustrationsNoneDrawn => 'لم يستطع الكمبيوتر رسم أي صورة.';

  @override
  String get illustrationsAlreadyDone => 'كل صفحة لديها صورتها بالفعل.';

  @override
  String get illustrationsStopped =>
      'توقف الرسم. الصور التي اكتملت تبقى محفوظة.';

  @override
  String illustrationsNotFetched(int count) {
    return '$count صور لم يتمكن هذا الجهاز من إنزالها.';
  }

  @override
  String get referencePhotoSkipped =>
      'لم يتم استخدام صورة البطل، لذلك الوجوه في الصور ليست وجهه.';

  @override
  String librarySyncPictures(int count) {
    return '$count صور جديدة';
  }

  @override
  String get bridgeProfileNotFound => 'لا يعرف الكمبيوتر هذا الطفل بعد.';

  @override
  String get bridgePhotoTooLarge => 'هذه الصورة كبيرة جداً على الكمبيوتر.';

  @override
  String get bridgeUnsupportedImage =>
      'لا يقبل الكمبيوتر إلا صورة JPEG أو PNG.';

  @override
  String get bridgeIllustrationNotFound => 'لم تبقَ هذه الصورة على الكمبيوتر.';

  @override
  String get bridgeIllustrationNotReady => 'لم تُرسم هذه الصورة بعد.';

  @override
  String get heroSheetTitle => 'كيف يُرسم البطل';

  @override
  String get heroSheetIntro =>
      'يقرأ الكمبيوتر صورة هذا الطفل مرة واحدة ثم يرسم البطل نفسه في كل قصة. وأنت تحدّد ما يرتديه البطل وما يحمله دائماً.';

  @override
  String get heroSheetReadFromPhoto => 'مقروء من الصورة';

  @override
  String get heroSheetHair => 'الشعر';

  @override
  String get heroSheetSkinTone => 'لون البشرة';

  @override
  String get heroSheetEyeColor => 'العينان';

  @override
  String get heroSheetNotReadYet => 'لم يقرأ الكمبيوتر هذه الصورة بعد.';

  @override
  String get heroSheetOutfit => 'يرتدي دائماً';

  @override
  String get heroSheetProp => 'يحمل دائماً';

  @override
  String get heroSheetWardrobeHelper =>
      'عبارة قصيرة بالإنجليزية، لأن نموذج الرسم يقرأ الإنجليزية.';

  @override
  String get heroSheetReadAgain => 'اقرأ الصورة من جديد';

  @override
  String get heroSheetRereadDone => 'قرأ الكمبيوتر الصورة من جديد.';

  @override
  String get heroSheetRereadPending =>
      'الكمبيوتر مشغول، وسيقرأ الصورة من جديد بعد قليل.';

  @override
  String get heroSheetRereadFailed =>
      'لم يتمكن الكمبيوتر من قراءة الصورة من جديد.';

  @override
  String get heroSheetSaveFailed => 'لم يُحفظ ما يرتديه البطل على الكمبيوتر.';

  @override
  String get heroSheetUnavailable =>
      'لم يردّ الكمبيوتر، لذلك لا يظهر شكل البطل.';

  @override
  String get settingsSubtitle => 'كل ما يقرره أحد الوالدين لهذا الجهاز.';

  @override
  String get settingsFamilyTitle => 'العائلة';

  @override
  String get settingsFamilyBody => 'الأبطال على هذا الجهاز، ولغة التطبيق.';

  @override
  String get settingsReadingTitle => 'القراءة';

  @override
  String get settingsReadingBody =>
      'شكل صفحات القصة، وطريقة قراءتها بصوت عالٍ.';

  @override
  String get settingsPcTitle => 'الكمبيوتر';

  @override
  String get settingsPcBody =>
      'مكان كتابة القصص، والأجهزة التي يثق بها الكمبيوتر، والمكتبة دون اتصال.';

  @override
  String get settingsSafetyTitle => 'الأمان';

  @override
  String get settingsSafetyBody =>
      'رمز PIN للوالدين والمواضيع التي تتجنبها القصص.';

  @override
  String get settingsSafetyTopicsBody => 'تُختار لكل طفل في مملكتي.';

  @override
  String get settingsDataTitle => 'بياناتك';

  @override
  String get settingsDataBody =>
      'النسخ الاحتياطية، وما يبقى على هذا الجهاز، وحذفه كله.';

  @override
  String get settingsAboutSummary => 'ما هذا التطبيق ومن يكتب قصصه';

  @override
  String get settingsNoHeroes => 'لا توجد ملفات أبطال على هذا الجهاز بعد';

  @override
  String settingsReadingTextSizeValue(String size) {
    return 'حجم النص: $size';
  }

  @override
  String get settingsReadingMixed => 'مختلط';

  @override
  String get settingsReadingEasyOn => 'خط القراءة السهلة مفعّل';

  @override
  String get settingsReadingEasyOff => 'خط القراءة السهلة متوقف';

  @override
  String get settingsReadingEasySome => 'خط القراءة السهلة لبعض الأبطال';

  @override
  String get settingsPcDemo => 'قصص تجريبية';

  @override
  String get settingsPcNotPaired => 'الكمبيوتر · غير مقترن بعد';

  @override
  String get settingsPcPaired => 'مقترن بالكمبيوتر';

  @override
  String get settingsPcNeverSynced => 'لم تتم المزامنة بعد';

  @override
  String settingsPcSyncedAt(String moment) {
    return 'تمت المزامنة $moment';
  }

  @override
  String get settingsSafetyPinOn => 'رمز PIN للوالدين مفعّل';

  @override
  String get settingsSafetyPinOff => 'لا يوجد رمز PIN للوالدين';

  @override
  String settingsDataSummary(int count) {
    return 'القصص على هذا الجهاز: $count';
  }

  @override
  String get settingsNarrationTitle => 'القراءة بصوت عالٍ';

  @override
  String get settingsNarrationBody =>
      'تُختار سرعة القراءة ومقدارها ومؤقّت النوم داخل القارئ في كل مرة تُقرأ فيها قصة بصوت عالٍ. لا يُحفظ أي من ذلك على هذا الجهاز.';

  @override
  String get settingsDangerZone => 'لا يمكن التراجع';
}
