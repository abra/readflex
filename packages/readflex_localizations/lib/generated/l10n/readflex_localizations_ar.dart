// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class ReadflexLocalizationsAr extends ReadflexLocalizations {
  ReadflexLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get libraryRemovalPending => 'ستتم الإزالة بعد الحفظ';

  @override
  String librarySelectedCount(int count) {
    return 'المحدد: $count';
  }

  @override
  String get libraryCancelSelection => 'إلغاء التحديد';

  @override
  String get libraryDiscardChangesTitle => 'تجاهل التغييرات؟';

  @override
  String get commonDiscardChangesTitle => 'تجاهل التغييرات؟';

  @override
  String get commonDiscardChanges => 'تجاهل';

  @override
  String get commonKeepEditing => 'متابعة التحرير';

  @override
  String get libraryDiscardChangesBody => 'لم يتم حفظ تغييرات هذه المجموعة.';

  @override
  String get readerSelectionStart => 'بداية التحديد';

  @override
  String get readerSelectionEnd => 'نهاية التحديد';

  @override
  String get translationOriginal => 'النص الأصلي';

  @override
  String get dictionaryInContext => 'في هذا السياق';

  @override
  String get dictionaryWordMeaning => 'معنى الكلمة';

  @override
  String get translationAction => 'ترجمة';

  @override
  String get translationTitle => 'الترجمة';

  @override
  String get translationSourceLanguage => 'لغة المصدر';

  @override
  String get translationTargetLanguage => 'اللغة الهدف';

  @override
  String get translationAutoSource => 'تلقائي';

  @override
  String translationAutoDetectedSource(String language) {
    return 'تلقائي: $language';
  }

  @override
  String get translationOffline => 'دون اتصال';

  @override
  String get translationSentence => 'الجملة';

  @override
  String get translationGeneralMeaning => 'المعنى العام';

  @override
  String translationGeneralMeaningOf(String word) {
    return 'المعنى العام: $word';
  }

  @override
  String get translationInExpression => 'في التعبير';

  @override
  String translationBaseForm(String lemma) {
    return 'الصيغة الأساسية: $lemma';
  }

  @override
  String get translationPosNoun => 'اسم';

  @override
  String get translationPosVerb => 'فعل';

  @override
  String get translationPosAdjective => 'صفة';

  @override
  String get translationPosAdverb => 'ظرف';

  @override
  String get translationPosPronoun => 'ضمير';

  @override
  String get translationPosPreposition => 'حرف جر';

  @override
  String get translationPosConjunction => 'حرف عطف';

  @override
  String get translationPosInterjection => 'تعجب';

  @override
  String get translationPosDeterminer => 'محدد';

  @override
  String get translationPosNumeral => 'عدد';

  @override
  String get translationPosParticle => 'أداة';

  @override
  String get translationPosAuxiliary => 'فعل مساعد';

  @override
  String get translationInContext => 'في هذا السياق';

  @override
  String get translationWordMeaning => 'معنى الكلمة';

  @override
  String get readerBackToReading => 'العودة إلى القراءة';

  @override
  String get readerPreviousMatch => 'التطابق السابق';

  @override
  String get readerNextMatch => 'التطابق التالي';

  @override
  String get readerEndSearch => 'إنهاء البحث';

  @override
  String readerSearchMatches(int count) {
    return 'التطابقات: $count';
  }

  @override
  String readerSearchMatchPosition(int current, int total) {
    return '$current من $total';
  }

  @override
  String get translationDetails => 'المعنى والبدائل';

  @override
  String get translationAlternatives => 'البدائل';

  @override
  String get translationSourceRequiredTitle => 'اختر لغة المصدر';

  @override
  String get translationSourceRequiredBody =>
      'لا يمكن اكتشاف لغة المصدر تلقائيًا دون اتصال بالإنترنت.';

  @override
  String get translationSelectLanguage => 'اختيار اللغة';

  @override
  String get translationOfflineModelTitle =>
      'يلزم تنزيل نماذج الترجمة دون اتصال';

  @override
  String translationOfflineModelBody(String source, String target) {
    return 'نزّل نماذج اللغتين $source و$target.';
  }

  @override
  String get translationDownloadModels => 'تنزيل النماذج';

  @override
  String get translationDownloadingModels => 'جارٍ تنزيل النماذج';

  @override
  String get translationDownloadingModelsBody =>
      'ستتم الترجمة على هذا الجهاز بعد التنزيل.';

  @override
  String get translationFailureTitle => 'تعذّرت الترجمة';

  @override
  String get translationFailureBody =>
      'تحقّق من اتصال الشبكة أو حاول مرة أخرى لاحقًا.';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get commonCopyFailed => 'تعذر النسخ';

  @override
  String get appInitializationFailed => 'فشل التهيئة';

  @override
  String get appInitializationFailedBody =>
      'تعذّر تشغيل Readflex. حاول مرة أخرى.';

  @override
  String get appTechnicalDetails => 'التفاصيل التقنية';

  @override
  String get appRetry => 'إعادة المحاولة';

  @override
  String get appRetrying => 'جار إعادة المحاولة…';

  @override
  String get onboardingWelcomeTitle => 'مرحبًا بك في Readflex';

  @override
  String get onboardingWelcomeSubtitle =>
      'الكتب والقصص المصورة وملفات PDF ومقالات الويب في قارئ واحد.';

  @override
  String get onboardingFeatureBooksTitle => 'الكتب والقصص المصورة وPDF';

  @override
  String get onboardingFeatureBooksDescription =>
      'EPUB وFB2 وMOBI وAZW3 وPDF وCBZ';

  @override
  String get onboardingFeatureArticlesTitle => 'مقالات من رابط';

  @override
  String get onboardingFeatureArticlesDescription =>
      'نسخة نظيفة للقراءة دون اتصال';

  @override
  String get onboardingFeatureLookupTitle => 'الترجمة والتعريف';

  @override
  String onboardingFeatureLookupDescription(String translate, String define) {
    return 'اضغط مطولًا على كلمة، ثم اضغط «$translate» أو «$define»';
  }

  @override
  String get onboardingFeatureHighlightsTitle => 'التظليل والملاحظات';

  @override
  String get onboardingFeatureHighlightsDescription =>
      'خمسة ألوان، وملاحظة على أي تظليل';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonDelete => 'حذف';

  @override
  String get commonKeep => 'الاحتفاظ';

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
  String get librarySearchHint => 'البحث في المكتبة';

  @override
  String get libraryScopeBooks => 'كتب';

  @override
  String get libraryScopeArticles => 'مقالات';

  @override
  String get libraryScopeComics => 'قصص مصورة';

  @override
  String get libraryScopeNew => 'جديد';

  @override
  String get libraryDisplayOptions => 'خيارات العرض';

  @override
  String get libraryDisplayTitle => 'العرض';

  @override
  String get libraryDisplayView => 'طريقة العرض';

  @override
  String get libraryDisplayList => 'قائمة';

  @override
  String get libraryDisplayGrid => 'شبكة';

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
  String get libraryNoResultsSubtitle => 'جرب بحثًا مختلفًا';

  @override
  String get libraryEmptyCollectionTitle => 'هذه المجموعة فارغة';

  @override
  String get libraryShowWholeLibrary => 'عرض المكتبة كاملة';

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
      other: 'سيؤدي هذا إلى حذف عناصر المكتبة والتظليلات والإشارات المرجعية.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'المجموعات';

  @override
  String get librarySearchCollectionsHint => 'البحث في المجموعات';

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
  String get libraryEmptySourceCount => 'لا توجد عناصر بعد';

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
  String get importSaveArticle => 'حفظ مقالة';

  @override
  String get importBeforeUploadingTitle => 'قبل الرفع';

  @override
  String get importBookTermsBody =>
      'ارفع فقط الكتب والقصص المصورة والمستندات التي تملك حق استخدامها في Readflex.';

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
  String get importUploadingBook => 'جار إضافة الكتاب';

  @override
  String get importPreparingBook => 'جار تجهيز الكتاب';

  @override
  String get importCopyingBook => 'جار نسخ الملف';

  @override
  String get importFinishingBook => 'جار إنهاء الاستيراد';

  @override
  String get commonUndo => 'تراجع';

  @override
  String get readerExpandHighlight => 'قراءة المزيد';

  @override
  String get readerCollapseHighlight => 'عرض أقل';

  @override
  String get readerGoToPassage => 'الانتقال إلى المقطع';

  @override
  String get readerBookmarkRemoved => 'تم حذف الإشارة المرجعية';

  @override
  String get readerBookmarkUpdateFailed => 'تعذر تحديث الإشارة المرجعية';

  @override
  String get readerPages => 'الصفحات';

  @override
  String get readerThumbnailUnavailable => 'المعاينة غير متاحة';

  @override
  String get libraryNewCollection => 'مجموعة جديدة';

  @override
  String get libraryCreateAndAdd => 'إنشاء وإضافة';

  @override
  String get importFetchingArticle => 'جار جلب المقالة…';

  @override
  String get importSavingArticle => 'جار حفظ نسخة دون اتصال…';

  @override
  String get importComicAdded => 'تمت إضافة القصة المصورة!';

  @override
  String get importBookAdded => 'تمت إضافة الكتاب!';

  @override
  String get importArticleSaved => 'تم حفظ المقالة!';

  @override
  String get importTryAgain => 'حاول مرة أخرى';

  @override
  String get importChooseFile => 'اختيار ملف';

  @override
  String get importEditLink => 'تعديل الرابط';

  @override
  String get importClipboardUnavailable => 'تعذر لصق الرابط';

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
  String get readerFontSample => 'لحظة هادئة مع كتاب.\nصفحة تقود إلى أخرى.';

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
  String get readerResetTextSize => 'إعادة تعيين حجم النص';

  @override
  String get readerTextSize => 'حجم النص';

  @override
  String get readerDecreaseTextSize => 'تصغير النص';

  @override
  String get readerIncreaseTextSize => 'تكبير النص';

  @override
  String get readerThemeSnow => 'ثلج';

  @override
  String get readerThemePaper => 'ورق';

  @override
  String get readerThemeWarm => 'دافئ';

  @override
  String get readerThemeMist => 'ليل';

  @override
  String get readerThemeNight => 'غرافيت';

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

  @override
  String get commonCopy => 'نسخ';

  @override
  String get readerSelectionCopied => 'تم النسخ';

  @override
  String get dictionaryAction => 'تعريف';

  @override
  String get dictionaryTitle => 'التعريف';

  @override
  String get dictionaryNotFoundTitle => 'لم يتم العثور على تعريف';

  @override
  String get dictionaryNotFoundBody =>
      'لم يتم العثور على مدخل في القاموس لهذا التحديد.';

  @override
  String get dictionaryUnsupportedLanguageTitle => 'اللغة غير متاحة';

  @override
  String get dictionaryUnsupportedLanguageBody =>
      'قاموس Readflex لا يدعم هذه اللغة حتى الآن.';

  @override
  String get dictionaryFailureTitle => 'التعريف غير متاح';

  @override
  String get dictionaryFailureBody =>
      'تحقق من الاتصال أو حاول مرة أخرى لاحقًا.';

  @override
  String get wordSave => 'حفظ في المفردات';

  @override
  String get wordSaved => 'حُفظت للمراجعة';

  @override
  String get wordUnsave => 'إزالة من المفردات';

  @override
  String get wordSaveFailed => 'تعذّر الحفظ في المفردات';

  @override
  String get practiceTitle => 'التدريب';

  @override
  String practiceWordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count كلمة',
      few: '$count كلمات',
      two: 'كلمتان',
      one: 'كلمة واحدة',
    );
    return '$_temp0';
  }

  @override
  String practiceHighlightCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تظليلًا',
      few: '$count تظليلات',
      two: 'تظليلان',
      one: 'تظليل واحد',
    );
    return '$_temp0';
  }

  @override
  String practiceNewToday(int count) {
    return '$count جديدة اليوم';
  }

  @override
  String get practiceLoadFailed => 'تعذّر تحميل بطاقاتك';

  @override
  String practiceDueToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count بطاقات لليوم',
      one: 'بطاقة واحدة لليوم',
    );
    return '$_temp0';
  }

  @override
  String practiceDueCount(int count) {
    return '$count مستحقة';
  }

  @override
  String get practiceCaughtUp => 'لا شيء متبقٍّ';

  @override
  String get practiceCaughtUpBody => 'لا شيء مستحق. عُد غدًا.';

  @override
  String get practiceSettingsTitle => 'إعدادات التدريب';

  @override
  String get practiceSettingsNewCards => 'بطاقات جديدة في اليوم';

  @override
  String get practiceSettingsReview => 'المراجعة';

  @override
  String get practiceSettingsReviewVocabulary => 'المفردات فقط';

  @override
  String get practiceSettingsReviewWithHighlights => 'مع التظليلات';

  @override
  String get practiceSettingsMemory => 'هدف الذاكرة';

  @override
  String get practiceMemoryLighter => 'أخف';

  @override
  String get practiceMemoryBalanced => 'متوازن';

  @override
  String get practiceMemoryStronger => 'أمتن';

  @override
  String get practiceMemoryHint =>
      '«متوازن» يعيد البطاقة ما دمت تتذكر 9 من 10. «أخف» ينتظر أطول ومراجعات أقل؛ «أمتن» يعيدها أبكر.';

  @override
  String get practiceCaughtUpShort => 'تم';

  @override
  String get practiceNothingTitle => 'لا شيء للتدريب بعد';

  @override
  String get practiceNothingBody =>
      'احفظ كلمة من ترجمة أو ظلّل مقطعًا أثناء القراءة. ستعود هنا للمراجعة.';

  @override
  String get practiceOpenLibrary => 'فتح المكتبة';

  @override
  String get practiceStartReview => 'بدء المراجعة';

  @override
  String get practiceReviewAhead => 'مراجعة مبكرة';

  @override
  String get practiceTodayTitle => 'اليوم';

  @override
  String practiceStreak(int days) {
    return 'سلسلة $days أيام';
  }

  @override
  String practiceThisWeek(int count) {
    return '$count هذا الأسبوع';
  }

  @override
  String practiceTotalCards(int count) {
    return '$count إجمالاً';
  }

  @override
  String get practiceSectionCollections => 'المجموعات';

  @override
  String get practiceSectionBySource => 'حسب الكتاب';

  @override
  String get practiceWordsTitle => 'المفردات';

  @override
  String get practiceHighlightsTitle => 'التظليلات';

  @override
  String practiceCollectionCounts(int total, int due) {
    return '$total محفوظة · $due مستحقة';
  }

  @override
  String get practiceSearchWords => 'البحث في المفردات';

  @override
  String get practiceSearchHighlights => 'البحث في التظليلات';

  @override
  String get practiceFilterAll => 'الكل';

  @override
  String get practiceFilterLearning => 'قيد التعلّم';

  @override
  String get practiceFilterMastered => 'متقنة';

  @override
  String get practiceWordsEmptyTitle => 'لا مفردات بعد';

  @override
  String get practiceWordsEmptyBody =>
      'اضغط حفظ في ترجمة أو تعريف أثناء القراءة';

  @override
  String get practiceHighlightsEmptyTitle => 'لا تظليلات بعد';

  @override
  String get practiceHighlightsEmptyBody =>
      'حدد نصًا أثناء القراءة واختر تظليل';

  @override
  String get practiceNoMatches => 'لا نتائج';

  @override
  String get practiceDueNew => 'جديدة';

  @override
  String get practiceDueNow => 'مستحقة';

  @override
  String practiceDueIn(String interval) {
    return 'بعد $interval';
  }

  @override
  String practiceIntervalMinutes(int count) {
    return '$count د';
  }

  @override
  String practiceIntervalHours(int count) {
    return '$count س';
  }

  @override
  String practiceIntervalDays(int count) {
    return '$count ي';
  }

  @override
  String practiceIntervalWeeks(int count) {
    return '$count أ';
  }

  @override
  String practiceIntervalMonths(int count) {
    return '$count ش';
  }

  @override
  String practiceIntervalYears(int count) {
    return '$count سنة';
  }

  @override
  String get practiceOpenInBook => 'فتح في الكتاب';

  @override
  String get practiceRemoveFromReview => 'إزالة من المراجعة';

  @override
  String get practiceMoreActions => 'المزيد';

  @override
  String practiceCardPosition(int position, int total) {
    return '$position من $total';
  }

  @override
  String get practiceShowAnswer => 'عرض الإجابة';

  @override
  String get practiceRateAgain => 'مجددًا';

  @override
  String get practiceRateHard => 'صعب';

  @override
  String get practiceRateGood => 'جيد';

  @override
  String get practiceKeep => 'إبقاء';

  @override
  String get practiceShowLess => 'عرض أقل';

  @override
  String get practiceNoNote => 'لا ملاحظة';

  @override
  String get practiceSessionDone => 'اكتملت الجلسة';

  @override
  String practiceSessionSummary(int reviewed, int known, int again) {
    return '$reviewed مُراجَعة · $known معروفة · $again مجددًا';
  }

  @override
  String practiceReviewAgainCount(int count) {
    return 'مراجعة $count مجددًا';
  }

  @override
  String get readerHighlightFilterAll => 'الكل';

  @override
  String get readerBrightnessSystem => 'النظام';

  @override
  String readerPageOfTotal(int page, int total) {
    return '$page / $total';
  }

  @override
  String get readerAddComment => 'إضافة تعليق';

  @override
  String get readerAppearanceSample => 'أب';

  @override
  String get translationUnknownLanguage => 'لغة غير معروفة';

  @override
  String get translationSameLanguageTitle => 'لا شيء للترجمة';

  @override
  String translationSameLanguageBody(String language) {
    return 'النص بلغة الترجمة بالفعل: $language. اختر لغة أخرى لترجمته.';
  }

  @override
  String translationSameLanguageDefineBody(String language, String define) {
    return 'النص بلغة الترجمة بالفعل: $language. يعرض «$define» معناه هنا.';
  }

  @override
  String dictionaryDefinitionNumber(int number) {
    return '$number.';
  }

  @override
  String get importDiscardUrlBody => 'لن يتم حفظ العنوان الذي أدخلته.';

  @override
  String get readerSelectionTipTitle => 'اضغط مطولًا على كلمة';

  @override
  String readerSelectionTipBody(
    String highlight,
    String copy,
    String translate,
    String define,
  ) {
    return 'ثم اضغط «$highlight» أو «$copy» أو «$translate» أو «$define».';
  }

  @override
  String get readerSelectionTipDismiss => 'حسنًا';

  @override
  String get readerTapAreaHint => 'منطقة النقر';

  @override
  String get importOfflineHint => 'لا يوجد اتصال';

  @override
  String get importArticleOfflineSubtitle => 'يتطلب اتصالاً بالإنترنت';

  @override
  String get libraryContinueReading => 'متابعة القراءة';

  @override
  String readingTimeLeftMinutes(int count) {
    return 'متبقٍ $count د';
  }

  @override
  String readingTimeLeftHours(int hours, int minutes) {
    return 'متبقٍ $hours س $minutes د';
  }

  @override
  String get libraryUploadFile => 'رفع ملف';

  @override
  String get librarySaveArticleAction => 'حفظ مقال';

  @override
  String get importFileKinds => 'كتب وقصص مصورة وPDF';

  @override
  String get importFromDevice => 'ملف من الجهاز';

  @override
  String get importArticleFromLink => 'مقال من رابط';

  @override
  String get importArticleOffline => 'يُحفظ للقراءة دون اتصال';

  @override
  String get libraryChooseCollection => 'اختيار مجموعة';

  @override
  String get onboardingAddBook => 'إضافة كتابك الأول';

  @override
  String get onboardingNotNow => 'ليس الآن';

  @override
  String get readerLineSpacingCompact => 'مضغوط';

  @override
  String get readerLineSpacingNormal => 'عادي';

  @override
  String get readerLineSpacingRelaxed => 'واسع';

  @override
  String get readerMarginsNarrow => 'ضيقة';

  @override
  String get readerMarginsMedium => 'متوسطة';

  @override
  String get readerMarginsWide => 'واسعة';

  @override
  String get readerAlignNormal => 'عادي';

  @override
  String get readerAlignJustified => 'ضبط';

  @override
  String get readerPageTurnHorizontalShort => 'أفقي';

  @override
  String get readerPageTurnVerticalShort => 'عمودي';

  @override
  String get readerColumns => 'الأعمدة';

  @override
  String get readerColumnsAuto => 'تلقائي';

  @override
  String get readerColumnsOne => 'عمود';

  @override
  String get readerColumnsTwo => 'عمودان';

  @override
  String get readerChapterRead => 'مقروء';

  @override
  String get readerPdfMargins => 'الهوامش';

  @override
  String get readerPdfMarginsWhole => 'الصفحة كاملة';

  @override
  String get readerPdfMarginsTrimmed => 'مقصوصة';

  @override
  String get readerPdfPageColors => 'ألوان الصفحات';

  @override
  String get readerPdfPageColorsTheme => 'السمة';

  @override
  String get readerPdfPageColorsOriginal => 'الأصلية';

  @override
  String get readerExternalLinkTitle => 'فتح الرابط؟';

  @override
  String get readerExternalLinkOpen => 'فتح';

  @override
  String get readerExternalLinkCopy => 'نسخ الرابط';

  @override
  String get libraryDisplayAppearance => 'المظهر';

  @override
  String get libraryDisplayLanguage => 'اللغة';

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
  String get developerReaderEngineTitle => 'محرّك القارئ';

  @override
  String get developerReaderEngineHint =>
      'أي محرّك يفتح كل صيغة. يسري على الكتاب التالي الذي يُفتح أو يُستورد.';

  @override
  String get developerReaderEngineWebView => 'WebView';

  @override
  String get developerReaderEngineNative => 'أصلي';

  @override
  String get developerReaderEngineReset => 'استخدام إعدادات البناء';
}
