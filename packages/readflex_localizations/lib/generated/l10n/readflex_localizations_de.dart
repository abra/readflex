// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class ReadflexLocalizationsDe extends ReadflexLocalizations {
  ReadflexLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appSkip => 'Überspringen';

  @override
  String get appNext => 'Weiter';

  @override
  String get appGetStarted => 'Loslegen';

  @override
  String get appInitializationFailed => 'Initialisierung fehlgeschlagen';

  @override
  String get appRetry => 'Erneut versuchen';

  @override
  String get appRetrying => 'Wird erneut versucht...';

  @override
  String get onboardingReadAnythingTitle => 'Alles lesen';

  @override
  String get onboardingReadAnythingDescription =>
      'Importiere Bücher und lies bequem mit einem anpassbaren Reader.';

  @override
  String get onboardingHighlightSaveTitle => 'Markieren und speichern';

  @override
  String get onboardingHighlightSaveDescription =>
      'Wähle Text aus, um Markierungen zu erstellen. Füge Notizen für besseres Verständnis hinzu.';

  @override
  String get onboardingOrganizeLibraryTitle => 'Bibliothek organisieren';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'Bewahre Bücher und Artikel an einem Ort auf und kehre zu deinem Lesefortschritt zurück.';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonCreate => 'Erstellen';

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonClearSearch => 'Suche löschen';

  @override
  String get libraryTitle => 'Bibliothek';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente',
      one: '1 Element',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'offline';

  @override
  String get librarySearchHint => 'Bibliothek durchsuchen...';

  @override
  String get libraryFilterAll => 'Alle';

  @override
  String get libraryFilterBooks => 'Bücher';

  @override
  String get libraryFilterArticles => 'Artikel';

  @override
  String get libraryFilterComics => 'Comics';

  @override
  String get libraryFilterNew => 'Neu';

  @override
  String get libraryDisplayOptions => 'Anzeigeoptionen';

  @override
  String get libraryDisplayTitle => 'Anzeige';

  @override
  String get libraryDisplayView => 'Ansicht';

  @override
  String get libraryDisplayAppearance => 'Darstellung';

  @override
  String get libraryDisplayLanguage => 'Sprache';

  @override
  String get libraryDisplayList => 'Liste';

  @override
  String get libraryDisplayGrid => 'Raster';

  @override
  String get libraryThemeSystem => 'System';

  @override
  String get libraryThemeSystemDescription => 'Geräteeinstellung verwenden';

  @override
  String get libraryThemeLight => 'Hell';

  @override
  String get libraryThemeLightDescription => 'Helle Darstellung verwenden';

  @override
  String get libraryThemeDark => 'Dunkel';

  @override
  String get libraryThemeDarkDescription => 'Dunkle Darstellung verwenden';

  @override
  String get libraryFailedToLoad => 'Bibliothek konnte nicht geladen werden';

  @override
  String get libraryLoadCollectionsFailed =>
      'Sammlungen konnten nicht geladen werden';

  @override
  String get libraryUpdateCollectionFailed =>
      'Sammlung konnte nicht aktualisiert werden';

  @override
  String get libraryUpdateFavouritesFailed =>
      'Favoriten konnten nicht aktualisiert werden';

  @override
  String get libraryCollectionNameRequired =>
      'Der Sammlungsname ist erforderlich';

  @override
  String get libraryCreateCollectionFailed =>
      'Sammlung konnte nicht erstellt werden';

  @override
  String get librarySaveCollectionFailed =>
      'Sammlung konnte nicht gespeichert werden';

  @override
  String get libraryDeleteCollectionFailed =>
      'Sammlung konnte nicht gelöscht werden';

  @override
  String get libraryAddedToCollection => 'Zur Sammlung hinzugefügt';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente zur Sammlung hinzugefügt',
      one: '1 Element zur Sammlung hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'Sammlung gelöscht';

  @override
  String get libraryDeletedSuffix => ' gelöscht';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente gelöscht',
      one: 'Element gelöscht',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Elemente konnten nicht gelöscht werden',
      one: 'Element konnte nicht gelöscht werden',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'Zur Sammlung';

  @override
  String get libraryEmptyTitle => 'Deine Bibliothek ist leer';

  @override
  String get libraryEmptySubtitle =>
      'Füge dein erstes Buch oder deinen ersten Artikel hinzu';

  @override
  String get libraryNoResultsTitle => 'Keine Ergebnisse';

  @override
  String get libraryNoResultsSubtitle =>
      'Versuche eine andere Suche oder einen anderen Filter';

  @override
  String get libraryAddToCollectionTitle => 'Zur Sammlung hinzufügen';

  @override
  String get libraryFavourites => 'Favoriten';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Erstelle eine Sammlung für $count ausgewählte Elemente.',
      one: 'Erstelle eine Sammlung für 1 ausgewähltes Element.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'Name der neuen Sammlung';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Elemente löschen?',
      one: 'Dieses Element löschen?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Dies entfernt die Bibliothekselemente und deine Markierungen. Archivierte Lerndaten bleiben erhalten.',
      one:
          'Dies entfernt das Bibliothekselement und deine Markierungen. Archivierte Lerndaten bleiben erhalten.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'Sammlungen';

  @override
  String get librarySearchCollectionsHint => 'Sammlungen durchsuchen...';

  @override
  String get libraryNoCollectionsYet => 'Noch keine Sammlungen';

  @override
  String get libraryNoMatchingCollections => 'Keine passenden Sammlungen';

  @override
  String get libraryManualCollections => 'Manuelle Sammlungen';

  @override
  String get librarySites => 'Websites';

  @override
  String get libraryAuthors => 'Autoren';

  @override
  String libraryManageCollection(String name) {
    return '$name verwalten';
  }

  @override
  String get libraryOpenCollectionActions => 'Sammlungsaktionen öffnen';

  @override
  String get libraryManageCollectionTitle => 'Sammlung verwalten';

  @override
  String get libraryDeleteCollectionTitle => 'Sammlung löschen?';

  @override
  String get libraryDeleteCollectionButton => 'Sammlung löschen';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Bücher',
      one: '1 Buch',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
      one: '1 Artikel',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 Bücher/Artikel';

  @override
  String get libraryNoItemsInCollection => 'Keine Elemente in dieser Sammlung';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'Dies entfernt nur \"$name\". Bücher und Artikel bleiben in deiner Bibliothek.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return '$title aus Sammlung entfernen';
  }

  @override
  String get librarySourceArticle => 'Artikel';

  @override
  String get librarySourceBook => 'Buch';

  @override
  String get librarySourceComic => 'Comic';

  @override
  String get librarySourceNew => 'Neu';

  @override
  String get librarySourceDone => 'Fertig';

  @override
  String get librarySourceFinished => 'Abgeschlossen';

  @override
  String get librarySourceUntitled => 'Quelle ohne Titel';

  @override
  String get librarySourceOpenReader => 'Reader öffnen';

  @override
  String get librarySourceSelect => 'Quelle auswählen';

  @override
  String get librarySourceDeselect => 'Quelle abwählen';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent Prozent gelesen';
  }

  @override
  String get importAddToLibraryTitle => 'Zur Bibliothek hinzufügen';

  @override
  String get importUploadBook => 'Buch hochladen';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'Artikel speichern';

  @override
  String get importSaveArticleDescription =>
      'Web-URL für Offline-Lesen einfügen';

  @override
  String get importBeforeUploadingTitle => 'Vor dem Hochladen';

  @override
  String get importBookTermsBody =>
      'Lade nur Bücher, Comics und Dokumente hoch, die du in ReadFlex verwenden darfst.';

  @override
  String get importBookTermsConfirm =>
      'Ich bestätige, dass ich diese Datei hochladen darf.';

  @override
  String get importLegalPrefix => 'Mit dem Fortfahren akzeptierst du die ';

  @override
  String get importLegalAnd => ' und die ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'Bedingungen';

  @override
  String get importPrivacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'URL einfügen';

  @override
  String get importArticleHintClean =>
      'Erstellt einen bereinigten Artikel für Offline-Lesen.';

  @override
  String get importArticleHintSource => 'Behält den ursprünglichen Quelllink.';

  @override
  String get importArticleHintLibrary => 'Fügt ihn deiner Bibliothek hinzu.';

  @override
  String get importUploadingBook => 'Buch wird hochgeladen...';

  @override
  String get importFetchingArticle => 'Artikel wird abgerufen...';

  @override
  String get importSavingArticle => 'Offline-Kopie wird gespeichert...';

  @override
  String get importComicAdded => 'Comic hinzugefügt!';

  @override
  String get importBookAdded => 'Buch hinzugefügt!';

  @override
  String get importArticleSaved => 'Artikel gespeichert!';

  @override
  String get importTryAgain => 'Erneut versuchen';

  @override
  String get importArticleUrlRequired => 'Artikel-URL eingeben';

  @override
  String get importInvalidArticleUrl => 'Gültige Artikel-URL eingeben';

  @override
  String get importBookImportFailed => 'Buch konnte nicht importiert werden';

  @override
  String get importArticleSaveFailed =>
      'Artikel konnte nicht gespeichert werden';

  @override
  String get highlightAction => 'Markieren';

  @override
  String get highlightTitle => 'Markieren';

  @override
  String get highlightNoteHint => 'Notiz hinzufügen (optional)';

  @override
  String get highlightFailedToSave =>
      'Markierung konnte nicht gespeichert werden';

  @override
  String get highlightColorYellow => 'Gelb';

  @override
  String get highlightColorGreen => 'Grün';

  @override
  String get highlightColorBlue => 'Blau';

  @override
  String get highlightColorPink => 'Rosa';

  @override
  String get highlightColorPurple => 'Lila';

  @override
  String highlightColorSemantics(String color) {
    return 'Markierungsfarbe $color';
  }

  @override
  String get highlightSelectColor => 'Markierungsfarbe auswählen';

  @override
  String get readerFailedToLoadContent => 'Inhalt konnte nicht geladen werden';

  @override
  String get readerGoBack => 'Zurück';

  @override
  String get readerBookSearchUnavailable => 'Buchsuche ist nicht verfügbar';

  @override
  String get readerNotReady => 'Reader ist nicht bereit';

  @override
  String get readerHighlightSaved => 'Markierung gespeichert';

  @override
  String get readerHighlightRemoved => 'Markierung entfernt';

  @override
  String get readerHighlightSaveFailed =>
      'Markierung konnte nicht gespeichert werden';

  @override
  String get readerCommentUpdated => 'Kommentar aktualisiert';

  @override
  String get readerContents => 'Inhalt';

  @override
  String get readerChapters => 'Kapitel';

  @override
  String get readerBookmarks => 'Lesezeichen';

  @override
  String get readerHighlights => 'Markierungen';

  @override
  String get readerSearchChapters => 'Kapitel suchen';

  @override
  String get readerSearchBookmarks => 'Lesezeichen suchen';

  @override
  String get readerSearchHighlights => 'Markierungen suchen';

  @override
  String get readerNoBookmarksYet => 'Noch keine Lesezeichen';

  @override
  String get readerNoMatchingBookmarks => 'Keine passenden Lesezeichen';

  @override
  String get readerBookmarkedPage => 'Seite mit Lesezeichen';

  @override
  String get readerDeleteBookmark => 'Lesezeichen löschen';

  @override
  String get readerNoHighlightsYet => 'Noch keine Markierungen';

  @override
  String get readerNoMatchingHighlights => 'Keine passenden Markierungen';

  @override
  String get readerHighlightedText => 'Markierter Text';

  @override
  String get readerLocationUnavailable => 'Position nicht verfügbar';

  @override
  String get readerSearchInBook => 'Im Buch suchen';

  @override
  String get readerNoResultsFound => 'Keine Ergebnisse';

  @override
  String get readerRecentSearches => 'Letzte Suchanfragen';

  @override
  String get readerRemoveFromHistory => 'Aus Verlauf entfernen';

  @override
  String get readerSearchResult => 'Suchergebnis';

  @override
  String get readerNoMatchingChapters => 'Keine passenden Kapitel';

  @override
  String get readerNoChaptersFound => 'Keine Kapitel gefunden';

  @override
  String get readerSearchPrompt => 'Mindestens 2 Zeichen eingeben';

  @override
  String get readerSearchAction => 'Suchen';

  @override
  String get readerSearchFailed => 'Suche fehlgeschlagen';

  @override
  String get readerUntitledChapter => 'Kapitel ohne Titel';

  @override
  String readerPageNumber(int page) {
    return 'Seite $page';
  }

  @override
  String get readerAppearanceTitle => 'Darstellung';

  @override
  String get readerReset => 'Zurücksetzen';

  @override
  String get readerTheme => 'Design';

  @override
  String get readerFont => 'Schrift';

  @override
  String get readerFontSize => 'Textgröße';

  @override
  String get readerLineSpacing => 'Zeilenabstand';

  @override
  String get readerTextAlignment => 'Textausrichtung';

  @override
  String get readerPageMargins => 'Seitenränder';

  @override
  String get readerPageTurn => 'Seitenwechsel';

  @override
  String get readerAlignStart => 'Am Anfang ausrichten';

  @override
  String get readerJustifyText => 'Blocksatz';

  @override
  String get readerAlignEnd => 'Am Ende ausrichten';

  @override
  String get readerHorizontalPageTurn => 'Horizontaler Seitenwechsel';

  @override
  String get readerVerticalPageTurn => 'Vertikaler Seitenwechsel';

  @override
  String get readerResetTextSize => 'Textgröße zurücksetzen';

  @override
  String get readerTextSize => 'Textgröße';

  @override
  String get readerDecreaseTextSize => 'Text verkleinern';

  @override
  String get readerIncreaseTextSize => 'Text vergrößern';

  @override
  String get readerResetLineSpacing => 'Zeilenabstand zurücksetzen';

  @override
  String get readerDecreaseLineSpacing => 'Zeilenabstand verringern';

  @override
  String get readerIncreaseLineSpacing => 'Zeilenabstand erhöhen';

  @override
  String get readerResetPageMargins => 'Ränder zurücksetzen';

  @override
  String get readerDecreasePageMargins => 'Ränder verringern';

  @override
  String get readerIncreasePageMargins => 'Ränder erhöhen';

  @override
  String get readerThemeSnow => 'Schnee';

  @override
  String get readerThemePaper => 'Papier';

  @override
  String get readerThemeWarm => 'Warm';

  @override
  String get readerThemeMist => 'Graphit';

  @override
  String get readerThemeNight => 'Nacht';

  @override
  String get readerIncreaseBrightness => 'Helligkeit erhöhen';

  @override
  String get readerDecreaseBrightness => 'Helligkeit verringern';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'Systemhelligkeit: $label';
  }

  @override
  String get readerUseSystemBrightness => 'Systemhelligkeit verwenden';

  @override
  String get readerPageBookmarked => 'Seite als Lesezeichen gespeichert';

  @override
  String get readerOpenOriginalArticle => 'Originalartikel öffnen';

  @override
  String get readerBack => 'Zurück';

  @override
  String get readerFontAction => 'Schrift';

  @override
  String get readerPageTurnVertical => 'Seitenwechsel: Vertikal';

  @override
  String get readerPageTurnHorizontal => 'Seitenwechsel: Horizontal';

  @override
  String get readerRemoveBookmark => 'Lesezeichen entfernen';

  @override
  String get readerBookmark => 'Lesezeichen';

  @override
  String get readerEditComment => 'Kommentar bearbeiten';

  @override
  String get readerRemoveHighlight => 'Markierung entfernen';

  @override
  String get readerHighlightNoteTitle => 'Markierungsnotiz';

  @override
  String get readerEditNoteTitle => 'Notiz bearbeiten';

  @override
  String get readerCommentHint => 'Kommentar hinzufügen (optional)';

  @override
  String get readerSkip => 'Überspringen';
}
