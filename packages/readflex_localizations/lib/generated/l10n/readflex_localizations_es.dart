// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class ReadflexLocalizationsEs extends ReadflexLocalizations {
  ReadflexLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appSkip => 'Omitir';

  @override
  String get appNext => 'Siguiente';

  @override
  String get appGetStarted => 'Empezar';

  @override
  String get appInitializationFailed => 'Error al iniciar';

  @override
  String get appRetry => 'Reintentar';

  @override
  String get appRetrying => 'Reintentando...';

  @override
  String get onboardingReadAnythingTitle => 'Lee cualquier cosa';

  @override
  String get onboardingReadAnythingDescription =>
      'Importa libros y lee cómodamente con un lector personalizable.';

  @override
  String get onboardingHighlightSaveTitle => 'Resalta y guarda';

  @override
  String get onboardingHighlightSaveDescription =>
      'Selecciona texto para crear resaltados. Añade notas para entender mejor.';

  @override
  String get onboardingOrganizeLibraryTitle => 'Organiza tu biblioteca';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'Mantén libros y artículos en un solo lugar y vuelve a tu progreso de lectura.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonCreate => 'Crear';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonSearch => 'Buscar';

  @override
  String get commonClearSearch => 'Borrar búsqueda';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos',
      one: '1 elemento',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'sin conexión';

  @override
  String get librarySearchHint => 'Buscar en la biblioteca...';

  @override
  String get libraryFilterAll => 'Todo';

  @override
  String get libraryFilterBooks => 'Libros';

  @override
  String get libraryFilterArticles => 'Artículos';

  @override
  String get libraryFilterComics => 'Cómics';

  @override
  String get libraryFilterNew => 'Nuevo';

  @override
  String get libraryDisplayOptions => 'Opciones de vista';

  @override
  String get libraryDisplayTitle => 'Vista';

  @override
  String get libraryDisplayView => 'Visualización';

  @override
  String get libraryDisplayAppearance => 'Apariencia';

  @override
  String get libraryDisplayLanguage => 'Idioma';

  @override
  String get libraryDisplayList => 'Lista';

  @override
  String get libraryDisplayGrid => 'Cuadrícula';

  @override
  String get libraryThemeSystem => 'Sistema';

  @override
  String get libraryThemeSystemDescription => 'Seguir ajustes del dispositivo';

  @override
  String get libraryThemeLight => 'Claro';

  @override
  String get libraryThemeLightDescription => 'Usar apariencia clara';

  @override
  String get libraryThemeDark => 'Oscuro';

  @override
  String get libraryThemeDarkDescription => 'Usar apariencia oscura';

  @override
  String get libraryFailedToLoad => 'No se pudo cargar la biblioteca';

  @override
  String get libraryLoadCollectionsFailed =>
      'No se pudieron cargar las colecciones';

  @override
  String get libraryUpdateCollectionFailed =>
      'No se pudo actualizar la colección';

  @override
  String get libraryUpdateFavouritesFailed =>
      'No se pudieron actualizar los favoritos';

  @override
  String get libraryCollectionNameRequired =>
      'El nombre de la colección es obligatorio';

  @override
  String get libraryCreateCollectionFailed => 'No se pudo crear la colección';

  @override
  String get librarySaveCollectionFailed => 'No se pudo guardar la colección';

  @override
  String get libraryDeleteCollectionFailed =>
      'No se pudo eliminar la colección';

  @override
  String get libraryAddedToCollection => 'Añadido a la colección';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos añadidos a la colección',
      one: '1 elemento añadido a la colección',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'Colección eliminada';

  @override
  String get libraryDeletedSuffix => ' eliminado';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementos eliminados',
      one: 'Elemento eliminado',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron eliminar los elementos',
      one: 'No se pudo eliminar el elemento',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'Añadir a colección';

  @override
  String get libraryEmptyTitle => 'Tu biblioteca está vacía';

  @override
  String get libraryEmptySubtitle => 'Añade tu primer libro o artículo';

  @override
  String get libraryNoResultsTitle => 'No se encontraron resultados';

  @override
  String get libraryNoResultsSubtitle => 'Prueba otra búsqueda o filtro';

  @override
  String get libraryAddToCollectionTitle => 'Añadir a colección';

  @override
  String get libraryFavourites => 'Favoritos';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crea una colección para $count elementos seleccionados.',
      one: 'Crea una colección para 1 elemento seleccionado.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'Nombre de la nueva colección';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¿Eliminar $count elementos?',
      one: '¿Eliminar este elemento?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Esto elimina los elementos de la biblioteca y tus resaltados. Los datos de aprendizaje archivados se conservan.',
      one:
          'Esto elimina el elemento de la biblioteca y tus resaltados. Los datos de aprendizaje archivados se conservan.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'Colecciones';

  @override
  String get librarySearchCollectionsHint => 'Buscar colecciones...';

  @override
  String get libraryNoCollectionsYet => 'Aún no hay colecciones';

  @override
  String get libraryNoMatchingCollections => 'No hay colecciones coincidentes';

  @override
  String get libraryManualCollections => 'Colecciones manuales';

  @override
  String get librarySites => 'Sitios';

  @override
  String get libraryAuthors => 'Autores';

  @override
  String libraryManageCollection(String name) {
    return 'Gestionar $name';
  }

  @override
  String get libraryOpenCollectionActions => 'Abrir acciones de colección';

  @override
  String get libraryManageCollectionTitle => 'Gestionar colección';

  @override
  String get libraryDeleteCollectionTitle => '¿Eliminar colección?';

  @override
  String get libraryDeleteCollectionButton => 'Eliminar colección';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libros',
      one: '1 libro',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artículos',
      one: '1 artículo',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 libros/artículos';

  @override
  String get libraryNoItemsInCollection => 'No hay elementos en esta colección';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'Esto elimina solo \"$name\". Los libros y artículos permanecen en tu biblioteca.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return 'Quitar $title de la colección';
  }

  @override
  String get librarySourceArticle => 'Artículo';

  @override
  String get librarySourceBook => 'Libro';

  @override
  String get librarySourceComic => 'Cómic';

  @override
  String get librarySourceNew => 'Nuevo';

  @override
  String get librarySourceDone => 'Listo';

  @override
  String get librarySourceFinished => 'Terminado';

  @override
  String get librarySourceUntitled => 'Fuente sin título';

  @override
  String get librarySourceOpenReader => 'Abrir lector';

  @override
  String get librarySourceSelect => 'Seleccionar fuente';

  @override
  String get librarySourceDeselect => 'Deseleccionar fuente';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent por ciento leído';
  }

  @override
  String get importAddToLibraryTitle => 'Añadir a biblioteca';

  @override
  String get importUploadBook => 'Subir libro';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'Guardar artículo';

  @override
  String get importSaveArticleDescription =>
      'Pega una URL web para leer sin conexión';

  @override
  String get importBeforeUploadingTitle => 'Antes de subir';

  @override
  String get importBookTermsBody =>
      'Sube solo libros, cómics y documentos que tengas derecho a usar en ReadFlex.';

  @override
  String get importBookTermsConfirm =>
      'Confirmo que tengo derecho a subir este archivo.';

  @override
  String get importLegalPrefix => 'Al continuar, aceptas los ';

  @override
  String get importLegalAnd => ' y la ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'Términos';

  @override
  String get importPrivacyPolicy => 'Política de privacidad';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'Pegar URL';

  @override
  String get importArticleHintClean =>
      'Crea un artículo limpio para leer sin conexión.';

  @override
  String get importArticleHintSource => 'Conserva el enlace original.';

  @override
  String get importArticleHintLibrary => 'Lo añade a tu biblioteca.';

  @override
  String get importUploadingBook => 'Subiendo libro...';

  @override
  String get importFetchingArticle => 'Obteniendo artículo...';

  @override
  String get importSavingArticle => 'Guardando copia sin conexión...';

  @override
  String get importComicAdded => '¡Cómic añadido!';

  @override
  String get importBookAdded => '¡Libro añadido!';

  @override
  String get importArticleSaved => '¡Artículo guardado!';

  @override
  String get importTryAgain => 'Intentar de nuevo';

  @override
  String get importArticleUrlRequired => 'Introduce la URL del artículo';

  @override
  String get importInvalidArticleUrl => 'Introduce una URL de artículo válida';

  @override
  String get importBookImportFailed => 'No se pudo importar el libro';

  @override
  String get importArticleSaveFailed => 'No se pudo guardar el artículo';

  @override
  String get highlightAction => 'Resaltar';

  @override
  String get highlightTitle => 'Resaltar';

  @override
  String get highlightNoteHint => 'Añadir nota (opcional)';

  @override
  String get highlightFailedToSave => 'No se pudo guardar el resaltado';

  @override
  String get highlightColorYellow => 'Amarillo';

  @override
  String get highlightColorGreen => 'Verde';

  @override
  String get highlightColorBlue => 'Azul';

  @override
  String get highlightColorPink => 'Rosa';

  @override
  String get highlightColorPurple => 'Morado';

  @override
  String highlightColorSemantics(String color) {
    return 'Color de resaltado $color';
  }

  @override
  String get highlightSelectColor => 'Seleccionar color de resaltado';

  @override
  String get readerFailedToLoadContent => 'No se pudo cargar el contenido';

  @override
  String get readerGoBack => 'Volver';

  @override
  String get readerBookSearchUnavailable =>
      'La búsqueda en el libro no está disponible';

  @override
  String get readerNotReady => 'El lector no está listo';

  @override
  String get readerHighlightSaved => 'Resaltado guardado';

  @override
  String get readerHighlightRemoved => 'Resaltado eliminado';

  @override
  String get readerHighlightSaveFailed => 'No se pudo guardar el resaltado';

  @override
  String get readerCommentUpdated => 'Comentario actualizado';

  @override
  String get readerContents => 'Contenido';

  @override
  String get readerChapters => 'Capítulos';

  @override
  String get readerBookmarks => 'Marcadores';

  @override
  String get readerHighlights => 'Resaltados';

  @override
  String get readerSearchChapters => 'Buscar capítulos';

  @override
  String get readerSearchBookmarks => 'Buscar marcadores';

  @override
  String get readerSearchHighlights => 'Buscar resaltados';

  @override
  String get readerNoBookmarksYet => 'Aún no hay marcadores';

  @override
  String get readerNoMatchingBookmarks => 'No hay marcadores coincidentes';

  @override
  String get readerBookmarkedPage => 'Página marcada';

  @override
  String get readerDeleteBookmark => 'Eliminar marcador';

  @override
  String get readerNoHighlightsYet => 'Aún no hay resaltados';

  @override
  String get readerNoMatchingHighlights => 'No hay resaltados coincidentes';

  @override
  String get readerHighlightedText => 'Texto resaltado';

  @override
  String get readerLocationUnavailable => 'Ubicación no disponible';

  @override
  String get readerSearchInBook => 'Buscar en el libro';

  @override
  String get readerNoResultsFound => 'No se encontraron resultados';

  @override
  String get readerRecentSearches => 'Búsquedas recientes';

  @override
  String get readerRemoveFromHistory => 'Quitar del historial';

  @override
  String get readerSearchResult => 'Resultado de búsqueda';

  @override
  String get readerNoMatchingChapters => 'No hay capítulos coincidentes';

  @override
  String get readerNoChaptersFound => 'No se encontraron capítulos';

  @override
  String get readerSearchPrompt => 'Escribe al menos 2 caracteres';

  @override
  String get readerSearchAction => 'Buscar';

  @override
  String get readerSearchFailed => 'La búsqueda falló';

  @override
  String get readerUntitledChapter => 'Capítulo sin título';

  @override
  String readerPageNumber(int page) {
    return 'Página $page';
  }

  @override
  String get readerAppearanceTitle => 'Apariencia';

  @override
  String get readerReset => 'Restablecer';

  @override
  String get readerTheme => 'Tema';

  @override
  String get readerFont => 'Fuente';

  @override
  String get readerFontSize => 'Tamaño de texto';

  @override
  String get readerLineSpacing => 'Interlineado';

  @override
  String get readerTextAlignment => 'Alineación del texto';

  @override
  String get readerPageMargins => 'Márgenes';

  @override
  String get readerPageTurn => 'Cambio de página';

  @override
  String get readerAlignStart => 'Alinear al inicio';

  @override
  String get readerJustifyText => 'Justificar texto';

  @override
  String get readerAlignEnd => 'Alinear al final';

  @override
  String get readerHorizontalPageTurn => 'Cambio horizontal';

  @override
  String get readerVerticalPageTurn => 'Cambio vertical';

  @override
  String get readerResetTextSize => 'Restablecer tamaño';

  @override
  String get readerTextSize => 'Tamaño de texto';

  @override
  String get readerDecreaseTextSize => 'Reducir texto';

  @override
  String get readerIncreaseTextSize => 'Aumentar texto';

  @override
  String get readerResetLineSpacing => 'Restablecer interlineado';

  @override
  String get readerDecreaseLineSpacing => 'Reducir interlineado';

  @override
  String get readerIncreaseLineSpacing => 'Aumentar interlineado';

  @override
  String get readerResetPageMargins => 'Restablecer márgenes';

  @override
  String get readerDecreasePageMargins => 'Reducir márgenes';

  @override
  String get readerIncreasePageMargins => 'Aumentar márgenes';

  @override
  String get readerThemeSnow => 'Nieve';

  @override
  String get readerThemePaper => 'Papel';

  @override
  String get readerThemeWarm => 'Cálido';

  @override
  String get readerThemeMist => 'Grafito';

  @override
  String get readerThemeNight => 'Noche';

  @override
  String get readerIncreaseBrightness => 'Aumentar brillo';

  @override
  String get readerDecreaseBrightness => 'Reducir brillo';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'Usando brillo del sistema: $label';
  }

  @override
  String get readerUseSystemBrightness => 'Usar brillo del sistema';

  @override
  String get readerPageBookmarked => 'Página marcada';

  @override
  String get readerOpenOriginalArticle => 'Abrir artículo original';

  @override
  String get readerBack => 'Atrás';

  @override
  String get readerFontAction => 'Fuente';

  @override
  String get readerPageTurnVertical => 'Cambio de página: vertical';

  @override
  String get readerPageTurnHorizontal => 'Cambio de página: horizontal';

  @override
  String get readerRemoveBookmark => 'Quitar marcador';

  @override
  String get readerBookmark => 'Marcador';

  @override
  String get readerEditComment => 'Editar comentario';

  @override
  String get readerRemoveHighlight => 'Quitar resaltado';

  @override
  String get readerHighlightNoteTitle => 'Nota del resaltado';

  @override
  String get readerEditNoteTitle => 'Editar nota';

  @override
  String get readerCommentHint => 'Añadir comentario (opcional)';

  @override
  String get readerSkip => 'Omitir';
}
