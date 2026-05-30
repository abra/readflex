import 'package:domain_models/domain_models.dart';

enum ReaderChromeAction {
  contents,
  textAppearance,
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
  ReaderChromeAction.bookmark,
};

const _djvuReaderActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.bookmark,
  ReaderChromeAction.textSearch,
};

Set<ReaderChromeAction> readerChromeActionsForFormat(BookFormat? format) {
  return switch (format) {
    BookFormat.cbz => _imagePageReaderActions,
    BookFormat.djvu => _djvuReaderActions,
    _ => _textReaderActions,
  };
}
