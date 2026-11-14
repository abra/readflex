import 'package:domain_models/domain_models.dart';

enum ReaderContentKind { text, article, comic, pdf, djvu }

enum ReaderChromeAction {
  contents,
  textAppearance,
  pageTurn,
  bookmark,
  textSearch,
}

enum ReaderAppearanceControls { text, pages, none }

enum ReaderContentsMode { chapters, pages, chaptersAndPages }

/// Text selection is intrinsic to reflowable content, absent from comics,
/// and discovered per document for PDF/DjVu.
enum ReaderTextSelectionSupport { always, textLayer, none }

/// Page indices are one-based for text sections/articles and zero-based for
/// document/image pages. PDF retains continuous percent-based scrubbing.
enum ReaderProgressMode {
  textSections,
  documentPages,
  imagePages,
  articleSections;

  bool get usesDiscretePages => this == imagePages || this == articleSections;

  bool get usesZeroBasedPages => this == documentPages || this == imagePages;

  bool get showsPageOverlay => this == imagePages;

  Duration get seekSettleTimeout => this == imagePages
      ? readerImagePageSeekSettleTimeout
      : readerDefaultSeekSettleTimeout;
}

const readerDefaultSeekSettleTimeout = Duration(milliseconds: 600);
const readerImagePageSeekSettleTimeout = Duration(seconds: 3);

/// Static Reader policy, separate from discovered `ReaderDocumentFeatures`.
/// Canonical const profiles keep per-frame lookups allocation-free. The
/// renderer still owns opening, navigation, layout and resource lifetimes.
class ReaderFormatCapabilities {
  const ReaderFormatCapabilities._({
    required this.contentKind,
    required this.chromeActions,
    required this.appearanceControls,
    required this.progressMode,
    required this.contentsMode,
    required this.textSelection,
    this.supportsZoom = false,
    this.supportsColumns = false,
    this.supportsPageTurns = true,
    this.allowsPageGesturesWithChrome = false,
    this.showsChapterTitles = true,
    this.supportsImageHighlightPreviews = false,
  });

  final ReaderContentKind contentKind;
  final Set<ReaderChromeAction> chromeActions;
  final ReaderAppearanceControls appearanceControls;
  final ReaderProgressMode progressMode;
  final ReaderContentsMode contentsMode;
  final ReaderTextSelectionSupport textSelection;
  final bool supportsZoom;
  final bool supportsColumns;
  final bool supportsPageTurns;
  final bool allowsPageGesturesWithChrome;
  final bool showsChapterTitles;
  final bool supportsImageHighlightPreviews;
}

const _textActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.textAppearance,
  ReaderChromeAction.bookmark,
  ReaderChromeAction.textSearch,
};

const _text = ReaderFormatCapabilities._(
  contentKind: ReaderContentKind.text,
  chromeActions: _textActions,
  appearanceControls: ReaderAppearanceControls.text,
  progressMode: ReaderProgressMode.textSections,
  contentsMode: ReaderContentsMode.chapters,
  textSelection: ReaderTextSelectionSupport.always,
  supportsColumns: true,
);

const _article = ReaderFormatCapabilities._(
  contentKind: ReaderContentKind.article,
  chromeActions: _textActions,
  appearanceControls: ReaderAppearanceControls.text,
  progressMode: ReaderProgressMode.articleSections,
  contentsMode: ReaderContentsMode.chapters,
  textSelection: ReaderTextSelectionSupport.always,
  supportsPageTurns: false,
);

const _pdf = ReaderFormatCapabilities._(
  contentKind: ReaderContentKind.pdf,
  chromeActions: _textActions,
  appearanceControls: ReaderAppearanceControls.pages,
  progressMode: ReaderProgressMode.documentPages,
  contentsMode: ReaderContentsMode.chaptersAndPages,
  textSelection: ReaderTextSelectionSupport.textLayer,
  supportsZoom: true,
);

const _comic = ReaderFormatCapabilities._(
  contentKind: ReaderContentKind.comic,
  chromeActions: {
    ReaderChromeAction.contents,
    ReaderChromeAction.pageTurn,
    ReaderChromeAction.bookmark,
  },
  appearanceControls: ReaderAppearanceControls.none,
  progressMode: ReaderProgressMode.imagePages,
  contentsMode: ReaderContentsMode.pages,
  textSelection: ReaderTextSelectionSupport.none,
  supportsZoom: true,
  allowsPageGesturesWithChrome: true,
  showsChapterTitles: false,
  supportsImageHighlightPreviews: true,
);

const _djvu = ReaderFormatCapabilities._(
  contentKind: ReaderContentKind.djvu,
  chromeActions: {
    ReaderChromeAction.contents,
    ReaderChromeAction.pageTurn,
    ReaderChromeAction.bookmark,
    ReaderChromeAction.textSearch,
  },
  appearanceControls: ReaderAppearanceControls.none,
  progressMode: ReaderProgressMode.imagePages,
  contentsMode: ReaderContentsMode.chaptersAndPages,
  textSelection: ReaderTextSelectionSupport.textLayer,
  supportsZoom: true,
  allowsPageGesturesWithChrome: true,
  showsChapterTitles: false,
);

/// Articles take precedence over legacy format metadata. A book whose format
/// is not known yet retains the existing text-reader policy. New BookFormat
/// values must be classified here by the exhaustive switch.
ReaderFormatCapabilities readerFormatCapabilitiesFor({
  SourceType sourceType = SourceType.book,
  required BookFormat? format,
}) {
  if (sourceType == SourceType.article) return _article;
  return switch (format) {
    BookFormat.epub ||
    BookFormat.fb2 ||
    BookFormat.mobi ||
    BookFormat.azw3 ||
    null => _text,
    BookFormat.pdf => _pdf,
    BookFormat.cbz => _comic,
    BookFormat.djvu => _djvu,
  };
}
