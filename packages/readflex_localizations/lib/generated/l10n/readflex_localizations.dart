import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'readflex_localizations_ar.dart';
import 'readflex_localizations_de.dart';
import 'readflex_localizations_en.dart';
import 'readflex_localizations_es.dart';
import 'readflex_localizations_fr.dart';
import 'readflex_localizations_hi.dart';
import 'readflex_localizations_ja.dart';
import 'readflex_localizations_pt.dart';
import 'readflex_localizations_ru.dart';
import 'readflex_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ReadflexLocalizations
/// returned by `ReadflexLocalizations.of(context)`.
///
/// Applications need to include `ReadflexLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/readflex_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ReadflexLocalizations.localizationsDelegates,
///   supportedLocales: ReadflexLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ReadflexLocalizations.supportedLocales
/// property.
abstract class ReadflexLocalizations {
  ReadflexLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ReadflexLocalizations? of(BuildContext context) {
    return Localizations.of<ReadflexLocalizations>(
      context,
      ReadflexLocalizations,
    );
  }

  static const LocalizationsDelegate<ReadflexLocalizations> delegate =
      _ReadflexLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('hi'),
    Locale('es'),
    Locale('ar'),
    Locale('fr'),
    Locale('ru'),
    Locale('pt'),
    Locale('de'),
    Locale('ja'),
  ];

  /// No description provided for @appSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get appSkip;

  /// No description provided for @appNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get appNext;

  /// No description provided for @appGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get appGetStarted;

  /// No description provided for @appInitializationFailed.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed'**
  String get appInitializationFailed;

  /// No description provided for @appRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get appRetry;

  /// No description provided for @appRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get appRetrying;

  /// No description provided for @onboardingReadAnythingTitle.
  ///
  /// In en, this message translates to:
  /// **'Read anything'**
  String get onboardingReadAnythingTitle;

  /// No description provided for @onboardingReadAnythingDescription.
  ///
  /// In en, this message translates to:
  /// **'Import books and read comfortably with a customizable reader.'**
  String get onboardingReadAnythingDescription;

  /// No description provided for @onboardingHighlightSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight & save'**
  String get onboardingHighlightSaveTitle;

  /// No description provided for @onboardingHighlightSaveDescription.
  ///
  /// In en, this message translates to:
  /// **'Select text to create highlights. Add notes for deeper understanding.'**
  String get onboardingHighlightSaveDescription;

  /// No description provided for @onboardingOrganizeLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Organize your library'**
  String get onboardingOrganizeLibraryTitle;

  /// No description provided for @onboardingOrganizeLibraryDescription.
  ///
  /// In en, this message translates to:
  /// **'Keep books and articles in one place and return to your reading progress.'**
  String get onboardingOrganizeLibraryDescription;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commonClearSearch;

  /// No description provided for @libraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// No description provided for @libraryItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item} other{{count} items}}'**
  String libraryItemCount(int count);

  /// No description provided for @libraryOffline.
  ///
  /// In en, this message translates to:
  /// **'offline'**
  String get libraryOffline;

  /// No description provided for @librarySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search library...'**
  String get librarySearchHint;

  /// No description provided for @libraryFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get libraryFilterAll;

  /// No description provided for @libraryFilterBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get libraryFilterBooks;

  /// No description provided for @libraryFilterArticles.
  ///
  /// In en, this message translates to:
  /// **'Articles'**
  String get libraryFilterArticles;

  /// No description provided for @libraryFilterComics.
  ///
  /// In en, this message translates to:
  /// **'Comics'**
  String get libraryFilterComics;

  /// No description provided for @libraryFilterNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get libraryFilterNew;

  /// No description provided for @libraryDisplayOptions.
  ///
  /// In en, this message translates to:
  /// **'Display options'**
  String get libraryDisplayOptions;

  /// No description provided for @libraryDisplayTitle.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get libraryDisplayTitle;

  /// No description provided for @libraryDisplayView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get libraryDisplayView;

  /// No description provided for @libraryDisplayAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get libraryDisplayAppearance;

  /// No description provided for @libraryDisplayLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get libraryDisplayLanguage;

  /// No description provided for @libraryDisplayList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get libraryDisplayList;

  /// No description provided for @libraryDisplayGrid.
  ///
  /// In en, this message translates to:
  /// **'Grid'**
  String get libraryDisplayGrid;

  /// No description provided for @libraryThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get libraryThemeSystem;

  /// No description provided for @libraryThemeSystemDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow device setting'**
  String get libraryThemeSystemDescription;

  /// No description provided for @libraryThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get libraryThemeLight;

  /// No description provided for @libraryThemeLightDescription.
  ///
  /// In en, this message translates to:
  /// **'Use light appearance'**
  String get libraryThemeLightDescription;

  /// No description provided for @libraryThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get libraryThemeDark;

  /// No description provided for @libraryThemeDarkDescription.
  ///
  /// In en, this message translates to:
  /// **'Use dark appearance'**
  String get libraryThemeDarkDescription;

  /// No description provided for @libraryFailedToLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load library'**
  String get libraryFailedToLoad;

  /// No description provided for @libraryLoadCollectionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load collections'**
  String get libraryLoadCollectionsFailed;

  /// No description provided for @libraryUpdateCollectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update collection'**
  String get libraryUpdateCollectionFailed;

  /// No description provided for @libraryUpdateFavouritesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update favourites'**
  String get libraryUpdateFavouritesFailed;

  /// No description provided for @libraryCollectionNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Collection name is required'**
  String get libraryCollectionNameRequired;

  /// No description provided for @libraryCreateCollectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create collection'**
  String get libraryCreateCollectionFailed;

  /// No description provided for @librarySaveCollectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save collection'**
  String get librarySaveCollectionFailed;

  /// No description provided for @libraryDeleteCollectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete collection'**
  String get libraryDeleteCollectionFailed;

  /// No description provided for @libraryAddedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Added to collection'**
  String get libraryAddedToCollection;

  /// No description provided for @libraryItemsAddedToCollection.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 item added to collection} other{{count} items added to collection}}'**
  String libraryItemsAddedToCollection(int count);

  /// No description provided for @libraryCollectionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Collection deleted'**
  String get libraryCollectionDeleted;

  /// No description provided for @libraryDeletedSuffix.
  ///
  /// In en, this message translates to:
  /// **' deleted'**
  String get libraryDeletedSuffix;

  /// No description provided for @libraryItemsDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Item deleted} other{{count} items deleted}}'**
  String libraryItemsDeleted(int count);

  /// No description provided for @libraryDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Failed to delete the item} other{Failed to delete the items}}'**
  String libraryDeleteFailed(int count);

  /// No description provided for @libraryAddToCollection.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get libraryAddToCollection;

  /// No description provided for @libraryEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your library is empty'**
  String get libraryEmptyTitle;

  /// No description provided for @libraryEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first book or article to get started'**
  String get libraryEmptySubtitle;

  /// No description provided for @libraryNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get libraryNoResultsTitle;

  /// No description provided for @libraryNoResultsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter'**
  String get libraryNoResultsSubtitle;

  /// No description provided for @libraryAddToCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to collection'**
  String get libraryAddToCollectionTitle;

  /// No description provided for @libraryFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get libraryFavourites;

  /// No description provided for @libraryCreateCollectionPrompt.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Create a collection for 1 selected item.} other{Create a collection for {count} selected items.}}'**
  String libraryCreateCollectionPrompt(int count);

  /// No description provided for @libraryNewCollectionName.
  ///
  /// In en, this message translates to:
  /// **'New collection name'**
  String get libraryNewCollectionName;

  /// No description provided for @libraryDeleteItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Delete this item?} other{Delete {count} items?}}'**
  String libraryDeleteItemsTitle(int count);

  /// No description provided for @libraryDeleteItemsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{This removes the library item and your highlights. Archived learning data is kept.} other{This removes the library items and your highlights. Archived learning data is kept.}}'**
  String libraryDeleteItemsBody(int count);

  /// No description provided for @libraryCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get libraryCollectionsTitle;

  /// No description provided for @librarySearchCollectionsHint.
  ///
  /// In en, this message translates to:
  /// **'Search collections...'**
  String get librarySearchCollectionsHint;

  /// No description provided for @libraryNoCollectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get libraryNoCollectionsYet;

  /// No description provided for @libraryNoMatchingCollections.
  ///
  /// In en, this message translates to:
  /// **'No matching collections'**
  String get libraryNoMatchingCollections;

  /// No description provided for @libraryManualCollections.
  ///
  /// In en, this message translates to:
  /// **'Manual collections'**
  String get libraryManualCollections;

  /// No description provided for @librarySites.
  ///
  /// In en, this message translates to:
  /// **'Sites'**
  String get librarySites;

  /// No description provided for @libraryAuthors.
  ///
  /// In en, this message translates to:
  /// **'Authors'**
  String get libraryAuthors;

  /// No description provided for @libraryManageCollection.
  ///
  /// In en, this message translates to:
  /// **'Manage {name}'**
  String libraryManageCollection(String name);

  /// No description provided for @libraryOpenCollectionActions.
  ///
  /// In en, this message translates to:
  /// **'Open collection actions'**
  String get libraryOpenCollectionActions;

  /// No description provided for @libraryManageCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage collection'**
  String get libraryManageCollectionTitle;

  /// No description provided for @libraryDeleteCollectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get libraryDeleteCollectionTitle;

  /// No description provided for @libraryDeleteCollectionButton.
  ///
  /// In en, this message translates to:
  /// **'Delete collection'**
  String get libraryDeleteCollectionButton;

  /// No description provided for @libraryBookCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 book} other{{count} books}}'**
  String libraryBookCount(int count);

  /// No description provided for @libraryArticleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 article} other{{count} articles}}'**
  String libraryArticleCount(int count);

  /// No description provided for @libraryEmptySourceCount.
  ///
  /// In en, this message translates to:
  /// **'0 books/articles'**
  String get libraryEmptySourceCount;

  /// No description provided for @libraryNoItemsInCollection.
  ///
  /// In en, this message translates to:
  /// **'No items in this collection'**
  String get libraryNoItemsInCollection;

  /// No description provided for @libraryDeleteCollectionBody.
  ///
  /// In en, this message translates to:
  /// **'This removes \"{name}\" only. Books and articles stay in your library.'**
  String libraryDeleteCollectionBody(String name);

  /// No description provided for @libraryRemoveFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Remove {title} from collection'**
  String libraryRemoveFromCollection(String title);

  /// No description provided for @librarySourceArticle.
  ///
  /// In en, this message translates to:
  /// **'Article'**
  String get librarySourceArticle;

  /// No description provided for @librarySourceBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get librarySourceBook;

  /// No description provided for @librarySourceComic.
  ///
  /// In en, this message translates to:
  /// **'Comic'**
  String get librarySourceComic;

  /// No description provided for @librarySourceNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get librarySourceNew;

  /// No description provided for @librarySourceDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get librarySourceDone;

  /// No description provided for @librarySourceFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get librarySourceFinished;

  /// No description provided for @librarySourceUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled source'**
  String get librarySourceUntitled;

  /// No description provided for @librarySourceOpenReader.
  ///
  /// In en, this message translates to:
  /// **'Open reader'**
  String get librarySourceOpenReader;

  /// No description provided for @librarySourceSelect.
  ///
  /// In en, this message translates to:
  /// **'Select source'**
  String get librarySourceSelect;

  /// No description provided for @librarySourceDeselect.
  ///
  /// In en, this message translates to:
  /// **'Deselect source'**
  String get librarySourceDeselect;

  /// No description provided for @librarySourcePercentRead.
  ///
  /// In en, this message translates to:
  /// **'{percent} percent read'**
  String librarySourcePercentRead(int percent);

  /// No description provided for @importAddToLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to Library'**
  String get importAddToLibraryTitle;

  /// No description provided for @importUploadBook.
  ///
  /// In en, this message translates to:
  /// **'Upload Book'**
  String get importUploadBook;

  /// No description provided for @importUploadBookFormats.
  ///
  /// In en, this message translates to:
  /// **'EPUB, FB2, MOBI, PDF, AZW3, CBZ'**
  String get importUploadBookFormats;

  /// No description provided for @importSaveArticle.
  ///
  /// In en, this message translates to:
  /// **'Save Article'**
  String get importSaveArticle;

  /// No description provided for @importSaveArticleDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste a web URL for offline reading'**
  String get importSaveArticleDescription;

  /// No description provided for @importBeforeUploadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Before uploading'**
  String get importBeforeUploadingTitle;

  /// No description provided for @importBookTermsBody.
  ///
  /// In en, this message translates to:
  /// **'Only upload books, comics, and documents you have the right to use in ReadFlex.'**
  String get importBookTermsBody;

  /// No description provided for @importBookTermsConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm I have the right to upload this file.'**
  String get importBookTermsConfirm;

  /// No description provided for @importLegalPrefix.
  ///
  /// In en, this message translates to:
  /// **'By continuing, you accept the '**
  String get importLegalPrefix;

  /// No description provided for @importLegalAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get importLegalAnd;

  /// No description provided for @importLegalSuffix.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get importLegalSuffix;

  /// No description provided for @importTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get importTerms;

  /// No description provided for @importPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get importPrivacyPolicy;

  /// No description provided for @importArticleUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/article'**
  String get importArticleUrlHint;

  /// No description provided for @importPasteUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste URL'**
  String get importPasteUrl;

  /// No description provided for @importArticleHintClean.
  ///
  /// In en, this message translates to:
  /// **'Creates a clean article for offline reading.'**
  String get importArticleHintClean;

  /// No description provided for @importArticleHintSource.
  ///
  /// In en, this message translates to:
  /// **'Keeps the original source link.'**
  String get importArticleHintSource;

  /// No description provided for @importArticleHintLibrary.
  ///
  /// In en, this message translates to:
  /// **'Adds it to your Library.'**
  String get importArticleHintLibrary;

  /// No description provided for @importUploadingBook.
  ///
  /// In en, this message translates to:
  /// **'Uploading book...'**
  String get importUploadingBook;

  /// No description provided for @importFetchingArticle.
  ///
  /// In en, this message translates to:
  /// **'Fetching article...'**
  String get importFetchingArticle;

  /// No description provided for @importSavingArticle.
  ///
  /// In en, this message translates to:
  /// **'Saving offline copy...'**
  String get importSavingArticle;

  /// No description provided for @importComicAdded.
  ///
  /// In en, this message translates to:
  /// **'Comic added!'**
  String get importComicAdded;

  /// No description provided for @importBookAdded.
  ///
  /// In en, this message translates to:
  /// **'Book added!'**
  String get importBookAdded;

  /// No description provided for @importArticleSaved.
  ///
  /// In en, this message translates to:
  /// **'Article saved!'**
  String get importArticleSaved;

  /// No description provided for @importTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get importTryAgain;

  /// No description provided for @importArticleUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter an article URL'**
  String get importArticleUrlRequired;

  /// No description provided for @importInvalidArticleUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid article URL'**
  String get importInvalidArticleUrl;

  /// No description provided for @importBookImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to import the book'**
  String get importBookImportFailed;

  /// No description provided for @importArticleSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the article'**
  String get importArticleSaveFailed;

  /// No description provided for @highlightAction.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlightAction;

  /// No description provided for @highlightTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get highlightTitle;

  /// No description provided for @highlightNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get highlightNoteHint;

  /// No description provided for @highlightFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save highlight'**
  String get highlightFailedToSave;

  /// No description provided for @highlightColorYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get highlightColorYellow;

  /// No description provided for @highlightColorGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get highlightColorGreen;

  /// No description provided for @highlightColorBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get highlightColorBlue;

  /// No description provided for @highlightColorPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get highlightColorPink;

  /// No description provided for @highlightColorPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get highlightColorPurple;

  /// No description provided for @highlightColorSemantics.
  ///
  /// In en, this message translates to:
  /// **'{color} highlight color'**
  String highlightColorSemantics(String color);

  /// No description provided for @highlightSelectColor.
  ///
  /// In en, this message translates to:
  /// **'Select highlight color'**
  String get highlightSelectColor;

  /// No description provided for @readerFailedToLoadContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to load content'**
  String get readerFailedToLoadContent;

  /// No description provided for @readerGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get readerGoBack;

  /// No description provided for @readerBookSearchUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Book search is unavailable'**
  String get readerBookSearchUnavailable;

  /// No description provided for @readerNotReady.
  ///
  /// In en, this message translates to:
  /// **'Reader is not ready'**
  String get readerNotReady;

  /// No description provided for @readerHighlightSaved.
  ///
  /// In en, this message translates to:
  /// **'Highlight saved'**
  String get readerHighlightSaved;

  /// No description provided for @readerHighlightRemoved.
  ///
  /// In en, this message translates to:
  /// **'Highlight removed'**
  String get readerHighlightRemoved;

  /// No description provided for @readerHighlightSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save highlight'**
  String get readerHighlightSaveFailed;

  /// No description provided for @readerCommentUpdated.
  ///
  /// In en, this message translates to:
  /// **'Comment updated'**
  String get readerCommentUpdated;

  /// No description provided for @readerContents.
  ///
  /// In en, this message translates to:
  /// **'Contents'**
  String get readerContents;

  /// No description provided for @readerChapters.
  ///
  /// In en, this message translates to:
  /// **'Chapters'**
  String get readerChapters;

  /// No description provided for @readerBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get readerBookmarks;

  /// No description provided for @readerHighlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get readerHighlights;

  /// No description provided for @readerSearchChapters.
  ///
  /// In en, this message translates to:
  /// **'Search chapters'**
  String get readerSearchChapters;

  /// No description provided for @readerSearchBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Search bookmarks'**
  String get readerSearchBookmarks;

  /// No description provided for @readerSearchHighlights.
  ///
  /// In en, this message translates to:
  /// **'Search highlights'**
  String get readerSearchHighlights;

  /// No description provided for @readerNoBookmarksYet.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get readerNoBookmarksYet;

  /// No description provided for @readerNoMatchingBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No matching bookmarks'**
  String get readerNoMatchingBookmarks;

  /// No description provided for @readerBookmarkedPage.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked page'**
  String get readerBookmarkedPage;

  /// No description provided for @readerDeleteBookmark.
  ///
  /// In en, this message translates to:
  /// **'Delete bookmark'**
  String get readerDeleteBookmark;

  /// No description provided for @readerNoHighlightsYet.
  ///
  /// In en, this message translates to:
  /// **'No highlights yet'**
  String get readerNoHighlightsYet;

  /// No description provided for @readerNoMatchingHighlights.
  ///
  /// In en, this message translates to:
  /// **'No matching highlights'**
  String get readerNoMatchingHighlights;

  /// No description provided for @readerHighlightedText.
  ///
  /// In en, this message translates to:
  /// **'Highlighted text'**
  String get readerHighlightedText;

  /// No description provided for @readerLocationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get readerLocationUnavailable;

  /// No description provided for @readerSearchInBook.
  ///
  /// In en, this message translates to:
  /// **'Search in book'**
  String get readerSearchInBook;

  /// No description provided for @readerNoResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get readerNoResultsFound;

  /// No description provided for @readerRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get readerRecentSearches;

  /// No description provided for @readerRemoveFromHistory.
  ///
  /// In en, this message translates to:
  /// **'Remove from history'**
  String get readerRemoveFromHistory;

  /// No description provided for @readerSearchResult.
  ///
  /// In en, this message translates to:
  /// **'Search result'**
  String get readerSearchResult;

  /// No description provided for @readerNoMatchingChapters.
  ///
  /// In en, this message translates to:
  /// **'No matching chapters'**
  String get readerNoMatchingChapters;

  /// No description provided for @readerNoChaptersFound.
  ///
  /// In en, this message translates to:
  /// **'No chapters found'**
  String get readerNoChaptersFound;

  /// No description provided for @readerSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Type at least 2 characters to search'**
  String get readerSearchPrompt;

  /// No description provided for @readerSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get readerSearchAction;

  /// No description provided for @readerSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get readerSearchFailed;

  /// No description provided for @readerUntitledChapter.
  ///
  /// In en, this message translates to:
  /// **'Untitled chapter'**
  String get readerUntitledChapter;

  /// No description provided for @readerPageNumber.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String readerPageNumber(int page);

  /// No description provided for @readerAppearanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get readerAppearanceTitle;

  /// No description provided for @readerReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get readerReset;

  /// No description provided for @readerTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get readerTheme;

  /// No description provided for @readerFont.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get readerFont;

  /// No description provided for @readerFontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get readerFontSize;

  /// No description provided for @readerLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get readerLineSpacing;

  /// No description provided for @readerTextAlignment.
  ///
  /// In en, this message translates to:
  /// **'Text alignment'**
  String get readerTextAlignment;

  /// No description provided for @readerPageMargins.
  ///
  /// In en, this message translates to:
  /// **'Page margins'**
  String get readerPageMargins;

  /// No description provided for @readerPageTurn.
  ///
  /// In en, this message translates to:
  /// **'Page turn'**
  String get readerPageTurn;

  /// No description provided for @readerAlignStart.
  ///
  /// In en, this message translates to:
  /// **'Align start'**
  String get readerAlignStart;

  /// No description provided for @readerJustifyText.
  ///
  /// In en, this message translates to:
  /// **'Justify text'**
  String get readerJustifyText;

  /// No description provided for @readerAlignEnd.
  ///
  /// In en, this message translates to:
  /// **'Align end'**
  String get readerAlignEnd;

  /// No description provided for @readerHorizontalPageTurn.
  ///
  /// In en, this message translates to:
  /// **'Horizontal page turn'**
  String get readerHorizontalPageTurn;

  /// No description provided for @readerVerticalPageTurn.
  ///
  /// In en, this message translates to:
  /// **'Vertical page turn'**
  String get readerVerticalPageTurn;

  /// No description provided for @readerResetTextSize.
  ///
  /// In en, this message translates to:
  /// **'Reset text size'**
  String get readerResetTextSize;

  /// No description provided for @readerTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get readerTextSize;

  /// No description provided for @readerDecreaseTextSize.
  ///
  /// In en, this message translates to:
  /// **'Decrease text size'**
  String get readerDecreaseTextSize;

  /// No description provided for @readerIncreaseTextSize.
  ///
  /// In en, this message translates to:
  /// **'Increase text size'**
  String get readerIncreaseTextSize;

  /// No description provided for @readerResetLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Reset line spacing'**
  String get readerResetLineSpacing;

  /// No description provided for @readerDecreaseLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Decrease line spacing'**
  String get readerDecreaseLineSpacing;

  /// No description provided for @readerIncreaseLineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Increase line spacing'**
  String get readerIncreaseLineSpacing;

  /// No description provided for @readerResetPageMargins.
  ///
  /// In en, this message translates to:
  /// **'Reset page margins'**
  String get readerResetPageMargins;

  /// No description provided for @readerDecreasePageMargins.
  ///
  /// In en, this message translates to:
  /// **'Decrease page margins'**
  String get readerDecreasePageMargins;

  /// No description provided for @readerIncreasePageMargins.
  ///
  /// In en, this message translates to:
  /// **'Increase page margins'**
  String get readerIncreasePageMargins;

  /// No description provided for @readerThemeSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get readerThemeSnow;

  /// No description provided for @readerThemePaper.
  ///
  /// In en, this message translates to:
  /// **'Paper'**
  String get readerThemePaper;

  /// No description provided for @readerThemeWarm.
  ///
  /// In en, this message translates to:
  /// **'Warm'**
  String get readerThemeWarm;

  /// No description provided for @readerThemeMist.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get readerThemeMist;

  /// No description provided for @readerThemeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get readerThemeNight;

  /// No description provided for @readerIncreaseBrightness.
  ///
  /// In en, this message translates to:
  /// **'Increase brightness'**
  String get readerIncreaseBrightness;

  /// No description provided for @readerDecreaseBrightness.
  ///
  /// In en, this message translates to:
  /// **'Decrease brightness'**
  String get readerDecreaseBrightness;

  /// No description provided for @readerUsingSystemBrightness.
  ///
  /// In en, this message translates to:
  /// **'Using system brightness: {label}'**
  String readerUsingSystemBrightness(String label);

  /// No description provided for @readerUseSystemBrightness.
  ///
  /// In en, this message translates to:
  /// **'Use system brightness'**
  String get readerUseSystemBrightness;

  /// No description provided for @readerPageBookmarked.
  ///
  /// In en, this message translates to:
  /// **'Page bookmarked'**
  String get readerPageBookmarked;

  /// No description provided for @readerOpenOriginalArticle.
  ///
  /// In en, this message translates to:
  /// **'Open original article'**
  String get readerOpenOriginalArticle;

  /// No description provided for @readerBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get readerBack;

  /// No description provided for @readerFontAction.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get readerFontAction;

  /// No description provided for @readerPageTurnVertical.
  ///
  /// In en, this message translates to:
  /// **'Page turn: Vertical'**
  String get readerPageTurnVertical;

  /// No description provided for @readerPageTurnHorizontal.
  ///
  /// In en, this message translates to:
  /// **'Page turn: Horizontal'**
  String get readerPageTurnHorizontal;

  /// No description provided for @readerRemoveBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get readerRemoveBookmark;

  /// No description provided for @readerBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get readerBookmark;

  /// No description provided for @readerEditComment.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get readerEditComment;

  /// No description provided for @readerRemoveHighlight.
  ///
  /// In en, this message translates to:
  /// **'Remove highlight'**
  String get readerRemoveHighlight;

  /// No description provided for @readerHighlightNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight note'**
  String get readerHighlightNoteTitle;

  /// No description provided for @readerEditNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get readerEditNoteTitle;

  /// No description provided for @readerCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get readerCommentHint;

  /// No description provided for @readerSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get readerSkip;
}

class _ReadflexLocalizationsDelegate
    extends LocalizationsDelegate<ReadflexLocalizations> {
  const _ReadflexLocalizationsDelegate();

  @override
  Future<ReadflexLocalizations> load(Locale locale) {
    return SynchronousFuture<ReadflexLocalizations>(
      lookupReadflexLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'hi',
    'ja',
    'pt',
    'ru',
    'zh',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_ReadflexLocalizationsDelegate old) => false;
}

ReadflexLocalizations lookupReadflexLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return ReadflexLocalizationsAr();
    case 'de':
      return ReadflexLocalizationsDe();
    case 'en':
      return ReadflexLocalizationsEn();
    case 'es':
      return ReadflexLocalizationsEs();
    case 'fr':
      return ReadflexLocalizationsFr();
    case 'hi':
      return ReadflexLocalizationsHi();
    case 'ja':
      return ReadflexLocalizationsJa();
    case 'pt':
      return ReadflexLocalizationsPt();
    case 'ru':
      return ReadflexLocalizationsRu();
    case 'zh':
      return ReadflexLocalizationsZh();
  }

  throw FlutterError(
    'ReadflexLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
