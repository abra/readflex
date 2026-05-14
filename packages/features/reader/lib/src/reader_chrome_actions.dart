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

const _comicReaderActions = {
  ReaderChromeAction.contents,
  ReaderChromeAction.bookmark,
};

Set<ReaderChromeAction> readerChromeActionsForFormat(BookFormat? format) {
  return switch (format) {
    BookFormat.cbz => _comicReaderActions,
    _ => _textReaderActions,
  };
}
