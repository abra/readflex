/// Article domain repository: fetches, sanitises and stores articles on
/// disk; ships them as both raw HTML and a packaged EPUB so the reader can
/// render them through foliate-js alongside books.
library;

export 'src/article_repository.dart';
export 'src/epub_builder.dart' show EpubBuilder, EpubImage;
