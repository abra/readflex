// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class ReadflexLocalizationsZh extends ReadflexLocalizations {
  ReadflexLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appSkip => '跳过';

  @override
  String get appNext => '下一步';

  @override
  String get appGetStarted => '开始';

  @override
  String get appInitializationFailed => '初始化失败';

  @override
  String get appRetry => '重试';

  @override
  String get appRetrying => '正在重试...';

  @override
  String get onboardingReadAnythingTitle => '阅读任何内容';

  @override
  String get onboardingReadAnythingDescription => '导入图书，并使用可自定义的阅读器舒适阅读。';

  @override
  String get onboardingHighlightSaveTitle => '高亮并保存';

  @override
  String get onboardingHighlightSaveDescription => '选择文字创建高亮。添加笔记以加深理解。';

  @override
  String get onboardingOrganizeLibraryTitle => '整理你的书库';

  @override
  String get onboardingOrganizeLibraryDescription => '将图书和文章放在一处，并随时回到阅读进度。';

  @override
  String get commonCancel => '取消';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonRetry => '重试';

  @override
  String get commonClose => '关闭';

  @override
  String get commonBack => '返回';

  @override
  String get commonDone => '完成';

  @override
  String get commonCreate => '创建';

  @override
  String get commonContinue => '继续';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonClearSearch => '清除搜索';

  @override
  String get libraryTitle => '书库';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => '离线';

  @override
  String get librarySearchHint => '搜索书库...';

  @override
  String get libraryFilterAll => '全部';

  @override
  String get libraryFilterBooks => '图书';

  @override
  String get libraryFilterArticles => '文章';

  @override
  String get libraryFilterComics => '漫画';

  @override
  String get libraryFilterNew => '新内容';

  @override
  String get libraryDisplayOptions => '显示选项';

  @override
  String get libraryDisplayTitle => '显示';

  @override
  String get libraryDisplayView => '视图';

  @override
  String get libraryDisplayAppearance => '外观';

  @override
  String get libraryDisplayLanguage => '语言';

  @override
  String get libraryDisplayList => '列表';

  @override
  String get libraryDisplayGrid => '网格';

  @override
  String get libraryThemeSystem => '系统';

  @override
  String get libraryThemeSystemDescription => '跟随设备设置';

  @override
  String get libraryThemeLight => '浅色';

  @override
  String get libraryThemeLightDescription => '使用浅色外观';

  @override
  String get libraryThemeDark => '深色';

  @override
  String get libraryThemeDarkDescription => '使用深色外观';

  @override
  String get libraryFailedToLoad => '无法加载书库';

  @override
  String get libraryLoadCollectionsFailed => '无法加载收藏集';

  @override
  String get libraryUpdateCollectionFailed => '无法更新收藏集';

  @override
  String get libraryUpdateFavouritesFailed => '无法更新收藏夹';

  @override
  String get libraryCollectionNameRequired => '需要填写收藏集名称';

  @override
  String get libraryCreateCollectionFailed => '无法创建收藏集';

  @override
  String get librarySaveCollectionFailed => '无法保存收藏集';

  @override
  String get libraryDeleteCollectionFailed => '无法删除收藏集';

  @override
  String get libraryAddedToCollection => '已添加到收藏集';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 项添加到收藏集',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => '收藏集已删除';

  @override
  String get libraryDeletedSuffix => ' 已删除';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已删除 $count 项',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '无法删除项目',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => '添加到收藏集';

  @override
  String get libraryEmptyTitle => '你的书库是空的';

  @override
  String get libraryEmptySubtitle => '添加第一本书或第一篇文章';

  @override
  String get libraryNoResultsTitle => '未找到结果';

  @override
  String get libraryNoResultsSubtitle => '尝试其他搜索或筛选条件';

  @override
  String get libraryAddToCollectionTitle => '添加到收藏集';

  @override
  String get libraryFavourites => '收藏';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '为 $count 个已选项目创建收藏集。',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => '新收藏集名称';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '删除 $count 个项目？',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '这会删除书库项目和你的高亮。已归档的学习数据会保留。',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => '收藏集';

  @override
  String get librarySearchCollectionsHint => '搜索收藏集...';

  @override
  String get libraryNoCollectionsYet => '还没有收藏集';

  @override
  String get libraryNoMatchingCollections => '没有匹配的收藏集';

  @override
  String get libraryManualCollections => '手动收藏集';

  @override
  String get librarySites => '网站';

  @override
  String get libraryAuthors => '作者';

  @override
  String libraryManageCollection(String name) {
    return '管理 $name';
  }

  @override
  String get libraryOpenCollectionActions => '打开收藏集操作';

  @override
  String get libraryManageCollectionTitle => '管理收藏集';

  @override
  String get libraryDeleteCollectionTitle => '删除收藏集？';

  @override
  String get libraryDeleteCollectionButton => '删除收藏集';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 本书',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 篇文章',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 本书/文章';

  @override
  String get libraryNoItemsInCollection => '此收藏集中没有项目';

  @override
  String libraryDeleteCollectionBody(String name) {
    return '这只会删除“$name”。图书和文章仍会保留在你的书库中。';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return '从收藏集中移除 $title';
  }

  @override
  String get librarySourceArticle => '文章';

  @override
  String get librarySourceBook => '图书';

  @override
  String get librarySourceComic => '漫画';

  @override
  String get librarySourceNew => '新内容';

  @override
  String get librarySourceDone => '完成';

  @override
  String get librarySourceFinished => '已读完';

  @override
  String get librarySourceUntitled => '未命名来源';

  @override
  String get librarySourceOpenReader => '打开阅读器';

  @override
  String get librarySourceSelect => '选择来源';

  @override
  String get librarySourceDeselect => '取消选择来源';

  @override
  String librarySourcePercentRead(int percent) {
    return '已读 $percent%';
  }

  @override
  String get importAddToLibraryTitle => '添加到书库';

  @override
  String get importUploadBook => '上传图书';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => '保存文章';

  @override
  String get importSaveArticleDescription => '粘贴网页 URL 以便离线阅读';

  @override
  String get importBeforeUploadingTitle => '上传前';

  @override
  String get importBookTermsBody => '请只上传你有权在 ReadFlex 中使用的图书、漫画和文档。';

  @override
  String get importBookTermsConfirm => '我确认我有权上传此文件。';

  @override
  String get importLegalPrefix => '继续即表示你接受';

  @override
  String get importLegalAnd => '和';

  @override
  String get importLegalSuffix => '。';

  @override
  String get importTerms => '条款';

  @override
  String get importPrivacyPolicy => '隐私政策';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => '粘贴 URL';

  @override
  String get importArticleHintClean => '创建适合离线阅读的干净文章。';

  @override
  String get importArticleHintSource => '保留原始来源链接。';

  @override
  String get importArticleHintLibrary => '添加到你的书库。';

  @override
  String get importUploadingBook => '正在上传图书...';

  @override
  String get importFetchingArticle => '正在获取文章...';

  @override
  String get importSavingArticle => '正在保存离线副本...';

  @override
  String get importComicAdded => '漫画已添加！';

  @override
  String get importBookAdded => '图书已添加！';

  @override
  String get importArticleSaved => '文章已保存！';

  @override
  String get importTryAgain => '重试';

  @override
  String get importArticleUrlRequired => '请输入文章 URL';

  @override
  String get importInvalidArticleUrl => '请输入有效的文章 URL';

  @override
  String get importBookImportFailed => '无法导入图书';

  @override
  String get importArticleSaveFailed => '无法保存文章';

  @override
  String get highlightAction => '高亮';

  @override
  String get highlightTitle => '高亮';

  @override
  String get highlightNoteHint => '添加笔记（可选）';

  @override
  String get highlightFailedToSave => '无法保存高亮';

  @override
  String get highlightColorYellow => '黄色';

  @override
  String get highlightColorGreen => '绿色';

  @override
  String get highlightColorBlue => '蓝色';

  @override
  String get highlightColorPink => '粉色';

  @override
  String get highlightColorPurple => '紫色';

  @override
  String highlightColorSemantics(String color) {
    return '$color高亮颜色';
  }

  @override
  String get highlightSelectColor => '选择高亮颜色';

  @override
  String get readerFailedToLoadContent => '无法加载内容';

  @override
  String get readerGoBack => '返回';

  @override
  String get readerBookSearchUnavailable => '图书搜索不可用';

  @override
  String get readerNotReady => '阅读器尚未准备好';

  @override
  String get readerHighlightSaved => '高亮已保存';

  @override
  String get readerHighlightRemoved => '高亮已移除';

  @override
  String get readerHighlightSaveFailed => '无法保存高亮';

  @override
  String get readerCommentUpdated => '评论已更新';

  @override
  String get readerContents => '目录';

  @override
  String get readerChapters => '章节';

  @override
  String get readerBookmarks => '书签';

  @override
  String get readerHighlights => '高亮';

  @override
  String get readerSearchChapters => '搜索章节';

  @override
  String get readerSearchBookmarks => '搜索书签';

  @override
  String get readerSearchHighlights => '搜索高亮';

  @override
  String get readerNoBookmarksYet => '还没有书签';

  @override
  String get readerNoMatchingBookmarks => '没有匹配的书签';

  @override
  String get readerBookmarkedPage => '已加书签的页面';

  @override
  String get readerDeleteBookmark => '删除书签';

  @override
  String get readerNoHighlightsYet => '还没有高亮';

  @override
  String get readerNoMatchingHighlights => '没有匹配的高亮';

  @override
  String get readerHighlightedText => '高亮文字';

  @override
  String get readerLocationUnavailable => '位置不可用';

  @override
  String get readerSearchInBook => '在书中搜索';

  @override
  String get readerNoResultsFound => '未找到结果';

  @override
  String get readerRecentSearches => '最近搜索';

  @override
  String get readerRemoveFromHistory => '从历史中移除';

  @override
  String get readerSearchResult => '搜索结果';

  @override
  String get readerNoMatchingChapters => '没有匹配的章节';

  @override
  String get readerNoChaptersFound => '未找到章节';

  @override
  String get readerSearchPrompt => '至少输入 2 个字符';

  @override
  String get readerSearchAction => '搜索';

  @override
  String get readerSearchFailed => '搜索失败';

  @override
  String get readerUntitledChapter => '未命名章节';

  @override
  String readerPageNumber(int page) {
    return '第 $page 页';
  }

  @override
  String get readerAppearanceTitle => '外观';

  @override
  String get readerReset => '重置';

  @override
  String get readerTheme => '主题';

  @override
  String get readerFont => '字体';

  @override
  String get readerFontSize => '文字大小';

  @override
  String get readerLineSpacing => '行距';

  @override
  String get readerTextAlignment => '文本对齐';

  @override
  String get readerPageMargins => '页边距';

  @override
  String get readerPageTurn => '翻页';

  @override
  String get readerAlignStart => '起始对齐';

  @override
  String get readerJustifyText => '两端对齐';

  @override
  String get readerAlignEnd => '末端对齐';

  @override
  String get readerHorizontalPageTurn => '水平翻页';

  @override
  String get readerVerticalPageTurn => '垂直翻页';

  @override
  String get readerResetTextSize => '重置文字大小';

  @override
  String get readerTextSize => '文字大小';

  @override
  String get readerDecreaseTextSize => '减小文字';

  @override
  String get readerIncreaseTextSize => '增大文字';

  @override
  String get readerResetLineSpacing => '重置行距';

  @override
  String get readerDecreaseLineSpacing => '减小行距';

  @override
  String get readerIncreaseLineSpacing => '增大行距';

  @override
  String get readerResetPageMargins => '重置页边距';

  @override
  String get readerDecreasePageMargins => '减小页边距';

  @override
  String get readerIncreasePageMargins => '增大页边距';

  @override
  String get readerThemeSnow => '雪白';

  @override
  String get readerThemePaper => '纸张';

  @override
  String get readerThemeWarm => '暖色';

  @override
  String get readerThemeMist => '石墨';

  @override
  String get readerThemeNight => '夜间';

  @override
  String get readerIncreaseBrightness => '提高亮度';

  @override
  String get readerDecreaseBrightness => '降低亮度';

  @override
  String readerUsingSystemBrightness(String label) {
    return '正在使用系统亮度：$label';
  }

  @override
  String get readerUseSystemBrightness => '使用系统亮度';

  @override
  String get readerPageBookmarked => '页面已加书签';

  @override
  String get readerOpenOriginalArticle => '打开原始文章';

  @override
  String get readerBack => '返回';

  @override
  String get readerFontAction => '字体';

  @override
  String get readerPageTurnVertical => '翻页：垂直';

  @override
  String get readerPageTurnHorizontal => '翻页：水平';

  @override
  String get readerRemoveBookmark => '移除书签';

  @override
  String get readerBookmark => '书签';

  @override
  String get readerEditComment => '编辑评论';

  @override
  String get readerRemoveHighlight => '移除高亮';

  @override
  String get readerHighlightNoteTitle => '高亮笔记';

  @override
  String get readerEditNoteTitle => '编辑笔记';

  @override
  String get readerCommentHint => '添加评论（可选）';

  @override
  String get readerSkip => '跳过';
}
