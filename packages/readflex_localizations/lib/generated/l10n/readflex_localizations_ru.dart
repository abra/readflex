// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class ReadflexLocalizationsRu extends ReadflexLocalizations {
  ReadflexLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appSkip => 'Пропустить';

  @override
  String get appNext => 'Далее';

  @override
  String get appGetStarted => 'Начать';

  @override
  String get appInitializationFailed => 'Не удалось запустить приложение';

  @override
  String get appRetry => 'Повторить';

  @override
  String get appRetrying => 'Повторяем...';

  @override
  String get onboardingReadAnythingTitle => 'Читайте что угодно';

  @override
  String get onboardingReadAnythingDescription =>
      'Импортируйте книги и читайте комфортно в настраиваемом ридере.';

  @override
  String get onboardingHighlightSaveTitle => 'Выделяйте и сохраняйте';

  @override
  String get onboardingHighlightSaveDescription =>
      'Выделяйте текст, создавайте хайлайты и добавляйте заметки.';

  @override
  String get onboardingOrganizeLibraryTitle => 'Организуйте библиотеку';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'Храните книги и статьи в одном месте и возвращайтесь к месту чтения.';

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonRetry => 'Повторить';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonBack => 'Назад';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonCreate => 'Создать';

  @override
  String get commonContinue => 'Продолжить';

  @override
  String get commonSearch => 'Поиск';

  @override
  String get commonClearSearch => 'Очистить поиск';

  @override
  String get libraryTitle => 'Библиотека';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '1 элемент',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'офлайн';

  @override
  String get librarySearchHint => 'Поиск в библиотеке...';

  @override
  String get libraryFilterAll => 'Все';

  @override
  String get libraryFilterBooks => 'Книги';

  @override
  String get libraryFilterArticles => 'Статьи';

  @override
  String get libraryFilterComics => 'Комиксы';

  @override
  String get libraryFilterNew => 'Новые';

  @override
  String get libraryDisplayOptions => 'Настройки вида';

  @override
  String get libraryDisplayTitle => 'Вид';

  @override
  String get libraryDisplayView => 'Отображение';

  @override
  String get libraryDisplayAppearance => 'Оформление';

  @override
  String get libraryDisplayLanguage => 'Язык';

  @override
  String get libraryDisplayList => 'Список';

  @override
  String get libraryDisplayGrid => 'Сетка';

  @override
  String get libraryThemeSystem => 'Системная';

  @override
  String get libraryThemeSystemDescription => 'Следовать настройкам устройства';

  @override
  String get libraryThemeLight => 'Светлая';

  @override
  String get libraryThemeLightDescription => 'Использовать светлое оформление';

  @override
  String get libraryThemeDark => 'Темная';

  @override
  String get libraryThemeDarkDescription => 'Использовать темное оформление';

  @override
  String get libraryFailedToLoad => 'Не удалось загрузить библиотеку';

  @override
  String get libraryLoadCollectionsFailed => 'Не удалось загрузить коллекции';

  @override
  String get libraryUpdateCollectionFailed => 'Не удалось обновить коллекцию';

  @override
  String get libraryUpdateFavouritesFailed => 'Не удалось обновить избранное';

  @override
  String get libraryCollectionNameRequired => 'Введите название коллекции';

  @override
  String get libraryCreateCollectionFailed => 'Не удалось создать коллекцию';

  @override
  String get librarySaveCollectionFailed => 'Не удалось сохранить коллекцию';

  @override
  String get libraryDeleteCollectionFailed => 'Не удалось удалить коллекцию';

  @override
  String get libraryAddedToCollection => 'Добавлено в коллекцию';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента добавлены в коллекцию',
      many: '$count элементов добавлены в коллекцию',
      few: '$count элемента добавлены в коллекцию',
      one: '1 элемент добавлен в коллекцию',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'Коллекция удалена';

  @override
  String get libraryDeletedSuffix => ' удалено';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента удалены',
      many: '$count элементов удалены',
      few: '$count элемента удалены',
      one: 'Элемент удален',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Не удалось удалить элементы',
      one: 'Не удалось удалить элемент',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'В коллекцию';

  @override
  String get libraryEmptyTitle => 'Библиотека пуста';

  @override
  String get libraryEmptySubtitle => 'Добавьте первую книгу или статью';

  @override
  String get libraryNoResultsTitle => 'Ничего не найдено';

  @override
  String get libraryNoResultsSubtitle => 'Попробуйте другой поиск или фильтр';

  @override
  String get libraryAddToCollectionTitle => 'Добавить в коллекцию';

  @override
  String get libraryFavourites => 'Избранное';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Создайте коллекцию для $count выбранных элементов.',
      many: 'Создайте коллекцию для $count выбранных элементов.',
      few: 'Создайте коллекцию для $count выбранных элементов.',
      one: 'Создайте коллекцию для 1 выбранного элемента.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'Название новой коллекции';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Удалить $count элемента?',
      many: 'Удалить $count элементов?',
      few: 'Удалить $count элемента?',
      one: 'Удалить этот элемент?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Будут удалены элементы библиотеки и ваши хайлайты. Архивные учебные данные сохранятся.',
      one:
          'Будет удален элемент библиотеки и ваши хайлайты. Архивные учебные данные сохранятся.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'Коллекции';

  @override
  String get librarySearchCollectionsHint => 'Поиск коллекций...';

  @override
  String get libraryNoCollectionsYet => 'Коллекций пока нет';

  @override
  String get libraryNoMatchingCollections => 'Подходящих коллекций нет';

  @override
  String get libraryManualCollections => 'Пользовательские коллекции';

  @override
  String get librarySites => 'Сайты';

  @override
  String get libraryAuthors => 'Авторы';

  @override
  String libraryManageCollection(String name) {
    return 'Управлять $name';
  }

  @override
  String get libraryOpenCollectionActions => 'Открыть действия коллекции';

  @override
  String get libraryManageCollectionTitle => 'Управление коллекцией';

  @override
  String get libraryDeleteCollectionTitle => 'Удалить коллекцию?';

  @override
  String get libraryDeleteCollectionButton => 'Удалить коллекцию';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count книги',
      many: '$count книг',
      few: '$count книги',
      one: '1 книга',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count статьи',
      many: '$count статей',
      few: '$count статьи',
      one: '1 статья',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 книг/статей';

  @override
  String get libraryNoItemsInCollection => 'В этой коллекции нет элементов';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'Будет удалена только коллекция \"$name\". Книги и статьи останутся в библиотеке.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return 'Убрать $title из коллекции';
  }

  @override
  String get librarySourceArticle => 'Статья';

  @override
  String get librarySourceBook => 'Книга';

  @override
  String get librarySourceComic => 'Комикс';

  @override
  String get librarySourceNew => 'Новая';

  @override
  String get librarySourceDone => 'Готово';

  @override
  String get librarySourceFinished => 'Завершено';

  @override
  String get librarySourceUntitled => 'Источник без названия';

  @override
  String get librarySourceOpenReader => 'Открыть ридер';

  @override
  String get librarySourceSelect => 'Выбрать источник';

  @override
  String get librarySourceDeselect => 'Снять выбор';

  @override
  String librarySourcePercentRead(int percent) {
    return 'прочитано $percent процентов';
  }

  @override
  String get importAddToLibraryTitle => 'Добавить в библиотеку';

  @override
  String get importUploadBook => 'Загрузить книгу';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'Сохранить статью';

  @override
  String get importSaveArticleDescription => 'Вставьте URL для офлайн-чтения';

  @override
  String get importBeforeUploadingTitle => 'Перед загрузкой';

  @override
  String get importBookTermsBody =>
      'Загружайте только книги, комиксы и документы, которые вы имеете право использовать в ReadFlex.';

  @override
  String get importBookTermsConfirm =>
      'Подтверждаю, что имею право загрузить этот файл.';

  @override
  String get importLegalPrefix => 'Продолжая, вы принимаете ';

  @override
  String get importLegalAnd => ' и ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'Условия';

  @override
  String get importPrivacyPolicy => 'Политику конфиденциальности';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'Вставить URL';

  @override
  String get importArticleHintClean =>
      'Создает чистую статью для офлайн-чтения.';

  @override
  String get importArticleHintSource => 'Сохраняет ссылку на исходник.';

  @override
  String get importArticleHintLibrary => 'Добавляет статью в библиотеку.';

  @override
  String get importUploadingBook => 'Загружаем книгу...';

  @override
  String get importFetchingArticle => 'Получаем статью...';

  @override
  String get importSavingArticle => 'Сохраняем офлайн-копию...';

  @override
  String get importComicAdded => 'Комикс добавлен!';

  @override
  String get importBookAdded => 'Книга добавлена!';

  @override
  String get importArticleSaved => 'Статья сохранена!';

  @override
  String get importTryAgain => 'Повторить';

  @override
  String get importArticleUrlRequired => 'Введите URL статьи';

  @override
  String get importInvalidArticleUrl => 'Введите корректный URL статьи';

  @override
  String get importBookImportFailed => 'Не удалось импортировать книгу';

  @override
  String get importArticleSaveFailed => 'Не удалось сохранить статью';

  @override
  String get highlightAction => 'Хайлайт';

  @override
  String get highlightTitle => 'Хайлайт';

  @override
  String get highlightNoteHint => 'Добавить заметку (необязательно)';

  @override
  String get highlightFailedToSave => 'Не удалось сохранить хайлайт';

  @override
  String get highlightColorYellow => 'Желтый';

  @override
  String get highlightColorGreen => 'Зеленый';

  @override
  String get highlightColorBlue => 'Синий';

  @override
  String get highlightColorPink => 'Розовый';

  @override
  String get highlightColorPurple => 'Фиолетовый';

  @override
  String highlightColorSemantics(String color) {
    return '$color цвет хайлайта';
  }

  @override
  String get highlightSelectColor => 'Выбрать цвет хайлайта';

  @override
  String get readerFailedToLoadContent => 'Не удалось загрузить содержимое';

  @override
  String get readerGoBack => 'Назад';

  @override
  String get readerBookSearchUnavailable => 'Поиск по книге недоступен';

  @override
  String get readerNotReady => 'Ридер не готов';

  @override
  String get readerHighlightSaved => 'Хайлайт сохранен';

  @override
  String get readerHighlightRemoved => 'Хайлайт удален';

  @override
  String get readerHighlightSaveFailed => 'Не удалось сохранить хайлайт';

  @override
  String get readerCommentUpdated => 'Комментарий обновлен';

  @override
  String get readerContents => 'Содержание';

  @override
  String get readerChapters => 'Главы';

  @override
  String get readerBookmarks => 'Закладки';

  @override
  String get readerHighlights => 'Хайлайты';

  @override
  String get readerSearchChapters => 'Поиск глав';

  @override
  String get readerSearchBookmarks => 'Поиск закладок';

  @override
  String get readerSearchHighlights => 'Поиск хайлайтов';

  @override
  String get readerNoBookmarksYet => 'Закладок пока нет';

  @override
  String get readerNoMatchingBookmarks => 'Подходящих закладок нет';

  @override
  String get readerBookmarkedPage => 'Страница с закладкой';

  @override
  String get readerDeleteBookmark => 'Удалить закладку';

  @override
  String get readerNoHighlightsYet => 'Хайлайтов пока нет';

  @override
  String get readerNoMatchingHighlights => 'Подходящих хайлайтов нет';

  @override
  String get readerHighlightedText => 'Выделенный текст';

  @override
  String get readerLocationUnavailable => 'Переход недоступен';

  @override
  String get readerSearchInBook => 'Поиск по книге';

  @override
  String get readerNoResultsFound => 'Ничего не найдено';

  @override
  String get readerRecentSearches => 'Недавние запросы';

  @override
  String get readerRemoveFromHistory => 'Убрать из истории';

  @override
  String get readerSearchResult => 'Результат поиска';

  @override
  String get readerNoMatchingChapters => 'Подходящих глав нет';

  @override
  String get readerNoChaptersFound => 'Главы не найдены';

  @override
  String get readerSearchPrompt => 'Введите минимум 2 символа';

  @override
  String get readerSearchAction => 'Поиск';

  @override
  String get readerSearchFailed => 'Поиск не удался';

  @override
  String get readerUntitledChapter => 'Глава без названия';

  @override
  String readerPageNumber(int page) {
    return 'Страница $page';
  }

  @override
  String get readerAppearanceTitle => 'Оформление';

  @override
  String get readerReset => 'Сбросить';

  @override
  String get readerTheme => 'Тема';

  @override
  String get readerFont => 'Шрифт';

  @override
  String get readerFontSize => 'Размер текста';

  @override
  String get readerLineSpacing => 'Межстрочный интервал';

  @override
  String get readerTextAlignment => 'Выравнивание';

  @override
  String get readerPageMargins => 'Поля страницы';

  @override
  String get readerPageTurn => 'Листание';

  @override
  String get readerAlignStart => 'По началу';

  @override
  String get readerJustifyText => 'По ширине';

  @override
  String get readerAlignEnd => 'По концу';

  @override
  String get readerHorizontalPageTurn => 'Горизонтальное листание';

  @override
  String get readerVerticalPageTurn => 'Вертикальное листание';

  @override
  String get readerResetTextSize => 'Сбросить размер текста';

  @override
  String get readerTextSize => 'Размер текста';

  @override
  String get readerDecreaseTextSize => 'Уменьшить текст';

  @override
  String get readerIncreaseTextSize => 'Увеличить текст';

  @override
  String get readerResetLineSpacing => 'Сбросить интервал';

  @override
  String get readerDecreaseLineSpacing => 'Уменьшить интервал';

  @override
  String get readerIncreaseLineSpacing => 'Увеличить интервал';

  @override
  String get readerResetPageMargins => 'Сбросить поля';

  @override
  String get readerDecreasePageMargins => 'Уменьшить поля';

  @override
  String get readerIncreasePageMargins => 'Увеличить поля';

  @override
  String get readerThemeSnow => 'Снег';

  @override
  String get readerThemePaper => 'Бумага';

  @override
  String get readerThemeWarm => 'Теплая';

  @override
  String get readerThemeMist => 'Графит';

  @override
  String get readerThemeNight => 'Ночь';

  @override
  String get readerIncreaseBrightness => 'Увеличить яркость';

  @override
  String get readerDecreaseBrightness => 'Уменьшить яркость';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'Системная яркость: $label';
  }

  @override
  String get readerUseSystemBrightness => 'Использовать системную яркость';

  @override
  String get readerPageBookmarked => 'Страница добавлена в закладки';

  @override
  String get readerOpenOriginalArticle => 'Открыть исходную статью';

  @override
  String get readerBack => 'Назад';

  @override
  String get readerFontAction => 'Шрифт';

  @override
  String get readerPageTurnVertical => 'Листание: вертикальное';

  @override
  String get readerPageTurnHorizontal => 'Листание: горизонтальное';

  @override
  String get readerRemoveBookmark => 'Удалить закладку';

  @override
  String get readerBookmark => 'Закладка';

  @override
  String get readerEditComment => 'Редактировать комментарий';

  @override
  String get readerRemoveHighlight => 'Удалить хайлайт';

  @override
  String get readerHighlightNoteTitle => 'Заметка к хайлайту';

  @override
  String get readerEditNoteTitle => 'Редактировать заметку';

  @override
  String get readerCommentHint => 'Добавить комментарий (необязательно)';

  @override
  String get readerSkip => 'Пропустить';
}
