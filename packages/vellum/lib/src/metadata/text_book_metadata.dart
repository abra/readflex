/// Title, author, description and cover of EPUB, FB2 and MOBI books for
/// the library's import: what the headless WebView used to read through
/// foliate-js (`book.metadata` and `getCover()`), from the native
/// parsers.
///
/// Authors are joined with `, ` as the WebView import stored them, the
/// cover is decoded and scaled to the library's thumbnail size, and a
/// book without a title takes its file name.
library;

import 'dart:typed_data';

import '../formats/epub/epub_book.dart';
import '../formats/fb2/fb2_book.dart';
import '../formats/mobi/mobi_book.dart';
import 'book_metadata.dart';
import 'cover_thumbnail.dart';

/// The metadata of the EPUB at [path].
Future<BookMetadata> readEpubMetadata(
  String path, {
  CoverThumbnailSpec spec = const CoverThumbnailSpec(),
}) async {
  final book = await EpubBook.open(path);
  try {
    final metadata = book.metadata;
    final cover = await book.readCover();
    return BookMetadata(
      title: _titleOr(metadata.title, path),
      author: _joinNames(metadata.authors.map((a) => a.name)),
      description: _nonEmpty(metadata.description),
      cover: await _thumbnail(cover?.bytes, spec),
    );
  } finally {
    await book.close();
  }
}

/// The metadata of the FB2 (or zipped FB2) at [path]. The description is
/// the annotation's XHTML, as the WebView import stored it.
Future<BookMetadata> readFb2Metadata(
  String path, {
  CoverThumbnailSpec spec = const CoverThumbnailSpec(),
}) async {
  final book = await Fb2Book.open(path);
  final metadata = book.metadata;
  return BookMetadata(
    title: _titleOr(metadata.title, path),
    author: _joinNames(metadata.authors.map((a) => a.name)),
    description: _nonEmpty(metadata.description),
    cover: await _thumbnail(book.readCover()?.bytes, spec),
  );
}

/// The metadata of the MOBI or KF8 book at [path].
Future<BookMetadata> readMobiMetadata(
  String path, {
  CoverThumbnailSpec spec = const CoverThumbnailSpec(),
}) async {
  final book = await MobiBook.open(path);
  try {
    final (metadata, cover) = switch (book) {
      MobiKf8(:final book) => (book.metadata, await book.readCover()),
      MobiLegacy(:final book) => (book.metadata, await book.readCover()),
    };
    return BookMetadata(
      title: _titleOr(metadata.title, path),
      author: _joinNames(metadata.authors ?? const []),
      description: _nonEmpty(metadata.description),
      cover: await _thumbnail(cover?.bytes, spec),
    );
  } finally {
    await book.close();
  }
}

Future<CoverImage?> _thumbnail(Uint8List? bytes, CoverThumbnailSpec spec) {
  if (bytes == null || bytes.isEmpty) return Future.value(null);
  return encodeCoverThumbnail(bytes, spec: spec);
}

String? _joinNames(Iterable<String> names) {
  final kept = [
    for (final name in names)
      if (name.trim().isNotEmpty) name.trim(),
  ];
  return kept.isEmpty ? null : kept.join(', ');
}

String? _nonEmpty(String? text) =>
    text == null || text.trim().isEmpty ? null : text;

/// [title] trimmed, or the file name without its extension (`.fb2.zip`
/// counts as one) when the book has no title.
String _titleOr(String? title, String path) {
  final trimmed = title?.trim() ?? '';
  if (trimmed.isNotEmpty) return trimmed;
  final slash = path.lastIndexOf('/');
  final name = slash < 0 ? path : path.substring(slash + 1);
  return name.replaceFirst(
    RegExp(r'(\.fb2\.zip|\.[A-Za-z0-9]+)$', caseSensitive: false),
    '',
  );
}
