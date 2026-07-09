// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class ReadflexLocalizationsPt extends ReadflexLocalizations {
  ReadflexLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appSkip => 'Pular';

  @override
  String get appNext => 'Avançar';

  @override
  String get appGetStarted => 'Começar';

  @override
  String get appInitializationFailed => 'Falha ao iniciar';

  @override
  String get appRetry => 'Tentar novamente';

  @override
  String get appRetrying => 'Tentando novamente...';

  @override
  String get onboardingReadAnythingTitle => 'Leia qualquer coisa';

  @override
  String get onboardingReadAnythingDescription =>
      'Importe livros e leia com conforto em um leitor personalizável.';

  @override
  String get onboardingHighlightSaveTitle => 'Destaque e salve';

  @override
  String get onboardingHighlightSaveDescription =>
      'Selecione texto para criar destaques. Adicione notas para entender melhor.';

  @override
  String get onboardingOrganizeLibraryTitle => 'Organize sua biblioteca';

  @override
  String get onboardingOrganizeLibraryDescription =>
      'Mantenha livros e artigos em um só lugar e retome seu progresso de leitura.';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonDone => 'Concluído';

  @override
  String get commonCreate => 'Criar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonSearch => 'Pesquisar';

  @override
  String get commonClearSearch => 'Limpar pesquisa';

  @override
  String get libraryTitle => 'Biblioteca';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'offline';

  @override
  String get librarySearchHint => 'Pesquisar na biblioteca...';

  @override
  String get libraryFilterAll => 'Tudo';

  @override
  String get libraryFilterBooks => 'Livros';

  @override
  String get libraryFilterArticles => 'Artigos';

  @override
  String get libraryFilterComics => 'Quadrinhos';

  @override
  String get libraryFilterNew => 'Novo';

  @override
  String get libraryDisplayOptions => 'Opções de exibição';

  @override
  String get libraryDisplayTitle => 'Exibição';

  @override
  String get libraryDisplayView => 'Visualização';

  @override
  String get libraryDisplayAppearance => 'Aparência';

  @override
  String get libraryDisplayLanguage => 'Idioma';

  @override
  String get libraryDisplayList => 'Lista';

  @override
  String get libraryDisplayGrid => 'Grade';

  @override
  String get libraryThemeSystem => 'Sistema';

  @override
  String get libraryThemeSystemDescription =>
      'Seguir configuração do dispositivo';

  @override
  String get libraryThemeLight => 'Claro';

  @override
  String get libraryThemeLightDescription => 'Usar aparência clara';

  @override
  String get libraryThemeDark => 'Escuro';

  @override
  String get libraryThemeDarkDescription => 'Usar aparência escura';

  @override
  String get libraryFailedToLoad => 'Não foi possível carregar a biblioteca';

  @override
  String get libraryLoadCollectionsFailed =>
      'Não foi possível carregar as coleções';

  @override
  String get libraryUpdateCollectionFailed =>
      'Não foi possível atualizar a coleção';

  @override
  String get libraryUpdateFavouritesFailed =>
      'Não foi possível atualizar os favoritos';

  @override
  String get libraryCollectionNameRequired => 'O nome da coleção é obrigatório';

  @override
  String get libraryCreateCollectionFailed =>
      'Não foi possível criar a coleção';

  @override
  String get librarySaveCollectionFailed => 'Não foi possível salvar a coleção';

  @override
  String get libraryDeleteCollectionFailed =>
      'Não foi possível excluir a coleção';

  @override
  String get libraryAddedToCollection => 'Adicionado à coleção';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens adicionados à coleção',
      one: '1 item adicionado à coleção',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'Coleção excluída';

  @override
  String get libraryDeletedSuffix => ' excluído';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count itens excluídos',
      one: 'Item excluído',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Não foi possível excluir os itens',
      one: 'Não foi possível excluir o item',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'Adicionar à coleção';

  @override
  String get libraryEmptyTitle => 'Sua biblioteca está vazia';

  @override
  String get libraryEmptySubtitle => 'Adicione seu primeiro livro ou artigo';

  @override
  String get libraryNoResultsTitle => 'Nenhum resultado encontrado';

  @override
  String get libraryNoResultsSubtitle => 'Tente outra busca ou filtro';

  @override
  String get libraryAddToCollectionTitle => 'Adicionar à coleção';

  @override
  String get libraryFavourites => 'Favoritos';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crie uma coleção para $count itens selecionados.',
      one: 'Crie uma coleção para 1 item selecionado.',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => 'Nome da nova coleção';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Excluir $count itens?',
      one: 'Excluir este item?',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Isso remove os itens da biblioteca e seus destaques. Dados de aprendizado arquivados são mantidos.',
      one:
          'Isso remove o item da biblioteca e seus destaques. Dados de aprendizado arquivados são mantidos.',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'Coleções';

  @override
  String get librarySearchCollectionsHint => 'Pesquisar coleções...';

  @override
  String get libraryNoCollectionsYet => 'Ainda não há coleções';

  @override
  String get libraryNoMatchingCollections => 'Nenhuma coleção encontrada';

  @override
  String get libraryManualCollections => 'Coleções manuais';

  @override
  String get librarySites => 'Sites';

  @override
  String get libraryAuthors => 'Autores';

  @override
  String libraryManageCollection(String name) {
    return 'Gerenciar $name';
  }

  @override
  String get libraryOpenCollectionActions => 'Abrir ações da coleção';

  @override
  String get libraryManageCollectionTitle => 'Gerenciar coleção';

  @override
  String get libraryDeleteCollectionTitle => 'Excluir coleção?';

  @override
  String get libraryDeleteCollectionButton => 'Excluir coleção';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livros',
      one: '1 livro',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artigos',
      one: '1 artigo',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 livros/artigos';

  @override
  String get libraryNoItemsInCollection => 'Nenhum item nesta coleção';

  @override
  String libraryDeleteCollectionBody(String name) {
    return 'Isso remove apenas \"$name\". Livros e artigos continuam na sua biblioteca.';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return 'Remover $title da coleção';
  }

  @override
  String get librarySourceArticle => 'Artigo';

  @override
  String get librarySourceBook => 'Livro';

  @override
  String get librarySourceComic => 'Quadrinho';

  @override
  String get librarySourceNew => 'Novo';

  @override
  String get librarySourceDone => 'Concluído';

  @override
  String get librarySourceFinished => 'Finalizado';

  @override
  String get librarySourceUntitled => 'Fonte sem título';

  @override
  String get librarySourceOpenReader => 'Abrir leitor';

  @override
  String get librarySourceSelect => 'Selecionar fonte';

  @override
  String get librarySourceDeselect => 'Desmarcar fonte';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent por cento lido';
  }

  @override
  String get importAddToLibraryTitle => 'Adicionar à biblioteca';

  @override
  String get importUploadBook => 'Enviar livro';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => 'Salvar artigo';

  @override
  String get importSaveArticleDescription => 'Cole uma URL para ler offline';

  @override
  String get importBeforeUploadingTitle => 'Antes de enviar';

  @override
  String get importBookTermsBody =>
      'Envie apenas livros, quadrinhos e documentos que você tem direito de usar no ReadFlex.';

  @override
  String get importBookTermsConfirm =>
      'Confirmo que tenho direito de enviar este arquivo.';

  @override
  String get importLegalPrefix => 'Ao continuar, você aceita os ';

  @override
  String get importLegalAnd => ' e a ';

  @override
  String get importLegalSuffix => '.';

  @override
  String get importTerms => 'Termos';

  @override
  String get importPrivacyPolicy => 'Política de Privacidade';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'Colar URL';

  @override
  String get importArticleHintClean =>
      'Cria um artigo limpo para leitura offline.';

  @override
  String get importArticleHintSource => 'Mantém o link original da fonte.';

  @override
  String get importArticleHintLibrary => 'Adiciona à sua biblioteca.';

  @override
  String get importUploadingBook => 'Enviando livro...';

  @override
  String get importFetchingArticle => 'Buscando artigo...';

  @override
  String get importSavingArticle => 'Salvando cópia offline...';

  @override
  String get importComicAdded => 'Quadrinho adicionado!';

  @override
  String get importBookAdded => 'Livro adicionado!';

  @override
  String get importArticleSaved => 'Artigo salvo!';

  @override
  String get importTryAgain => 'Tentar novamente';

  @override
  String get importArticleUrlRequired => 'Insira a URL do artigo';

  @override
  String get importInvalidArticleUrl => 'Insira uma URL de artigo válida';

  @override
  String get importBookImportFailed => 'Não foi possível importar o livro';

  @override
  String get importArticleSaveFailed => 'Não foi possível salvar o artigo';

  @override
  String get highlightAction => 'Destacar';

  @override
  String get highlightTitle => 'Destacar';

  @override
  String get highlightNoteHint => 'Adicionar nota (opcional)';

  @override
  String get highlightFailedToSave => 'Não foi possível salvar o destaque';

  @override
  String get highlightColorYellow => 'Amarelo';

  @override
  String get highlightColorGreen => 'Verde';

  @override
  String get highlightColorBlue => 'Azul';

  @override
  String get highlightColorPink => 'Rosa';

  @override
  String get highlightColorPurple => 'Roxo';

  @override
  String highlightColorSemantics(String color) {
    return 'Cor de destaque $color';
  }

  @override
  String get highlightSelectColor => 'Selecionar cor do destaque';

  @override
  String get readerFailedToLoadContent =>
      'Não foi possível carregar o conteúdo';

  @override
  String get readerGoBack => 'Voltar';

  @override
  String get readerBookSearchUnavailable => 'Pesquisa no livro indisponível';

  @override
  String get readerNotReady => 'O leitor não está pronto';

  @override
  String get readerHighlightSaved => 'Destaque salvo';

  @override
  String get readerHighlightRemoved => 'Destaque removido';

  @override
  String get readerHighlightSaveFailed => 'Não foi possível salvar o destaque';

  @override
  String get readerCommentUpdated => 'Comentário atualizado';

  @override
  String get readerContents => 'Conteúdo';

  @override
  String get readerChapters => 'Capítulos';

  @override
  String get readerBookmarks => 'Marcadores';

  @override
  String get readerHighlights => 'Destaques';

  @override
  String get readerSearchChapters => 'Pesquisar capítulos';

  @override
  String get readerSearchBookmarks => 'Pesquisar marcadores';

  @override
  String get readerSearchHighlights => 'Pesquisar destaques';

  @override
  String get readerNoBookmarksYet => 'Ainda não há marcadores';

  @override
  String get readerNoMatchingBookmarks => 'Nenhum marcador encontrado';

  @override
  String get readerBookmarkedPage => 'Página marcada';

  @override
  String get readerDeleteBookmark => 'Excluir marcador';

  @override
  String get readerNoHighlightsYet => 'Ainda não há destaques';

  @override
  String get readerNoMatchingHighlights => 'Nenhum destaque encontrado';

  @override
  String get readerHighlightedText => 'Texto destacado';

  @override
  String get readerLocationUnavailable => 'Local indisponível';

  @override
  String get readerSearchInBook => 'Pesquisar no livro';

  @override
  String get readerNoResultsFound => 'Nenhum resultado encontrado';

  @override
  String get readerRecentSearches => 'Pesquisas recentes';

  @override
  String get readerRemoveFromHistory => 'Remover do histórico';

  @override
  String get readerSearchResult => 'Resultado da pesquisa';

  @override
  String get readerNoMatchingChapters => 'Nenhum capítulo encontrado';

  @override
  String get readerNoChaptersFound => 'Nenhum capítulo encontrado';

  @override
  String get readerSearchPrompt => 'Digite pelo menos 2 caracteres';

  @override
  String get readerSearchAction => 'Pesquisar';

  @override
  String get readerSearchFailed => 'A pesquisa falhou';

  @override
  String get readerUntitledChapter => 'Capítulo sem título';

  @override
  String readerPageNumber(int page) {
    return 'Página $page';
  }

  @override
  String get readerAppearanceTitle => 'Aparência';

  @override
  String get readerReset => 'Redefinir';

  @override
  String get readerTheme => 'Tema';

  @override
  String get readerFont => 'Fonte';

  @override
  String get readerFontSize => 'Tamanho do texto';

  @override
  String get readerLineSpacing => 'Espaçamento de linha';

  @override
  String get readerTextAlignment => 'Alinhamento do texto';

  @override
  String get readerPageMargins => 'Margens';

  @override
  String get readerPageTurn => 'Virada de página';

  @override
  String get readerAlignStart => 'Alinhar ao início';

  @override
  String get readerJustifyText => 'Justificar texto';

  @override
  String get readerAlignEnd => 'Alinhar ao fim';

  @override
  String get readerHorizontalPageTurn => 'Virada horizontal';

  @override
  String get readerVerticalPageTurn => 'Virada vertical';

  @override
  String get readerResetTextSize => 'Redefinir tamanho';

  @override
  String get readerTextSize => 'Tamanho do texto';

  @override
  String get readerDecreaseTextSize => 'Diminuir texto';

  @override
  String get readerIncreaseTextSize => 'Aumentar texto';

  @override
  String get readerResetLineSpacing => 'Redefinir espaçamento';

  @override
  String get readerDecreaseLineSpacing => 'Diminuir espaçamento';

  @override
  String get readerIncreaseLineSpacing => 'Aumentar espaçamento';

  @override
  String get readerResetPageMargins => 'Redefinir margens';

  @override
  String get readerDecreasePageMargins => 'Diminuir margens';

  @override
  String get readerIncreasePageMargins => 'Aumentar margens';

  @override
  String get readerThemeSnow => 'Neve';

  @override
  String get readerThemePaper => 'Papel';

  @override
  String get readerThemeWarm => 'Quente';

  @override
  String get readerThemeMist => 'Grafite';

  @override
  String get readerThemeNight => 'Noite';

  @override
  String get readerIncreaseBrightness => 'Aumentar brilho';

  @override
  String get readerDecreaseBrightness => 'Diminuir brilho';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'Usando brilho do sistema: $label';
  }

  @override
  String get readerUseSystemBrightness => 'Usar brilho do sistema';

  @override
  String get readerPageBookmarked => 'Página marcada';

  @override
  String get readerOpenOriginalArticle => 'Abrir artigo original';

  @override
  String get readerBack => 'Voltar';

  @override
  String get readerFontAction => 'Fonte';

  @override
  String get readerPageTurnVertical => 'Virada de página: vertical';

  @override
  String get readerPageTurnHorizontal => 'Virada de página: horizontal';

  @override
  String get readerRemoveBookmark => 'Remover marcador';

  @override
  String get readerBookmark => 'Marcador';

  @override
  String get readerEditComment => 'Editar comentário';

  @override
  String get readerRemoveHighlight => 'Remover destaque';

  @override
  String get readerHighlightNoteTitle => 'Nota do destaque';

  @override
  String get readerEditNoteTitle => 'Editar nota';

  @override
  String get readerCommentHint => 'Adicionar comentário (opcional)';

  @override
  String get readerSkip => 'Pular';
}
