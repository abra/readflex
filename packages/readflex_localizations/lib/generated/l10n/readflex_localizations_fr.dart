// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class ReadflexLocalizationsFr extends ReadflexLocalizations {
  ReadflexLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appSkip => 'Ignorer';

  @override
  String get appNext => 'Suivant';

  @override
  String get appGetStarted => 'Commencer';

  @override
  String get appInitializationFailed => 'Échec de l\'initialisation';

  @override
  String get appRetry => 'Réessayer';

  @override
  String get appRetrying => 'Nouvelle tentative...';

  @override
  String get onboardingReadAnythingTitle => 'Lisez tout';

  @override
  String get onboardingReadAnythingDescription =>
      'Importez des livres et lisez confortablement avec un lecteur personnalisable.';

  @override
  String get onboardingHighlightSaveTitle => 'Surlignez et enregistrez';

  @override
  String get onboardingHighlightSaveDescription =>
      'Sélectionnez du texte pour créer des surlignages. Ajoutez des notes pour mieux comprendre.';

  @override
  String get onboardingOrganizeLibraryTitle => 'Organisez votre bibliothèque';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'Gardez livres et articles au même endroit et retrouvez votre progression.';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonClearSearch => 'Effacer la recherche';

  @override
  String get libraryTitle => 'Bibliothèque';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'hors ligne';

  @override
  String get librarySearchHint => 'Rechercher dans la bibliothèque...';

  @override
  String get libraryFilterAll => 'Tout';

  @override
  String get libraryFilterBooks => 'Livres';

  @override
  String get libraryFilterArticles => 'Articles';

  @override
  String get libraryFilterComics => 'BD';

  @override
  String get libraryFilterNew => 'Nouveau';

  @override
  String get libraryDisplayOptions => 'Options d\'affichage';

  @override
  String get libraryDisplayTitle => 'Affichage';

  @override
  String get libraryDisplayView => 'Vue';

  @override
  String get libraryDisplayAppearance => 'Apparence';

  @override
  String get libraryDisplayLanguage => 'Langue';

  @override
  String get libraryDisplayList => 'Liste';

  @override
  String get libraryDisplayGrid => 'Grille';

  @override
  String get libraryThemeSystem => 'Système';

  @override
  String get libraryThemeSystemDescription =>
      'Suivre le réglage de l\'appareil';

  @override
  String get libraryThemeLight => 'Clair';

  @override
  String get libraryThemeLightDescription => 'Utiliser l\'apparence claire';

  @override
  String get libraryThemeDark => 'Sombre';

  @override
  String get libraryThemeDarkDescription => 'Utiliser l\'apparence sombre';

  @override
  String get libraryFailedToLoad => 'Impossible de charger la bibliothèque';

  @override
  String get libraryLoadCollectionsFailed =>
      'Impossible de charger les collections';

  @override
  String get libraryUpdateCollectionFailed =>
      'Impossible de mettre à jour la collection';

  @override
  String get libraryUpdateFavouritesFailed =>
      'Impossible de mettre à jour les favoris';

  @override
  String get libraryCollectionNameRequired =>
      'Le nom de la collection est obligatoire';

  @override
  String get libraryCreateCollectionFailed =>
      'Impossible de créer la collection';

  @override
  String get librarySaveCollectionFailed =>
      'Impossible d\'enregistrer la collection';

  @override
  String get libraryDeleteCollectionFailed =>
      'Impossible de supprimer la collection';

  @override
  String get libraryAddedToCollection => 'Ajouté à la collection';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ajoutés à la collection',
      one: '1 élément ajouté à la collection',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'Collection supprimée';

  @override
  String get libraryDeletedSuffix => ' supprimé';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments supprimés',
      one: 'Élément supprimé',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Impossible de supprimer les éléments',
      one: 'Impossible de supprimer l\'élément',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'Ajouter à une collection';

  @override
  String get libraryEmptyTitle => 'Votre bibliothèque est vide';

  @override
  String get libraryEmptySubtitle => 'Ajoutez votre premier livre ou article';

  @override
  String get libraryNoResultsTitle => 'Aucun résultat';

  @override
  String get libraryNoResultsSubtitle =>
      'Essayez une autre recherche ou un autre filtre';

  @override
  String get libraryAddToCollectionTitle => 'Ajouter à une collection';

  @override
  String get libraryFavourites => 'Favoris';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Créez une collection pour $count éléments sélectionnés.',
      one: 'Créez une collection pour 1 élément sélectionné.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'Nom de la nouvelle collection';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count éléments ?',
      one: 'Supprimer cet élément ?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Cela supprime les éléments de la bibliothèque et vos surlignages. Les données d\'apprentissage archivées sont conservées.',
      one:
          'Cela supprime l\'élément de la bibliothèque et vos surlignages. Les données d\'apprentissage archivées sont conservées.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'Collections';

  @override
  String get librarySearchCollectionsHint => 'Rechercher des collections...';

  @override
  String get libraryNoCollectionsYet => 'Aucune collection pour le moment';

  @override
  String get libraryNoMatchingCollections => 'Aucune collection correspondante';

  @override
  String get libraryManualCollections => 'Collections manuelles';

  @override
  String get librarySites => 'Sites';

  @override
  String get libraryAuthors => 'Auteurs';

  @override
  String libraryManageCollection(String name) {
    return 'Gérer $name';
  }

  @override
  String get libraryOpenCollectionActions => 'Ouvrir les actions de collection';

  @override
  String get libraryManageCollectionTitle => 'Gérer la collection';

  @override
  String get libraryDeleteCollectionTitle => 'Supprimer la collection ?';

  @override
  String get libraryDeleteCollectionButton => 'Supprimer la collection';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livres',
      one: '1 livre',
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
  String get libraryEmptySourceCount => '0 livre/article';

  @override
  String get libraryNoItemsInCollection =>
      'Aucun élément dans cette collection';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'Cela supprime uniquement \"$name\". Les livres et articles restent dans votre bibliothèque.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return 'Retirer $title de la collection';
  }

  @override
  String get librarySourceArticle => 'Article';

  @override
  String get librarySourceBook => 'Livre';

  @override
  String get librarySourceComic => 'BD';

  @override
  String get librarySourceNew => 'Nouveau';

  @override
  String get librarySourceDone => 'Terminé';

  @override
  String get librarySourceFinished => 'Terminé';

  @override
  String get librarySourceUntitled => 'Source sans titre';

  @override
  String get librarySourceOpenReader => 'Ouvrir le lecteur';

  @override
  String get librarySourceSelect => 'Sélectionner la source';

  @override
  String get librarySourceDeselect => 'Désélectionner la source';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent pour cent lu';
  }

  @override
  String get importAddToLibraryTitle => 'Ajouter à la bibliothèque';

  @override
  String get importUploadBook => 'Importer un livre';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'Enregistrer l\'article';

  @override
  String get importSaveArticleDescription =>
      'Collez une URL web pour lire hors ligne';

  @override
  String get importBeforeUploadingTitle => 'Avant l\'import';

  @override
  String get importBookTermsBody =>
      'Importez uniquement des livres, BD et documents que vous avez le droit d\'utiliser dans ReadFlex.';

  @override
  String get importBookTermsConfirm =>
      'Je confirme avoir le droit d\'importer ce fichier.';

  @override
  String get importLegalPrefix => 'En continuant, vous acceptez les ';

  @override
  String get importLegalAnd => ' et la ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'Conditions';

  @override
  String get importPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'Coller l\'URL';

  @override
  String get importArticleHintClean =>
      'Crée un article propre pour la lecture hors ligne.';

  @override
  String get importArticleHintSource => 'Conserve le lien source original.';

  @override
  String get importArticleHintLibrary => 'L\'ajoute à votre bibliothèque.';

  @override
  String get importUploadingBook => 'Import du livre...';

  @override
  String get importFetchingArticle => 'Récupération de l\'article...';

  @override
  String get importSavingArticle => 'Enregistrement de la copie hors ligne...';

  @override
  String get importComicAdded => 'BD ajoutée !';

  @override
  String get importBookAdded => 'Livre ajouté !';

  @override
  String get importArticleSaved => 'Article enregistré !';

  @override
  String get importTryAgain => 'Réessayer';

  @override
  String get importArticleUrlRequired => 'Saisissez l\'URL de l\'article';

  @override
  String get importInvalidArticleUrl => 'Saisissez une URL d\'article valide';

  @override
  String get importBookImportFailed => 'Impossible d\'importer le livre';

  @override
  String get importArticleSaveFailed => 'Impossible d\'enregistrer l\'article';

  @override
  String get highlightAction => 'Surligner';

  @override
  String get highlightTitle => 'Surligner';

  @override
  String get highlightNoteHint => 'Ajouter une note (facultatif)';

  @override
  String get highlightFailedToSave => 'Impossible d\'enregistrer le surlignage';

  @override
  String get highlightColorYellow => 'Jaune';

  @override
  String get highlightColorGreen => 'Vert';

  @override
  String get highlightColorBlue => 'Bleu';

  @override
  String get highlightColorPink => 'Rose';

  @override
  String get highlightColorPurple => 'Violet';

  @override
  String highlightColorSemantics(String color) {
    return 'Couleur de surlignage $color';
  }

  @override
  String get highlightSelectColor => 'Choisir la couleur du surlignage';

  @override
  String get readerFailedToLoadContent => 'Impossible de charger le contenu';

  @override
  String get readerGoBack => 'Retour';

  @override
  String get readerBookSearchUnavailable =>
      'Recherche indisponible dans ce livre';

  @override
  String get readerNotReady => 'Le lecteur n\'est pas prêt';

  @override
  String get readerHighlightSaved => 'Surlignage enregistré';

  @override
  String get readerHighlightRemoved => 'Surlignage supprimé';

  @override
  String get readerHighlightSaveFailed =>
      'Impossible d\'enregistrer le surlignage';

  @override
  String get readerCommentUpdated => 'Commentaire mis à jour';

  @override
  String get readerContents => 'Sommaire';

  @override
  String get readerChapters => 'Chapitres';

  @override
  String get readerBookmarks => 'Signets';

  @override
  String get readerHighlights => 'Surlignages';

  @override
  String get readerSearchChapters => 'Rechercher des chapitres';

  @override
  String get readerSearchBookmarks => 'Rechercher des signets';

  @override
  String get readerSearchHighlights => 'Rechercher des surlignages';

  @override
  String get readerNoBookmarksYet => 'Aucun signet pour le moment';

  @override
  String get readerNoMatchingBookmarks => 'Aucun signet correspondant';

  @override
  String get readerBookmarkedPage => 'Page avec signet';

  @override
  String get readerDeleteBookmark => 'Supprimer le signet';

  @override
  String get readerNoHighlightsYet => 'Aucun surlignage pour le moment';

  @override
  String get readerNoMatchingHighlights => 'Aucun surlignage correspondant';

  @override
  String get readerHighlightedText => 'Texte surligné';

  @override
  String get readerLocationUnavailable => 'Emplacement indisponible';

  @override
  String get readerSearchInBook => 'Rechercher dans le livre';

  @override
  String get readerNoResultsFound => 'Aucun résultat';

  @override
  String get readerRecentSearches => 'Recherches récentes';

  @override
  String get readerRemoveFromHistory => 'Retirer de l\'historique';

  @override
  String get readerSearchResult => 'Résultat de recherche';

  @override
  String get readerNoMatchingChapters => 'Aucun chapitre correspondant';

  @override
  String get readerNoChaptersFound => 'Aucun chapitre trouvé';

  @override
  String get readerSearchPrompt => 'Saisissez au moins 2 caractères';

  @override
  String get readerSearchAction => 'Rechercher';

  @override
  String get readerSearchFailed => 'La recherche a échoué';

  @override
  String get readerUntitledChapter => 'Chapitre sans titre';

  @override
  String readerPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get readerAppearanceTitle => 'Apparence';

  @override
  String get readerReset => 'Réinitialiser';

  @override
  String get readerTheme => 'Thème';

  @override
  String get readerFont => 'Police';

  @override
  String get readerFontSize => 'Taille du texte';

  @override
  String get readerLineSpacing => 'Interligne';

  @override
  String get readerTextAlignment => 'Alignement du texte';

  @override
  String get readerPageMargins => 'Marges';

  @override
  String get readerPageTurn => 'Changement de page';

  @override
  String get readerAlignStart => 'Aligner au début';

  @override
  String get readerJustifyText => 'Justifier le texte';

  @override
  String get readerAlignEnd => 'Aligner à la fin';

  @override
  String get readerHorizontalPageTurn => 'Changement horizontal';

  @override
  String get readerVerticalPageTurn => 'Changement vertical';

  @override
  String get readerResetTextSize => 'Réinitialiser la taille';

  @override
  String get readerTextSize => 'Taille du texte';

  @override
  String get readerDecreaseTextSize => 'Réduire le texte';

  @override
  String get readerIncreaseTextSize => 'Agrandir le texte';

  @override
  String get readerResetLineSpacing => 'Réinitialiser l\'interligne';

  @override
  String get readerDecreaseLineSpacing => 'Réduire l\'interligne';

  @override
  String get readerIncreaseLineSpacing => 'Augmenter l\'interligne';

  @override
  String get readerResetPageMargins => 'Réinitialiser les marges';

  @override
  String get readerDecreasePageMargins => 'Réduire les marges';

  @override
  String get readerIncreasePageMargins => 'Augmenter les marges';

  @override
  String get readerThemeSnow => 'Neige';

  @override
  String get readerThemePaper => 'Papier';

  @override
  String get readerThemeWarm => 'Chaud';

  @override
  String get readerThemeMist => 'Graphite';

  @override
  String get readerThemeNight => 'Nuit';

  @override
  String get readerIncreaseBrightness => 'Augmenter la luminosité';

  @override
  String get readerDecreaseBrightness => 'Réduire la luminosité';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'Luminosité système : $label';
  }

  @override
  String get readerUseSystemBrightness => 'Utiliser la luminosité système';

  @override
  String get readerPageBookmarked => 'Page ajoutée aux signets';

  @override
  String get readerOpenOriginalArticle => 'Ouvrir l\'article original';

  @override
  String get readerBack => 'Retour';

  @override
  String get readerFontAction => 'Police';

  @override
  String get readerPageTurnVertical => 'Changement de page : vertical';

  @override
  String get readerPageTurnHorizontal => 'Changement de page : horizontal';

  @override
  String get readerRemoveBookmark => 'Retirer le signet';

  @override
  String get readerBookmark => 'Signet';

  @override
  String get readerEditComment => 'Modifier le commentaire';

  @override
  String get readerRemoveHighlight => 'Retirer le surlignage';

  @override
  String get readerHighlightNoteTitle => 'Note du surlignage';

  @override
  String get readerEditNoteTitle => 'Modifier la note';

  @override
  String get readerCommentHint => 'Ajouter un commentaire (facultatif)';

  @override
  String get readerSkip => 'Ignorer';
}
