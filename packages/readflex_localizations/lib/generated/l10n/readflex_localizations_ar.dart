// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class ReadflexLocalizationsAr extends ReadflexLocalizations {
  ReadflexLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appSkip => 'تخطي';

  @override
  String get appNext => 'التالي';

  @override
  String get appGetStarted => 'ابدأ';

  @override
  String get appInitializationFailed => 'فشل التهيئة';

  @override
  String get appRetry => 'إعادة المحاولة';

  @override
  String get appRetrying => 'جار إعادة المحاولة...';

  @override
  String get onboardingReadAnythingTitle => 'اقرأ أي شيء';

  @override
  String get onboardingReadAnythingDescription =>
      'استورد الكتب واقرأ براحة باستخدام قارئ قابل للتخصيص.';

  @override
  String get onboardingHighlightSaveTitle => 'ظلّل واحفظ';

  @override
  String get onboardingHighlightSaveDescription =>
      'حدد النص لإنشاء تظليلات. أضف ملاحظات لفهم أعمق.';

  @override
  String get onboardingOrganizeLibraryTitle => 'نظّم مكتبتك';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'احتفظ بالكتب والمقالات في مكان واحد وعد إلى تقدم القراءة بسهولة.';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonDone => 'تم';

  @override
  String get commonCreate => 'إنشاء';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonClearSearch => 'مسح البحث';

  @override
  String get libraryTitle => 'المكتبة';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصر',
      many: '$count عنصرًا',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'غير متصل';

  @override
  String get librarySearchHint => 'البحث في المكتبة...';

  @override
  String get libraryFilterAll => 'الكل';

  @override
  String get libraryFilterBooks => 'كتب';

  @override
  String get libraryFilterArticles => 'مقالات';

  @override
  String get libraryFilterComics => 'قصص مصورة';

  @override
  String get libraryFilterNew => 'جديد';

  @override
  String get libraryDisplayOptions => 'خيارات العرض';

  @override
  String get libraryDisplayTitle => 'العرض';

  @override
  String get libraryDisplayView => 'طريقة العرض';

  @override
  String get libraryDisplayAppearance => 'المظهر';

  @override
  String get libraryDisplayLanguage => 'اللغة';

  @override
  String get libraryDisplayList => 'قائمة';

  @override
  String get libraryDisplayGrid => 'شبكة';

  @override
  String get libraryThemeSystem => 'النظام';

  @override
  String get libraryThemeSystemDescription => 'اتباع إعداد الجهاز';

  @override
  String get libraryThemeLight => 'فاتح';

  @override
  String get libraryThemeLightDescription => 'استخدام المظهر الفاتح';

  @override
  String get libraryThemeDark => 'داكن';

  @override
  String get libraryThemeDarkDescription => 'استخدام المظهر الداكن';

  @override
  String get libraryFailedToLoad => 'تعذر تحميل المكتبة';

  @override
  String get libraryLoadCollectionsFailed => 'تعذر تحميل المجموعات';

  @override
  String get libraryUpdateCollectionFailed => 'تعذر تحديث المجموعة';

  @override
  String get libraryUpdateFavouritesFailed => 'تعذر تحديث المفضلة';

  @override
  String get libraryCollectionNameRequired => 'اسم المجموعة مطلوب';

  @override
  String get libraryCreateCollectionFailed => 'تعذر إنشاء المجموعة';

  @override
  String get librarySaveCollectionFailed => 'تعذر حفظ المجموعة';

  @override
  String get libraryDeleteCollectionFailed => 'تعذر حذف المجموعة';

  @override
  String get libraryAddedToCollection => 'تمت الإضافة إلى المجموعة';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تمت إضافة $count عنصر إلى المجموعة',
      many: 'تمت إضافة $count عنصرًا إلى المجموعة',
      few: 'تمت إضافة $count عناصر إلى المجموعة',
      two: 'تمت إضافة عنصرين إلى المجموعة',
      one: 'تمت إضافة عنصر واحد إلى المجموعة',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'تم حذف المجموعة';

  @override
  String get libraryDeletedSuffix => ' تم حذفه';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count عنصر',
      many: 'تم حذف $count عنصرًا',
      few: 'تم حذف $count عناصر',
      two: 'تم حذف عنصرين',
      one: 'تم حذف العنصر',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تعذر حذف العناصر',
      one: 'تعذر حذف العنصر',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'إضافة إلى مجموعة';

  @override
  String get libraryEmptyTitle => 'مكتبتك فارغة';

  @override
  String get libraryEmptySubtitle => 'أضف أول كتاب أو مقالة للبدء';

  @override
  String get libraryNoResultsTitle => 'لم يتم العثور على نتائج';

  @override
  String get libraryNoResultsSubtitle => 'جرب بحثًا أو مرشحًا مختلفًا';

  @override
  String get libraryAddToCollectionTitle => 'إضافة إلى مجموعة';

  @override
  String get libraryFavourites => 'المفضلة';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'أنشئ مجموعة لـ $count عناصر محددة.',
      one: 'أنشئ مجموعة لعنصر واحد محدد.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'اسم المجموعة الجديدة';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count عنصر؟',
      many: 'حذف $count عنصرًا؟',
      few: 'حذف $count عناصر؟',
      two: 'حذف عنصرين؟',
      one: 'حذف هذا العنصر؟',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'سيؤدي هذا إلى إزالة عناصر المكتبة وتظليلاتك. سيتم الاحتفاظ ببيانات التعلم المؤرشفة.',
      one:
          'سيؤدي هذا إلى إزالة عنصر المكتبة وتظليلاتك. سيتم الاحتفاظ ببيانات التعلم المؤرشفة.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'المجموعات';

  @override
  String get librarySearchCollectionsHint => 'البحث في المجموعات...';

  @override
  String get libraryNoCollectionsYet => 'لا توجد مجموعات بعد';

  @override
  String get libraryNoMatchingCollections => 'لا توجد مجموعات مطابقة';

  @override
  String get libraryManualCollections => 'مجموعات يدوية';

  @override
  String get librarySites => 'المواقع';

  @override
  String get libraryAuthors => 'المؤلفون';

  @override
  String libraryManageCollection(String name) {
    return 'إدارة $name';
  }

  @override
  String get libraryOpenCollectionActions => 'فتح إجراءات المجموعة';

  @override
  String get libraryManageCollectionTitle => 'إدارة المجموعة';

  @override
  String get libraryDeleteCollectionTitle => 'حذف المجموعة؟';

  @override
  String get libraryDeleteCollectionButton => 'حذف المجموعة';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كتاب',
      many: '$count كتابًا',
      few: '$count كتب',
      two: 'كتابان',
      one: 'كتاب واحد',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقالة',
      many: '$count مقالة',
      few: '$count مقالات',
      two: 'مقالتان',
      one: 'مقالة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 كتب/مقالات';

  @override
  String get libraryNoItemsInCollection => 'لا توجد عناصر في هذه المجموعة';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'سيؤدي هذا إلى حذف \"$name\" فقط. ستبقى الكتب والمقالات في مكتبتك.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return 'إزالة $title من المجموعة';
  }

  @override
  String get librarySourceArticle => 'مقالة';

  @override
  String get librarySourceBook => 'كتاب';

  @override
  String get librarySourceComic => 'قصة مصورة';

  @override
  String get librarySourceNew => 'جديد';

  @override
  String get librarySourceDone => 'تم';

  @override
  String get librarySourceFinished => 'مكتمل';

  @override
  String get librarySourceUntitled => 'مصدر بلا عنوان';

  @override
  String get librarySourceOpenReader => 'فتح القارئ';

  @override
  String get librarySourceSelect => 'تحديد المصدر';

  @override
  String get librarySourceDeselect => 'إلغاء تحديد المصدر';

  @override
  String librarySourcePercentRead(int percent) {
    return 'تمت قراءة $percent بالمئة';
  }

  @override
  String get importAddToLibraryTitle => 'إضافة إلى المكتبة';

  @override
  String get importUploadBook => 'رفع كتاب';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'حفظ مقالة';

  @override
  String get importSaveArticleDescription => 'الصق رابط ويب للقراءة دون اتصال';

  @override
  String get importBeforeUploadingTitle => 'قبل الرفع';

  @override
  String get importBookTermsBody =>
      'ارفع فقط الكتب والقصص المصورة والمستندات التي تملك حق استخدامها في ReadFlex.';

  @override
  String get importBookTermsConfirm => 'أؤكد أن لدي الحق في رفع هذا الملف.';

  @override
  String get importLegalPrefix => 'بالمتابعة، فإنك تقبل ';

  @override
  String get importLegalAnd => ' و ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'الشروط';

  @override
  String get importPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'لصق الرابط';

  @override
  String get importArticleHintClean => 'ينشئ مقالة نظيفة للقراءة دون اتصال.';

  @override
  String get importArticleHintSource => 'يحافظ على رابط المصدر الأصلي.';

  @override
  String get importArticleHintLibrary => 'يضيفها إلى مكتبتك.';

  @override
  String get importUploadingBook => 'جار رفع الكتاب...';

  @override
  String get importFetchingArticle => 'جار جلب المقالة...';

  @override
  String get importSavingArticle => 'جار حفظ نسخة دون اتصال...';

  @override
  String get importComicAdded => 'تمت إضافة القصة المصورة!';

  @override
  String get importBookAdded => 'تمت إضافة الكتاب!';

  @override
  String get importArticleSaved => 'تم حفظ المقالة!';

  @override
  String get importTryAgain => 'حاول مرة أخرى';

  @override
  String get importArticleUrlRequired => 'أدخل رابط المقالة';

  @override
  String get importInvalidArticleUrl => 'أدخل رابط مقالة صالحًا';

  @override
  String get importBookImportFailed => 'تعذر استيراد الكتاب';

  @override
  String get importArticleSaveFailed => 'تعذر حفظ المقالة';

  @override
  String get highlightAction => 'تظليل';

  @override
  String get highlightTitle => 'تظليل';

  @override
  String get highlightNoteHint => 'إضافة ملاحظة (اختياري)';

  @override
  String get highlightFailedToSave => 'تعذر حفظ التظليل';

  @override
  String get highlightColorYellow => 'أصفر';

  @override
  String get highlightColorGreen => 'أخضر';

  @override
  String get highlightColorBlue => 'أزرق';

  @override
  String get highlightColorPink => 'وردي';

  @override
  String get highlightColorPurple => 'بنفسجي';

  @override
  String highlightColorSemantics(String color) {
    return 'لون التظليل $color';
  }

  @override
  String get highlightSelectColor => 'اختيار لون التظليل';

  @override
  String get readerFailedToLoadContent => 'تعذر تحميل المحتوى';

  @override
  String get readerGoBack => 'رجوع';

  @override
  String get readerBookSearchUnavailable => 'البحث في الكتاب غير متاح';

  @override
  String get readerNotReady => 'القارئ غير جاهز';

  @override
  String get readerHighlightSaved => 'تم حفظ التظليل';

  @override
  String get readerHighlightRemoved => 'تمت إزالة التظليل';

  @override
  String get readerHighlightSaveFailed => 'تعذر حفظ التظليل';

  @override
  String get readerCommentUpdated => 'تم تحديث التعليق';

  @override
  String get readerContents => 'المحتويات';

  @override
  String get readerChapters => 'الفصول';

  @override
  String get readerBookmarks => 'الإشارات المرجعية';

  @override
  String get readerHighlights => 'التظليلات';

  @override
  String get readerSearchChapters => 'البحث في الفصول';

  @override
  String get readerSearchBookmarks => 'البحث في الإشارات';

  @override
  String get readerSearchHighlights => 'البحث في التظليلات';

  @override
  String get readerNoBookmarksYet => 'لا توجد إشارات مرجعية بعد';

  @override
  String get readerNoMatchingBookmarks => 'لا توجد إشارات مطابقة';

  @override
  String get readerBookmarkedPage => 'صفحة عليها إشارة';

  @override
  String get readerDeleteBookmark => 'حذف الإشارة المرجعية';

  @override
  String get readerNoHighlightsYet => 'لا توجد تظليلات بعد';

  @override
  String get readerNoMatchingHighlights => 'لا توجد تظليلات مطابقة';

  @override
  String get readerHighlightedText => 'نص مظلل';

  @override
  String get readerLocationUnavailable => 'الموقع غير متاح';

  @override
  String get readerSearchInBook => 'البحث في الكتاب';

  @override
  String get readerNoResultsFound => 'لم يتم العثور على نتائج';

  @override
  String get readerRecentSearches => 'عمليات البحث الأخيرة';

  @override
  String get readerRemoveFromHistory => 'إزالة من السجل';

  @override
  String get readerSearchResult => 'نتيجة البحث';

  @override
  String get readerNoMatchingChapters => 'لا توجد فصول مطابقة';

  @override
  String get readerNoChaptersFound => 'لم يتم العثور على فصول';

  @override
  String get readerSearchPrompt => 'اكتب حرفين على الأقل للبحث';

  @override
  String get readerSearchAction => 'بحث';

  @override
  String get readerSearchFailed => 'فشل البحث';

  @override
  String get readerUntitledChapter => 'فصل بلا عنوان';

  @override
  String readerPageNumber(int page) {
    return 'الصفحة $page';
  }

  @override
  String get readerAppearanceTitle => 'المظهر';

  @override
  String get readerReset => 'إعادة تعيين';

  @override
  String get readerTheme => 'السمة';

  @override
  String get readerFont => 'الخط';

  @override
  String get readerFontSize => 'حجم النص';

  @override
  String get readerLineSpacing => 'تباعد الأسطر';

  @override
  String get readerTextAlignment => 'محاذاة النص';

  @override
  String get readerPageMargins => 'هوامش الصفحة';

  @override
  String get readerPageTurn => 'تقليب الصفحات';

  @override
  String get readerAlignStart => 'محاذاة البداية';

  @override
  String get readerJustifyText => 'ضبط النص';

  @override
  String get readerAlignEnd => 'محاذاة النهاية';

  @override
  String get readerHorizontalPageTurn => 'تقليب أفقي';

  @override
  String get readerVerticalPageTurn => 'تقليب عمودي';

  @override
  String get readerResetTextSize => 'إعادة تعيين حجم النص';

  @override
  String get readerTextSize => 'حجم النص';

  @override
  String get readerDecreaseTextSize => 'تصغير النص';

  @override
  String get readerIncreaseTextSize => 'تكبير النص';

  @override
  String get readerResetLineSpacing => 'إعادة تعيين تباعد الأسطر';

  @override
  String get readerDecreaseLineSpacing => 'تقليل تباعد الأسطر';

  @override
  String get readerIncreaseLineSpacing => 'زيادة تباعد الأسطر';

  @override
  String get readerResetPageMargins => 'إعادة تعيين الهوامش';

  @override
  String get readerDecreasePageMargins => 'تقليل الهوامش';

  @override
  String get readerIncreasePageMargins => 'زيادة الهوامش';

  @override
  String get readerThemeSnow => 'ثلج';

  @override
  String get readerThemePaper => 'ورق';

  @override
  String get readerThemeWarm => 'دافئ';

  @override
  String get readerThemeMist => 'غرافيت';

  @override
  String get readerThemeNight => 'ليل';

  @override
  String get readerIncreaseBrightness => 'زيادة السطوع';

  @override
  String get readerDecreaseBrightness => 'تقليل السطوع';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'استخدام سطوع النظام: $label';
  }

  @override
  String get readerUseSystemBrightness => 'استخدام سطوع النظام';

  @override
  String get readerPageBookmarked => 'تم وضع إشارة على الصفحة';

  @override
  String get readerOpenOriginalArticle => 'فتح المقالة الأصلية';

  @override
  String get readerBack => 'رجوع';

  @override
  String get readerFontAction => 'الخط';

  @override
  String get readerPageTurnVertical => 'تقليب الصفحات: عمودي';

  @override
  String get readerPageTurnHorizontal => 'تقليب الصفحات: أفقي';

  @override
  String get readerRemoveBookmark => 'إزالة الإشارة المرجعية';

  @override
  String get readerBookmark => 'إشارة مرجعية';

  @override
  String get readerEditComment => 'تعديل التعليق';

  @override
  String get readerRemoveHighlight => 'إزالة التظليل';

  @override
  String get readerHighlightNoteTitle => 'ملاحظة التظليل';

  @override
  String get readerEditNoteTitle => 'تعديل الملاحظة';

  @override
  String get readerCommentHint => 'إضافة تعليق (اختياري)';

  @override
  String get readerSkip => 'تخطي';
}
