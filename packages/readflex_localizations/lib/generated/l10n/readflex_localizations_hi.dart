// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class ReadflexLocalizationsHi extends ReadflexLocalizations {
  ReadflexLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appSkip => 'छोड़ें';

  @override
  String get appNext => 'आगे';

  @override
  String get appGetStarted => 'शुरू करें';

  @override
  String get appInitializationFailed => 'आरंभ करने में विफल';

  @override
  String get appRetry => 'फिर कोशिश करें';

  @override
  String get appRetrying => 'फिर कोशिश हो रही है...';

  @override
  String get onboardingReadAnythingTitle => 'कुछ भी पढ़ें';

  @override
  String get onboardingReadAnythingDescription =>
      'किताबें आयात करें और अनुकूलन योग्य रीडर में आराम से पढ़ें।';

  @override
  String get onboardingHighlightSaveTitle => 'हाइलाइट करें और सहेजें';

  @override
  String get onboardingHighlightSaveDescription =>
      'हाइलाइट बनाने के लिए टेक्स्ट चुनें। बेहतर समझ के लिए नोट जोड़ें।';

  @override
  String get onboardingOrganizeLibraryTitle => 'अपनी लाइब्रेरी व्यवस्थित करें';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'किताबें और लेख एक जगह रखें और अपनी पढ़ने की प्रगति पर वापस आएं।';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get commonDelete => 'हटाएं';

  @override
  String get commonRetry => 'फिर कोशिश करें';

  @override
  String get commonClose => 'बंद करें';

  @override
  String get commonBack => 'वापस';

  @override
  String get commonDone => 'हो गया';

  @override
  String get commonCreate => 'बनाएं';

  @override
  String get commonContinue => 'जारी रखें';

  @override
  String get commonSearch => 'खोजें';

  @override
  String get commonClearSearch => 'खोज साफ करें';

  @override
  String get libraryTitle => 'लाइब्रेरी';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम',
      one: '1 आइटम',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'ऑफलाइन';

  @override
  String get librarySearchHint => 'लाइब्रेरी खोजें...';

  @override
  String get libraryFilterAll => 'सभी';

  @override
  String get libraryFilterBooks => 'किताबें';

  @override
  String get libraryFilterArticles => 'लेख';

  @override
  String get libraryFilterComics => 'कॉमिक्स';

  @override
  String get libraryFilterNew => 'नया';

  @override
  String get libraryDisplayOptions => 'डिस्प्ले विकल्प';

  @override
  String get libraryDisplayTitle => 'डिस्प्ले';

  @override
  String get libraryDisplayView => 'दृश्य';

  @override
  String get libraryDisplayAppearance => 'रूप';

  @override
  String get libraryDisplayLanguage => 'भाषा';

  @override
  String get libraryDisplayList => 'सूची';

  @override
  String get libraryDisplayGrid => 'ग्रिड';

  @override
  String get libraryThemeSystem => 'सिस्टम';

  @override
  String get libraryThemeSystemDescription => 'डिवाइस सेटिंग का पालन करें';

  @override
  String get libraryThemeLight => 'लाइट';

  @override
  String get libraryThemeLightDescription => 'लाइट रूप का उपयोग करें';

  @override
  String get libraryThemeDark => 'डार्क';

  @override
  String get libraryThemeDarkDescription => 'डार्क रूप का उपयोग करें';

  @override
  String get libraryFailedToLoad => 'लाइब्रेरी लोड नहीं हो सकी';

  @override
  String get libraryLoadCollectionsFailed => 'संग्रह लोड नहीं हो सके';

  @override
  String get libraryUpdateCollectionFailed => 'संग्रह अपडेट नहीं हो सका';

  @override
  String get libraryUpdateFavouritesFailed => 'पसंदीदा अपडेट नहीं हो सके';

  @override
  String get libraryCollectionNameRequired => 'संग्रह का नाम आवश्यक है';

  @override
  String get libraryCreateCollectionFailed => 'संग्रह बनाया नहीं जा सका';

  @override
  String get librarySaveCollectionFailed => 'संग्रह सहेजा नहीं जा सका';

  @override
  String get libraryDeleteCollectionFailed => 'संग्रह हटाया नहीं जा सका';

  @override
  String get libraryAddedToCollection => 'कलेक्शन में जोड़ा गया';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम कलेक्शन में जोड़े गए',
      one: '1 आइटम कलेक्शन में जोड़ा गया',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'कलेक्शन हटाया गया';

  @override
  String get libraryDeletedSuffix => ' हटाया गया';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम हटाए गए',
      one: 'आइटम हटाया गया',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'आइटम हटाए नहीं जा सके',
      one: 'आइटम हटाया नहीं जा सका',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'कलेक्शन में जोड़ें';

  @override
  String get libraryEmptyTitle => 'आपकी लाइब्रेरी खाली है';

  @override
  String get libraryEmptySubtitle => 'अपनी पहली किताब या लेख जोड़ें';

  @override
  String get libraryNoResultsTitle => 'कोई परिणाम नहीं मिला';

  @override
  String get libraryNoResultsSubtitle => 'दूसरी खोज या फ़िल्टर आज़माएं';

  @override
  String get libraryAddToCollectionTitle => 'कलेक्शन में जोड़ें';

  @override
  String get libraryFavourites => 'पसंदीदा';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count चुने गए आइटम के लिए कलेक्शन बनाएं।',
      one: '1 चुने गए आइटम के लिए कलेक्शन बनाएं।',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'नए कलेक्शन का नाम';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count आइटम हटाएं?',
      one: 'यह आइटम हटाएं?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'यह लाइब्रेरी आइटम और आपके हाइलाइट हटाता है। संग्रहित सीखने का डेटा रखा जाता है।',
      one:
          'यह लाइब्रेरी आइटम और आपके हाइलाइट हटाता है। संग्रहित सीखने का डेटा रखा जाता है।',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'कलेक्शन';

  @override
  String get librarySearchCollectionsHint => 'कलेक्शन खोजें...';

  @override
  String get libraryNoCollectionsYet => 'अभी कोई कलेक्शन नहीं';

  @override
  String get libraryNoMatchingCollections => 'कोई मेल खाता कलेक्शन नहीं';

  @override
  String get libraryManualCollections => 'मैनुअल कलेक्शन';

  @override
  String get librarySites => 'साइटें';

  @override
  String get libraryAuthors => 'लेखक';

  @override
  String libraryManageCollection(String name) {
    return '$name प्रबंधित करें';
  }

  @override
  String get libraryOpenCollectionActions => 'कलेक्शन क्रियाएं खोलें';

  @override
  String get libraryManageCollectionTitle => 'कलेक्शन प्रबंधित करें';

  @override
  String get libraryDeleteCollectionTitle => 'कलेक्शन हटाएं?';

  @override
  String get libraryDeleteCollectionButton => 'कलेक्शन हटाएं';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count किताबें',
      one: '1 किताब',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count लेख',
      one: '1 लेख',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 किताबें/लेख';

  @override
  String get libraryNoItemsInCollection => 'इस कलेक्शन में कोई आइटम नहीं';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'यह केवल \"$name\" हटाता है। किताबें और लेख आपकी लाइब्रेरी में रहेंगे।';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return '$title को कलेक्शन से हटाएं';
  }

  @override
  String get librarySourceArticle => 'लेख';

  @override
  String get librarySourceBook => 'किताब';

  @override
  String get librarySourceComic => 'कॉमिक';

  @override
  String get librarySourceNew => 'नया';

  @override
  String get librarySourceDone => 'हो गया';

  @override
  String get librarySourceFinished => 'पूरा';

  @override
  String get librarySourceUntitled => 'बिना शीर्षक स्रोत';

  @override
  String get librarySourceOpenReader => 'रीडर खोलें';

  @override
  String get librarySourceSelect => 'स्रोत चुनें';

  @override
  String get librarySourceDeselect => 'स्रोत अचयनित करें';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent प्रतिशत पढ़ा';
  }

  @override
  String get importAddToLibraryTitle => 'लाइब्रेरी में जोड़ें';

  @override
  String get importUploadBook => 'किताब अपलोड करें';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'लेख सहेजें';

  @override
  String get importSaveArticleDescription =>
      'ऑफलाइन पढ़ने के लिए वेब URL पेस्ट करें';

  @override
  String get importBeforeUploadingTitle => 'अपलोड करने से पहले';

  @override
  String get importBookTermsBody =>
      'केवल वे किताबें, कॉमिक्स और दस्तावेज़ अपलोड करें जिन्हें ReadFlex में उपयोग करने का अधिकार आपके पास है।';

  @override
  String get importBookTermsConfirm =>
      'मैं पुष्टि करता/करती हूं कि मुझे यह फ़ाइल अपलोड करने का अधिकार है।';

  @override
  String get importLegalPrefix => 'जारी रखने पर आप ';

  @override
  String get importLegalAnd => ' और ';

  @override
  String get importLegalSuffix => ' स्वीकार करते हैं।';

  @override
  String get importTerms => 'शर्तें';

  @override
  String get importPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'URL पेस्ट करें';

  @override
  String get importArticleHintClean => 'ऑफलाइन पढ़ने के लिए साफ लेख बनाता है।';

  @override
  String get importArticleHintSource => 'मूल स्रोत लिंक रखता है।';

  @override
  String get importArticleHintLibrary => 'इसे आपकी लाइब्रेरी में जोड़ता है।';

  @override
  String get importUploadingBook => 'किताब अपलोड हो रही है...';

  @override
  String get importFetchingArticle => 'लेख लाया जा रहा है...';

  @override
  String get importSavingArticle => 'ऑफलाइन कॉपी सहेजी जा रही है...';

  @override
  String get importComicAdded => 'कॉमिक जोड़ी गई!';

  @override
  String get importBookAdded => 'किताब जोड़ी गई!';

  @override
  String get importArticleSaved => 'लेख सहेजा गया!';

  @override
  String get importTryAgain => 'फिर कोशिश करें';

  @override
  String get importArticleUrlRequired => 'लेख URL दर्ज करें';

  @override
  String get importInvalidArticleUrl => 'मान्य लेख URL दर्ज करें';

  @override
  String get importBookImportFailed => 'किताब आयात नहीं हो सकी';

  @override
  String get importArticleSaveFailed => 'लेख सहेजा नहीं जा सका';

  @override
  String get highlightAction => 'हाइलाइट';

  @override
  String get highlightTitle => 'हाइलाइट';

  @override
  String get highlightNoteHint => 'नोट जोड़ें (वैकल्पिक)';

  @override
  String get highlightFailedToSave => 'हाइलाइट सहेजा नहीं जा सका';

  @override
  String get highlightColorYellow => 'पीला';

  @override
  String get highlightColorGreen => 'हरा';

  @override
  String get highlightColorBlue => 'नीला';

  @override
  String get highlightColorPink => 'गुलाबी';

  @override
  String get highlightColorPurple => 'बैंगनी';

  @override
  String highlightColorSemantics(String color) {
    return '$color हाइलाइट रंग';
  }

  @override
  String get highlightSelectColor => 'हाइलाइट रंग चुनें';

  @override
  String get readerFailedToLoadContent => 'सामग्री लोड नहीं हो सकी';

  @override
  String get readerGoBack => 'वापस जाएं';

  @override
  String get readerBookSearchUnavailable => 'किताब खोज उपलब्ध नहीं है';

  @override
  String get readerNotReady => 'रीडर तैयार नहीं है';

  @override
  String get readerHighlightSaved => 'हाइलाइट सहेजा गया';

  @override
  String get readerHighlightRemoved => 'हाइलाइट हटाया गया';

  @override
  String get readerHighlightSaveFailed => 'हाइलाइट सहेजा नहीं जा सका';

  @override
  String get readerCommentUpdated => 'टिप्पणी अपडेट हुई';

  @override
  String get readerContents => 'सामग्री';

  @override
  String get readerChapters => 'अध्याय';

  @override
  String get readerBookmarks => 'बुकमार्क';

  @override
  String get readerHighlights => 'हाइलाइट';

  @override
  String get readerSearchChapters => 'अध्याय खोजें';

  @override
  String get readerSearchBookmarks => 'बुकमार्क खोजें';

  @override
  String get readerSearchHighlights => 'हाइलाइट खोजें';

  @override
  String get readerNoBookmarksYet => 'अभी कोई बुकमार्क नहीं';

  @override
  String get readerNoMatchingBookmarks => 'कोई मेल खाता बुकमार्क नहीं';

  @override
  String get readerBookmarkedPage => 'बुकमार्क किया गया पेज';

  @override
  String get readerDeleteBookmark => 'बुकमार्क हटाएं';

  @override
  String get readerNoHighlightsYet => 'अभी कोई हाइलाइट नहीं';

  @override
  String get readerNoMatchingHighlights => 'कोई मेल खाता हाइलाइट नहीं';

  @override
  String get readerHighlightedText => 'हाइलाइट किया गया टेक्स्ट';

  @override
  String get readerLocationUnavailable => 'स्थान उपलब्ध नहीं';

  @override
  String get readerSearchInBook => 'किताब में खोजें';

  @override
  String get readerNoResultsFound => 'कोई परिणाम नहीं मिला';

  @override
  String get readerRecentSearches => 'हाल की खोजें';

  @override
  String get readerRemoveFromHistory => 'इतिहास से हटाएं';

  @override
  String get readerSearchResult => 'खोज परिणाम';

  @override
  String get readerNoMatchingChapters => 'कोई मेल खाता अध्याय नहीं';

  @override
  String get readerNoChaptersFound => 'कोई अध्याय नहीं मिला';

  @override
  String get readerSearchPrompt => 'कम से कम 2 अक्षर लिखें';

  @override
  String get readerSearchAction => 'खोजें';

  @override
  String get readerSearchFailed => 'खोज विफल रही';

  @override
  String get readerUntitledChapter => 'बिना शीर्षक अध्याय';

  @override
  String readerPageNumber(int page) {
    return 'पेज $page';
  }

  @override
  String get readerAppearanceTitle => 'रूप';

  @override
  String get readerReset => 'रीसेट';

  @override
  String get readerTheme => 'थीम';

  @override
  String get readerFont => 'फ़ॉन्ट';

  @override
  String get readerFontSize => 'टेक्स्ट आकार';

  @override
  String get readerLineSpacing => 'लाइन स्पेसिंग';

  @override
  String get readerTextAlignment => 'टेक्स्ट अलाइनमेंट';

  @override
  String get readerPageMargins => 'पेज मार्जिन';

  @override
  String get readerPageTurn => 'पेज पलटना';

  @override
  String get readerAlignStart => 'शुरुआत पर अलाइन करें';

  @override
  String get readerJustifyText => 'टेक्स्ट जस्टिफाई करें';

  @override
  String get readerAlignEnd => 'अंत पर अलाइन करें';

  @override
  String get readerHorizontalPageTurn => 'क्षैतिज पेज पलटना';

  @override
  String get readerVerticalPageTurn => 'लंबवत पेज पलटना';

  @override
  String get readerResetTextSize => 'टेक्स्ट आकार रीसेट करें';

  @override
  String get readerTextSize => 'टेक्स्ट आकार';

  @override
  String get readerDecreaseTextSize => 'टेक्स्ट घटाएं';

  @override
  String get readerIncreaseTextSize => 'टेक्स्ट बढ़ाएं';

  @override
  String get readerResetLineSpacing => 'लाइन स्पेसिंग रीसेट करें';

  @override
  String get readerDecreaseLineSpacing => 'लाइन स्पेसिंग घटाएं';

  @override
  String get readerIncreaseLineSpacing => 'लाइन स्पेसिंग बढ़ाएं';

  @override
  String get readerResetPageMargins => 'मार्जिन रीसेट करें';

  @override
  String get readerDecreasePageMargins => 'मार्जिन घटाएं';

  @override
  String get readerIncreasePageMargins => 'मार्जिन बढ़ाएं';

  @override
  String get readerThemeSnow => 'स्नो';

  @override
  String get readerThemePaper => 'पेपर';

  @override
  String get readerThemeWarm => 'वार्म';

  @override
  String get readerThemeMist => 'ग्रेफाइट';

  @override
  String get readerThemeNight => 'नाइट';

  @override
  String get readerIncreaseBrightness => 'ब्राइटनेस बढ़ाएं';

  @override
  String get readerDecreaseBrightness => 'ब्राइटनेस घटाएं';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'सिस्टम ब्राइटनेस उपयोग में: $label';
  }

  @override
  String get readerUseSystemBrightness => 'सिस्टम ब्राइटनेस उपयोग करें';

  @override
  String get readerPageBookmarked => 'पेज बुकमार्क किया गया';

  @override
  String get readerOpenOriginalArticle => 'मूल लेख खोलें';

  @override
  String get readerBack => 'वापस';

  @override
  String get readerFontAction => 'फ़ॉन्ट';

  @override
  String get readerPageTurnVertical => 'पेज पलटना: लंबवत';

  @override
  String get readerPageTurnHorizontal => 'पेज पलटना: क्षैतिज';

  @override
  String get readerRemoveBookmark => 'बुकमार्क हटाएं';

  @override
  String get readerBookmark => 'बुकमार्क';

  @override
  String get readerEditComment => 'टिप्पणी संपादित करें';

  @override
  String get readerRemoveHighlight => 'हाइलाइट हटाएं';

  @override
  String get readerHighlightNoteTitle => 'हाइलाइट नोट';

  @override
  String get readerEditNoteTitle => 'नोट संपादित करें';

  @override
  String get readerCommentHint => 'टिप्पणी जोड़ें (वैकल्पिक)';

  @override
  String get readerSkip => 'छोड़ें';
}
