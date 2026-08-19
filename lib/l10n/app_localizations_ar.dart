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
  String get welcomeTitle => 'مغامرة جديدة تبدأ هنا';

  @override
  String get welcomeBody => 'أنشئ قصصًا خاصة ومصورة يصبح فيها كل طفل هو البطل.';

  @override
  String get createFirstStory => 'أنشئ القصة الأولى';

  @override
  String get createAnotherStory => 'أنشئ قصة جديدة';

  @override
  String get recentStories => 'أحدث القصص';

  @override
  String get profileIncompleteTitle => 'أضف ملف بطل';

  @override
  String get profileIncompleteBody =>
      'أضف اسم الطفل وعمره واختر فتاة أو فتى وأضف صورة مرجعية قبل إنشاء القصة.';

  @override
  String get setUpProfile => 'إضافة ملف';

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
  String get createStoryTitle => 'إنشاء قصة';

  @override
  String get chooseHeroProfile => 'اختر ملف البطل';

  @override
  String get selectHeroProfile => 'اختر طفلًا';

  @override
  String get profileSelectionRequired => 'اختر الطفل الذي سيكون بطل القصة.';

  @override
  String get storyLanguage => 'لغة القصة';

  @override
  String get theme => 'موضوع المغامرة';

  @override
  String get themeHint => 'مثال: حديقة على القمر';

  @override
  String get moral => 'الدرس أو القيمة';

  @override
  String get moralHint => 'مثال: اللطف والشجاعة';

  @override
  String get storyLength => 'طول القصة';

  @override
  String get illustrationStyle => 'أسلوب الرسوم';

  @override
  String get shortLength => 'قصيرة · 6 صفحات';

  @override
  String get mediumLength => 'متوسطة · 8 صفحات';

  @override
  String get longLength => 'طويلة · 10 صفحات';

  @override
  String get pictureBookStyle => 'كتاب مصور ناعم';

  @override
  String get watercolorStyle => 'ألوان مائية';

  @override
  String get threeDStyle => 'ثلاثي الأبعاد ملون';

  @override
  String get generateStory => 'إنشاء قصة تجريبية';

  @override
  String get demoModeNotice =>
      'لم يتم توصيل الذكاء الاصطناعي المحلي بعد. ينشئ الوضع التجريبي قصة نموذجية مميزة بوضوح لاختبار التطبيق كاملًا مجانًا.';

  @override
  String get profileNeeded => 'أضف ملف بطل واحدًا على الأقل أولًا.';

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
  String get libraryTitle => 'مكتبة قصص العائلة';

  @override
  String get librarySubtitle => 'تُحفظ القصص المكتملة على هذا الجهاز فقط.';

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
      'كتاب قصص عائلي خاص. ستتم إضافة الاتصال المحلي مع Ollama وComfyUI في مرحلة لاحقة.';

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
  String get filterStories => 'تصفية هذا الرف';

  @override
  String get allStories => 'كل القصص';

  @override
  String get favoriteStories => 'المفضلة';

  @override
  String get noStoriesInFilter => 'لا توجد قصص تطابق هذا المرشح بعد.';

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
      'يعمل العرض والجهاز مطفأ. بعد ربط الذكاء الاصطناعي المحلي لاحقاً، يجب تشغيل الكمبيوتر والنماذج لإنشاء قصص ذكاء اصطناعي جديدة؛ وتبقى الكتب المحفوظة متاحة دون اتصال.';

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
}
