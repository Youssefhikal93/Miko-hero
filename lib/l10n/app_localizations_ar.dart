// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'ميكو هيرو';

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
  String get welcomeBody => 'أنشئ قصصًا خاصة ومصورة تكون فيها ابنتك هي البطلة.';

  @override
  String get createFirstStory => 'أنشئ قصتها الأولى';

  @override
  String get createAnotherStory => 'أنشئ قصة جديدة';

  @override
  String get recentStories => 'أحدث القصص';

  @override
  String get profileIncompleteTitle => 'أنشئ ملف البطلة';

  @override
  String get profileIncompleteBody =>
      'أضف اسمها وعمرها وصورة مرجعية قبل إنشاء القصة.';

  @override
  String get setUpProfile => 'إنشاء الملف';

  @override
  String get editProfile => 'تعديل ملف البطلة';

  @override
  String get profileTitle => 'ملف البطلة';

  @override
  String get profileIntro =>
      'تبقى هذه المعلومات على الجهاز ولا تُحفظ أبدًا في الشفرة المصدرية للتطبيق.';

  @override
  String get daughterName => 'اسم ابنتك';

  @override
  String get age => 'العمر';

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
  String get nameRequired => 'أدخل اسمها.';

  @override
  String get ageInvalid => 'أدخل عمرًا من 1 إلى 17.';

  @override
  String get photoTooLarge => 'اختر صورة أصغر من 2 ميغابايت.';

  @override
  String get photoReadFailed => 'تعذرت قراءة الصورة المحددة.';

  @override
  String get photoRequired => 'اختر صورة مرجعية.';

  @override
  String get createStoryTitle => 'إنشاء قصة';

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
  String get profileNeeded => 'أكمل ملف البطلة أولًا.';

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
  String get libraryTitle => 'مكتبة قصصها';

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
      'تبقى معلومات الملف والصور والقصص في التخزين المحلي للجهاز. لا نستخدم التحليلات أو أي خدمة سحابية مدفوعة.';

  @override
  String get deleteAllData => 'حذف جميع البيانات المحلية';

  @override
  String get deleteAllTitle => 'حذف كل شيء؟';

  @override
  String get deleteAllBody =>
      'سيتم حذف الملف والصورة وجميع القصص نهائيًا من هذا الجهاز.';

  @override
  String get allDataDeleted => 'تم حذف جميع البيانات المحلية';

  @override
  String get aboutTitle => 'عن ميكو هيرو';

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
}
