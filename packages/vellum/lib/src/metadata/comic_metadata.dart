import 'dart:typed_data';

import '../formats/comic_book.dart';
import '../formats/comic_page_order.dart';
import '../vellum_exception.dart';
import 'book_metadata.dart';
import 'cover_thumbnail.dart';

/// First pages above this size are not decoded for a cover.
const defaultMaxCoverBytes = 32 * 1024 * 1024;

/// The title and cover of the comic at [path], for the library's import:
/// the counterpart of `getMetadata` in `book.js` over `comic-book.js`,
/// without a WebView.
///
/// The title is the file name without its extension and the cover is the
/// first page in reading order, encoded by [encodeCoverThumbnail]. A first
/// page above [maxCoverBytes] or one that does not decode leaves
/// [BookMetadata.cover] null. Throws [VellumException] when the file is not
/// a comic.
Future<BookMetadata> readComicMetadata(
  String path, {
  CoverThumbnailSpec spec = const CoverThumbnailSpec(),
  int maxCoverBytes = defaultMaxCoverBytes,
}) async {
  final book = await ComicBook.open(
    path,
    pageOrderVersion: currentComicPageOrderVersion,
  );
  try {
    return BookMetadata(
      title: book.title,
      cover: await _readCover(book, spec, maxCoverBytes),
    );
  } finally {
    await book.close();
  }
}

Future<CoverImage?> _readCover(
  ComicBook book,
  CoverThumbnailSpec spec,
  int maxCoverBytes,
) async {
  final Uint8List bytes;
  try {
    bytes = await book.readCover(maxBytes: maxCoverBytes);
  } on VellumException {
    return null;
  }
  return encodeCoverThumbnail(bytes, spec: spec);
}
