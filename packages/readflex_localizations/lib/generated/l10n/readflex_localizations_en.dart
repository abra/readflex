// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ReadflexLocalizationsEn extends ReadflexLocalizations {
  ReadflexLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appSkip => 'Skip';

  @override
  String get appNext => 'Next';

  @override
  String get appGetStarted => 'Get Started';

  @override
  String get appInitializationFailed => 'Initialization failed';

  @override
  String get appRetry => 'Retry';

  @override
  String get appRetrying => 'Retrying...';

  @override
  String get onboardingReadAnythingTitle => 'Read anything';

  @override
  String get onboardingReadAnythingDescription =>
      'Import books and read comfortably with a customizable reader.';

  @override
  String get onboardingHighlightSaveTitle => 'Highlight & save';

  @override
  String get onboardingHighlightSaveDescription =>
      'Select text to create highlights. Add notes for deeper understanding.';

  @override
  String get onboardingOrganizeLibraryTitle => 'Organize your library';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'Keep books and articles in one place and return to your reading progress.';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDone => 'Done';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonClearSearch => 'Clear search';

  @override
  String get libraryTitle => 'Library';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'offline';

  @override
  String get librarySearchHint => 'Search library...';

  @override
  String get libraryFilterAll => 'All';

  @override
  String get libraryFilterBooks => 'Books';

  @override
  String get libraryFilterArticles => 'Articles';

  @override
  String get libraryFilterComics => 'Comics';

  @override
  String get libraryFilterNew => 'New';

  @override
  String get libraryDisplayOptions => 'Display options';

  @override
  String get libraryDisplayTitle => 'Display';

  @override
  String get libraryDisplayView => 'View';

  @override
  String get libraryDisplayAppearance => 'Appearance';

  @override
  String get libraryDisplayLanguage => 'Language';

  @override
  String get libraryDisplayList => 'List';

  @override
  String get libraryDisplayGrid => 'Grid';

  @override
  String get libraryThemeSystem => 'System';

  @override
  String get libraryThemeSystemDescription => 'Follow device setting';

  @override
  String get libraryThemeLight => 'Light';

  @override
  String get libraryThemeLightDescription => 'Use light appearance';

  @override
  String get libraryThemeDark => 'Dark';

  @override
  String get libraryThemeDarkDescription => 'Use dark appearance';

  @override
  String get libraryFailedToLoad => 'Failed to load library';

  @override
  String get libraryLoadCollectionsFailed => 'Failed to load collections';

  @override
  String get libraryUpdateCollectionFailed => 'Failed to update collection';

  @override
  String get libraryUpdateFavouritesFailed => 'Failed to update favourites';

  @override
  String get libraryCollectionNameRequired => 'Collection name is required';

  @override
  String get libraryCreateCollectionFailed => 'Failed to create collection';

  @override
  String get librarySaveCollectionFailed => 'Failed to save collection';

  @override
  String get libraryDeleteCollectionFailed => 'Failed to delete collection';

  @override
  String get libraryAddedToCollection => 'Added to collection';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to collection',
      one: '1 item added to collection',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'Collection deleted';

  @override
  String get libraryDeletedSuffix => ' deleted';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items deleted',
      one: 'Item deleted',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Failed to delete the items',
      one: 'Failed to delete the item',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'Add to collection';

  @override
  String get libraryEmptyTitle => 'Your library is empty';

  @override
  String get libraryEmptySubtitle =>
      'Add your first book or article to get started';

  @override
  String get libraryNoResultsTitle => 'No results found';

  @override
  String get libraryNoResultsSubtitle => 'Try a different search or filter';

  @override
  String get libraryAddToCollectionTitle => 'Add to collection';

  @override
  String get libraryFavourites => 'Favourites';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Create a collection for $count selected items.',
      one: 'Create a collection for 1 selected item.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'New collection name';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count items?',
      one: 'Delete this item?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'This removes the library items and your highlights. Archived learning data is kept.',
      one:
          'This removes the library item and your highlights. Archived learning data is kept.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'Collections';

  @override
  String get librarySearchCollectionsHint => 'Search collections...';

  @override
  String get libraryNoCollectionsYet => 'No collections yet';

  @override
  String get libraryNoMatchingCollections => 'No matching collections';

  @override
  String get libraryManualCollections => 'Manual collections';

  @override
  String get librarySites => 'Sites';

  @override
  String get libraryAuthors => 'Authors';

  @override
  String libraryManageCollection(String name) {
    return 'Manage $name';
  }

  @override
  String get libraryOpenCollectionActions => 'Open collection actions';

  @override
  String get libraryManageCollectionTitle => 'Manage collection';

  @override
  String get libraryDeleteCollectionTitle => 'Delete collection?';

  @override
  String get libraryDeleteCollectionButton => 'Delete collection';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count books',
      one: '1 book',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 books/articles';

  @override
  String get libraryNoItemsInCollection => 'No items in this collection';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'This removes \"$name\" only. Books and articles stay in your library.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return 'Remove $title from collection';
  }

  @override
  String get librarySourceArticle => 'Article';

  @override
  String get librarySourceBook => 'Book';

  @override
  String get librarySourceComic => 'Comic';

  @override
  String get librarySourceNew => 'New';

  @override
  String get librarySourceDone => 'Done';

  @override
  String get librarySourceFinished => 'Finished';

  @override
  String get librarySourceUntitled => 'Untitled source';

  @override
  String get librarySourceOpenReader => 'Open reader';

  @override
  String get librarySourceSelect => 'Select source';

  @override
  String get librarySourceDeselect => 'Deselect source';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent percent read';
  }

  @override
  String get importAddToLibraryTitle => 'Add to Library';

  @override
  String get importUploadBook => 'Upload Book';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'Save Article';

  @override
  String get importSaveArticleDescription =>
      'Paste a web URL for offline reading';

  @override
  String get importBeforeUploadingTitle => 'Before uploading';

  @override
  String get importBookTermsBody =>
      'Only upload books, comics, and documents you have the right to use in ReadFlex.';

  @override
  String get importBookTermsConfirm =>
      'I confirm I have the right to upload this file.';

  @override
  String get importLegalPrefix => 'By continuing, you accept the ';

  @override
  String get importLegalAnd => ' and ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'Terms';

  @override
  String get importPrivacyPolicy => 'Privacy Policy';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'Paste URL';

  @override
  String get importArticleHintClean =>
      'Creates a clean article for offline reading.';

  @override
  String get importArticleHintSource => 'Keeps the original source link.';

  @override
  String get importArticleHintLibrary => 'Adds it to your Library.';

  @override
  String get importUploadingBook => 'Uploading book...';

  @override
  String get importFetchingArticle => 'Fetching article...';

  @override
  String get importSavingArticle => 'Saving offline copy...';

  @override
  String get importComicAdded => 'Comic added!';

  @override
  String get importBookAdded => 'Book added!';

  @override
  String get importArticleSaved => 'Article saved!';

  @override
  String get importTryAgain => 'Try again';

  @override
  String get importArticleUrlRequired => 'Enter an article URL';

  @override
  String get importInvalidArticleUrl => 'Enter a valid article URL';

  @override
  String get importBookImportFailed => 'Failed to import the book';

  @override
  String get importArticleSaveFailed => 'Failed to save the article';

  @override
  String get highlightAction => 'Highlight';

  @override
  String get highlightTitle => 'Highlight';

  @override
  String get highlightNoteHint => 'Add a note (optional)';

  @override
  String get highlightFailedToSave => 'Failed to save highlight';

  @override
  String get highlightColorYellow => 'Yellow';

  @override
  String get highlightColorGreen => 'Green';

  @override
  String get highlightColorBlue => 'Blue';

  @override
  String get highlightColorPink => 'Pink';

  @override
  String get highlightColorPurple => 'Purple';

  @override
  String highlightColorSemantics(String color) {
    return '$color highlight color';
  }

  @override
  String get highlightSelectColor => 'Select highlight color';

  @override
  String get readerFailedToLoadContent => 'Failed to load content';

  @override
  String get readerGoBack => 'Go Back';

  @override
  String get readerBookSearchUnavailable => 'Book search is unavailable';

  @override
  String get readerNotReady => 'Reader is not ready';

  @override
  String get readerHighlightSaved => 'Highlight saved';

  @override
  String get readerHighlightRemoved => 'Highlight removed';

  @override
  String get readerHighlightSaveFailed => 'Failed to save highlight';

  @override
  String get readerCommentUpdated => 'Comment updated';

  @override
  String get readerContents => 'Contents';

  @override
  String get readerChapters => 'Chapters';

  @override
  String get readerBookmarks => 'Bookmarks';

  @override
  String get readerHighlights => 'Highlights';

  @override
  String get readerSearchChapters => 'Search chapters';

  @override
  String get readerSearchBookmarks => 'Search bookmarks';

  @override
  String get readerSearchHighlights => 'Search highlights';

  @override
  String get readerNoBookmarksYet => 'No bookmarks yet';

  @override
  String get readerNoMatchingBookmarks => 'No matching bookmarks';

  @override
  String get readerBookmarkedPage => 'Bookmarked page';

  @override
  String get readerDeleteBookmark => 'Delete bookmark';

  @override
  String get readerNoHighlightsYet => 'No highlights yet';

  @override
  String get readerNoMatchingHighlights => 'No matching highlights';

  @override
  String get readerHighlightedText => 'Highlighted text';

  @override
  String get readerLocationUnavailable => 'Location unavailable';

  @override
  String get readerSearchInBook => 'Search in book';

  @override
  String get readerNoResultsFound => 'No results found';

  @override
  String get readerRecentSearches => 'Recent searches';

  @override
  String get readerRemoveFromHistory => 'Remove from history';

  @override
  String get readerSearchResult => 'Search result';

  @override
  String get readerNoMatchingChapters => 'No matching chapters';

  @override
  String get readerNoChaptersFound => 'No chapters found';

  @override
  String get readerSearchPrompt => 'Type at least 2 characters to search';

  @override
  String get readerSearchAction => 'Search';

  @override
  String get readerSearchFailed => 'Search failed';

  @override
  String get readerUntitledChapter => 'Untitled chapter';

  @override
  String readerPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get readerAppearanceTitle => 'Appearance';

  @override
  String get readerReset => 'Reset';

  @override
  String get readerTheme => 'Theme';

  @override
  String get readerFont => 'Font';

  @override
  String get readerFontSize => 'Font size';

  @override
  String get readerLineSpacing => 'Line spacing';

  @override
  String get readerTextAlignment => 'Text alignment';

  @override
  String get readerPageMargins => 'Page margins';

  @override
  String get readerPageTurn => 'Page turn';

  @override
  String get readerAlignStart => 'Align start';

  @override
  String get readerJustifyText => 'Justify text';

  @override
  String get readerAlignEnd => 'Align end';

  @override
  String get readerHorizontalPageTurn => 'Horizontal page turn';

  @override
  String get readerVerticalPageTurn => 'Vertical page turn';

  @override
  String get readerResetTextSize => 'Reset text size';

  @override
  String get readerTextSize => 'Text size';

  @override
  String get readerDecreaseTextSize => 'Decrease text size';

  @override
  String get readerIncreaseTextSize => 'Increase text size';

  @override
  String get readerResetLineSpacing => 'Reset line spacing';

  @override
  String get readerDecreaseLineSpacing => 'Decrease line spacing';

  @override
  String get readerIncreaseLineSpacing => 'Increase line spacing';

  @override
  String get readerResetPageMargins => 'Reset page margins';

  @override
  String get readerDecreasePageMargins => 'Decrease page margins';

  @override
  String get readerIncreasePageMargins => 'Increase page margins';

  @override
  String get readerThemeSnow => 'Snow';

  @override
  String get readerThemePaper => 'Paper';

  @override
  String get readerThemeWarm => 'Warm';

  @override
  String get readerThemeMist => 'Graphite';

  @override
  String get readerThemeNight => 'Night';

  @override
  String get readerIncreaseBrightness => 'Increase brightness';

  @override
  String get readerDecreaseBrightness => 'Decrease brightness';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'Using system brightness: $label';
  }

  @override
  String get readerUseSystemBrightness => 'Use system brightness';

  @override
  String get readerPageBookmarked => 'Page bookmarked';

  @override
  String get readerOpenOriginalArticle => 'Open original article';

  @override
  String get readerBack => 'Back';

  @override
  String get readerFontAction => 'Font';

  @override
  String get readerPageTurnVertical => 'Page turn: Vertical';

  @override
  String get readerPageTurnHorizontal => 'Page turn: Horizontal';

  @override
  String get readerRemoveBookmark => 'Remove bookmark';

  @override
  String get readerBookmark => 'Bookmark';

  @override
  String get readerEditComment => 'Edit comment';

  @override
  String get readerRemoveHighlight => 'Remove highlight';

  @override
  String get readerHighlightNoteTitle => 'Highlight note';

  @override
  String get readerEditNoteTitle => 'Edit note';

  @override
  String get readerCommentHint => 'Add a comment (optional)';

  @override
  String get readerSkip => 'Skip';
}
