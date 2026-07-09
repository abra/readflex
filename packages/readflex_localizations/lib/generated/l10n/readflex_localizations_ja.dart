// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'readflex_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class ReadflexLocalizationsJa extends ReadflexLocalizations {
  ReadflexLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appSkip => 'スキップ';

  @override
  String get appNext => '次へ';

  @override
  String get appGetStarted => '始める';

  @override
  String get appInitializationFailed => '初期化に失敗しました';

  @override
  String get appRetry => '再試行';

  @override
  String get appRetrying => '再試行中...';

  @override
  String get onboardingReadAnythingTitle => '何でも読む';

  @override
  String get onboardingReadAnythingDescription =>
      '本をインポートし、カスタマイズできるリーダーで快適に読みましょう。';

  @override
  String get onboardingHighlightSaveTitle => 'ハイライトして保存';

  @override
  String get onboardingHighlightSaveDescription =>
      'テキストを選択してハイライトを作成し、理解を深めるためにメモを追加できます。';

  @override
  String get onboardingOrganizeLibraryTitle => 'ライブラリを整理';

  @override
  String get onboardingOrganizeLibraryDescription =>
      '本と記事を一か所にまとめ、読書の続きにすぐ戻れます。';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '削除';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonBack => '戻る';

  @override
  String get commonDone => '完了';

  @override
  String get commonCreate => '作成';

  @override
  String get commonContinue => '続ける';

  @override
  String get commonSearch => '検索';

  @override
  String get commonClearSearch => '検索をクリア';

  @override
  String get libraryTitle => 'ライブラリ';

  @override
  String libraryItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String get libraryOffline => 'オフライン';

  @override
  String get librarySearchHint => 'ライブラリを検索...';

  @override
  String get libraryFilterAll => 'すべて';

  @override
  String get libraryFilterBooks => '本';

  @override
  String get libraryFilterArticles => '記事';

  @override
  String get libraryFilterComics => 'コミック';

  @override
  String get libraryFilterNew => '新規';

  @override
  String get libraryDisplayOptions => '表示オプション';

  @override
  String get libraryDisplayTitle => '表示';

  @override
  String get libraryDisplayView => 'ビュー';

  @override
  String get libraryDisplayAppearance => '外観';

  @override
  String get libraryDisplayLanguage => '言語';

  @override
  String get libraryDisplayList => 'リスト';

  @override
  String get libraryDisplayGrid => 'グリッド';

  @override
  String get libraryThemeSystem => 'システム';

  @override
  String get libraryThemeSystemDescription => '端末設定に合わせる';

  @override
  String get libraryThemeLight => 'ライト';

  @override
  String get libraryThemeLightDescription => 'ライト表示を使用';

  @override
  String get libraryThemeDark => 'ダーク';

  @override
  String get libraryThemeDarkDescription => 'ダーク表示を使用';

  @override
  String get libraryFailedToLoad => 'ライブラリを読み込めませんでした';

  @override
  String get libraryLoadCollectionsFailed => 'コレクションを読み込めませんでした';

  @override
  String get libraryUpdateCollectionFailed => 'コレクションを更新できませんでした';

  @override
  String get libraryUpdateFavouritesFailed => 'お気に入りを更新できませんでした';

  @override
  String get libraryCollectionNameRequired => 'コレクション名を入力してください';

  @override
  String get libraryCreateCollectionFailed => 'コレクションを作成できませんでした';

  @override
  String get librarySaveCollectionFailed => 'コレクションを保存できませんでした';

  @override
  String get libraryDeleteCollectionFailed => 'コレクションを削除できませんでした';

  @override
  String get libraryAddedToCollection => 'コレクションに追加しました';

  @override
  String libraryItemsAddedToCollection(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件をコレクションに追加しました',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionDeleted => 'コレクションを削除しました';

  @override
  String get libraryDeletedSuffix => ' を削除しました';

  @override
  String libraryItemsDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件を削除しました',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '項目を削除できませんでした',
    );
    return '$_temp0';
  }

  @override
  String get libraryAddToCollection => 'コレクションに追加';

  @override
  String get libraryEmptyTitle => 'ライブラリは空です';

  @override
  String get libraryEmptySubtitle => '最初の本または記事を追加しましょう';

  @override
  String get libraryNoResultsTitle => '結果が見つかりません';

  @override
  String get libraryNoResultsSubtitle => '別の検索またはフィルターを試してください';

  @override
  String get libraryAddToCollectionTitle => 'コレクションに追加';

  @override
  String get libraryFavourites => 'お気に入り';

  @override
  String libraryCreateCollectionPrompt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選択した $count 件用のコレクションを作成します。',
    );
    return '$_temp0';
  }

  @override
  String get libraryNewCollectionName => '新しいコレクション名';

  @override
  String libraryDeleteItemsTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件を削除しますか？',
    );
    return '$_temp0';
  }

  @override
  String libraryDeleteItemsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ライブラリ項目とハイライトが削除されます。アーカイブ済みの学習データは保持されます。',
    );
    return '$_temp0';
  }

  @override
  String get libraryCollectionsTitle => 'コレクション';

  @override
  String get librarySearchCollectionsHint => 'コレクションを検索...';

  @override
  String get libraryNoCollectionsYet => 'コレクションはまだありません';

  @override
  String get libraryNoMatchingCollections => '一致するコレクションはありません';

  @override
  String get libraryManualCollections => '手動コレクション';

  @override
  String get librarySites => 'サイト';

  @override
  String get libraryAuthors => '著者';

  @override
  String libraryManageCollection(String name) {
    return '$name を管理';
  }

  @override
  String get libraryOpenCollectionActions => 'コレクション操作を開く';

  @override
  String get libraryManageCollectionTitle => 'コレクションを管理';

  @override
  String get libraryDeleteCollectionTitle => 'コレクションを削除しますか？';

  @override
  String get libraryDeleteCollectionButton => 'コレクションを削除';

  @override
  String libraryBookCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 冊',
    );
    return '$_temp0';
  }

  @override
  String libraryArticleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の記事',
    );
    return '$_temp0';
  }

  @override
  String get libraryEmptySourceCount => '0 冊/記事';

  @override
  String get libraryNoItemsInCollection => 'このコレクションに項目はありません';

  @override
  String libraryDeleteCollectionBody(String name) {
    return '削除されるのは「$name」だけです。本と記事はライブラリに残ります。';
  }

  @override
  String libraryRemoveFromCollection(String title) {
    return '$title をコレクションから削除';
  }

  @override
  String get librarySourceArticle => '記事';

  @override
  String get librarySourceBook => '本';

  @override
  String get librarySourceComic => 'コミック';

  @override
  String get librarySourceNew => '新規';

  @override
  String get librarySourceDone => '完了';

  @override
  String get librarySourceFinished => '読了';

  @override
  String get librarySourceUntitled => '無題のソース';

  @override
  String get librarySourceOpenReader => 'リーダーを開く';

  @override
  String get librarySourceSelect => 'ソースを選択';

  @override
  String get librarySourceDeselect => '選択を解除';

  @override
  String librarySourcePercentRead(int percent) {
    return '$percent% 読了';
  }

  @override
  String get importAddToLibraryTitle => 'ライブラリに追加';

  @override
  String get importUploadBook => '本をアップロード';

  @override
  String get importUploadBookFormats => 'EPUB, FB2, MOBI, PDF, AZW3, CBZ';

  @override
  String get importSaveArticle => '記事を保存';

  @override
  String get importSaveArticleDescription => 'オフライン読書用にWeb URLを貼り付けます';

  @override
  String get importBeforeUploadingTitle => 'アップロード前';

  @override
  String get importBookTermsBody =>
      'ReadFlexで使用する権利がある本、コミック、文書のみをアップロードしてください。';

  @override
  String get importBookTermsConfirm => 'このファイルをアップロードする権利があることを確認します。';

  @override
  String get importLegalPrefix => '続行すると、';

  @override
  String get importLegalAnd => ' と ';

  @override
  String get importLegalSuffix => ' に同意したものとみなされます。';

  @override
  String get importTerms => '利用規約';

  @override
  String get importPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get importArticleUrlHint => 'https://example.com/article';

  @override
  String get importPasteUrl => 'URLを貼り付け';

  @override
  String get importArticleHintClean => 'オフライン読書用の読みやすい記事を作成します。';

  @override
  String get importArticleHintSource => '元のソースリンクを保持します。';

  @override
  String get importArticleHintLibrary => 'ライブラリに追加します。';

  @override
  String get importUploadingBook => '本をアップロード中...';

  @override
  String get importFetchingArticle => '記事を取得中...';

  @override
  String get importSavingArticle => 'オフラインコピーを保存中...';

  @override
  String get importComicAdded => 'コミックを追加しました！';

  @override
  String get importBookAdded => '本を追加しました！';

  @override
  String get importArticleSaved => '記事を保存しました！';

  @override
  String get importTryAgain => 'もう一度試す';

  @override
  String get importArticleUrlRequired => '記事のURLを入力してください';

  @override
  String get importInvalidArticleUrl => '有効な記事URLを入力してください';

  @override
  String get importBookImportFailed => '本をインポートできませんでした';

  @override
  String get importArticleSaveFailed => '記事を保存できませんでした';

  @override
  String get highlightAction => 'ハイライト';

  @override
  String get highlightTitle => 'ハイライト';

  @override
  String get highlightNoteHint => 'メモを追加（任意）';

  @override
  String get highlightFailedToSave => 'ハイライトを保存できませんでした';

  @override
  String get highlightColorYellow => '黄色';

  @override
  String get highlightColorGreen => '緑';

  @override
  String get highlightColorBlue => '青';

  @override
  String get highlightColorPink => 'ピンク';

  @override
  String get highlightColorPurple => '紫';

  @override
  String highlightColorSemantics(String color) {
    return '$colorのハイライト色';
  }

  @override
  String get highlightSelectColor => 'ハイライト色を選択';

  @override
  String get readerFailedToLoadContent => 'コンテンツを読み込めませんでした';

  @override
  String get readerGoBack => '戻る';

  @override
  String get readerBookSearchUnavailable => '本内検索は利用できません';

  @override
  String get readerNotReady => 'リーダーはまだ準備できていません';

  @override
  String get readerHighlightSaved => 'ハイライトを保存しました';

  @override
  String get readerHighlightRemoved => 'ハイライトを削除しました';

  @override
  String get readerHighlightSaveFailed => 'ハイライトを保存できませんでした';

  @override
  String get readerCommentUpdated => 'コメントを更新しました';

  @override
  String get readerContents => '目次';

  @override
  String get readerChapters => '章';

  @override
  String get readerBookmarks => 'ブックマーク';

  @override
  String get readerHighlights => 'ハイライト';

  @override
  String get readerSearchChapters => '章を検索';

  @override
  String get readerSearchBookmarks => 'ブックマークを検索';

  @override
  String get readerSearchHighlights => 'ハイライトを検索';

  @override
  String get readerNoBookmarksYet => 'ブックマークはまだありません';

  @override
  String get readerNoMatchingBookmarks => '一致するブックマークはありません';

  @override
  String get readerBookmarkedPage => 'ブックマークしたページ';

  @override
  String get readerDeleteBookmark => 'ブックマークを削除';

  @override
  String get readerNoHighlightsYet => 'ハイライトはまだありません';

  @override
  String get readerNoMatchingHighlights => '一致するハイライトはありません';

  @override
  String get readerHighlightedText => 'ハイライトされたテキスト';

  @override
  String get readerLocationUnavailable => '位置を利用できません';

  @override
  String get readerSearchInBook => '本内を検索';

  @override
  String get readerNoResultsFound => '結果が見つかりません';

  @override
  String get readerRecentSearches => '最近の検索';

  @override
  String get readerRemoveFromHistory => '履歴から削除';

  @override
  String get readerSearchResult => '検索結果';

  @override
  String get readerNoMatchingChapters => '一致する章はありません';

  @override
  String get readerNoChaptersFound => '章が見つかりません';

  @override
  String get readerSearchPrompt => '2文字以上入力してください';

  @override
  String get readerSearchAction => '検索';

  @override
  String get readerSearchFailed => '検索に失敗しました';

  @override
  String get readerUntitledChapter => '無題の章';

  @override
  String readerPageNumber(int page) {
    return '$page ページ';
  }

  @override
  String get readerAppearanceTitle => '外観';

  @override
  String get readerReset => 'リセット';

  @override
  String get readerTheme => 'テーマ';

  @override
  String get readerFont => 'フォント';

  @override
  String get readerFontSize => '文字サイズ';

  @override
  String get readerLineSpacing => '行間';

  @override
  String get readerTextAlignment => 'テキスト配置';

  @override
  String get readerPageMargins => 'ページ余白';

  @override
  String get readerPageTurn => 'ページめくり';

  @override
  String get readerAlignStart => '先頭に揃える';

  @override
  String get readerJustifyText => '両端揃え';

  @override
  String get readerAlignEnd => '末尾に揃える';

  @override
  String get readerHorizontalPageTurn => '横方向ページめくり';

  @override
  String get readerVerticalPageTurn => '縦方向ページめくり';

  @override
  String get readerResetTextSize => '文字サイズをリセット';

  @override
  String get readerTextSize => '文字サイズ';

  @override
  String get readerDecreaseTextSize => '文字を小さく';

  @override
  String get readerIncreaseTextSize => '文字を大きく';

  @override
  String get readerResetLineSpacing => '行間をリセット';

  @override
  String get readerDecreaseLineSpacing => '行間を狭く';

  @override
  String get readerIncreaseLineSpacing => '行間を広く';

  @override
  String get readerResetPageMargins => '余白をリセット';

  @override
  String get readerDecreasePageMargins => '余白を狭く';

  @override
  String get readerIncreasePageMargins => '余白を広く';

  @override
  String get readerThemeSnow => 'スノー';

  @override
  String get readerThemePaper => 'ペーパー';

  @override
  String get readerThemeWarm => 'ウォーム';

  @override
  String get readerThemeMist => 'グラファイト';

  @override
  String get readerThemeNight => 'ナイト';

  @override
  String get readerIncreaseBrightness => '明るさを上げる';

  @override
  String get readerDecreaseBrightness => '明るさを下げる';

  @override
  String readerUsingSystemBrightness(String label) {
    return 'システムの明るさを使用中: $label';
  }

  @override
  String get readerUseSystemBrightness => 'システムの明るさを使用';

  @override
  String get readerPageBookmarked => 'ページをブックマークしました';

  @override
  String get readerOpenOriginalArticle => '元の記事を開く';

  @override
  String get readerBack => '戻る';

  @override
  String get readerFontAction => 'フォント';

  @override
  String get readerPageTurnVertical => 'ページめくり: 縦';

  @override
  String get readerPageTurnHorizontal => 'ページめくり: 横';

  @override
  String get readerRemoveBookmark => 'ブックマークを削除';

  @override
  String get readerBookmark => 'ブックマーク';

  @override
  String get readerEditComment => 'コメントを編集';

  @override
  String get readerRemoveHighlight => 'ハイライトを削除';

  @override
  String get readerHighlightNoteTitle => 'ハイライトのメモ';

  @override
  String get readerEditNoteTitle => 'メモを編集';

  @override
  String get readerCommentHint => 'コメントを追加（任意）';

  @override
  String get readerSkip => 'スキップ';
}
