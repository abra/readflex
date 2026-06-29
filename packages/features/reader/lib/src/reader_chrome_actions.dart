import 'package:domain_models/domain_models.dart';

enum ReaderChromeAction {
  contents,
  textAppearance,
  pageTurn,
  bookmark,
  textSearch,
}

const _textReaderActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.textAppearance,
  ReaderChromeAction.bookmark,
  ReaderChromeAction.textSearch,
};

const _imagePageReaderActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.pageTurn,
  ReaderChromeAction.bookmark,
};

const _articleHtmlReaderActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.textAppearance,
  ReaderChromeAction.bookmark,
  ReaderChromeAction.textSearch,
};

Set<ReaderChromeAction> readerChromeActionsForFormat(BookFormat? format) {
  return switch (format) {
    BookFormat.cbz => _imagePageReaderActions,
    _ => _textReaderActions,
  };
}

Set<ReaderChromeAction> readerChromeActionsFor({
  required SourceType sourceType,
  required BookFormat? format,
}) {
  if (sourceType == SourceType.article) return _articleHtmlReaderActions;
  return readerChromeActionsForFormat(format);
}
