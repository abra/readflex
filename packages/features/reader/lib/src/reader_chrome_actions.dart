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

Set<ReaderChromeAction> readerChromeActionsForFormat(BookFormat? format) {
  return switch (format) {
    BookFormat.cbz => _imagePageReaderActions,
    _ => _textReaderActions,
  };
}
