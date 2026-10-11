import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_contents_tabs.dart';

void main() {
  const chapters = ReaderContentsTab.chapters;
  const pages = ReaderContentsTab.pages;
  const bookmarks = ReaderContentsTab.bookmarks;
  const highlights = ReaderContentsTab.highlights;

  List<ReaderContentsTab> tabs(BookFormat? format, {bool hasPageGrid = true}) =>
      readerContentsTabs(format: format, hasPageGrid: hasPageGrid);

  test('reflowable books and articles list chapters', () {
    for (final format in [
      BookFormat.epub,
      BookFormat.fb2,
      BookFormat.mobi,
      BookFormat.azw3,
      null,
    ]) {
      expect(tabs(format), [
        chapters,
        bookmarks,
        highlights,
      ], reason: '$format');
    }
  });

  test('comics list their pages instead of chapters', () {
    expect(tabs(BookFormat.cbz), [pages, bookmarks, highlights]);
    expect(tabs(BookFormat.cbz, hasPageGrid: false), [
      pages,
      bookmarks,
      highlights,
    ]);
  });

  test('PDF keeps Chapters first and adds Pages after it', () {
    expect(tabs(BookFormat.pdf), [chapters, pages, bookmarks, highlights]);
  });

  test('PDF shows Pages only once it reports its page count', () {
    expect(tabs(BookFormat.pdf, hasPageGrid: false), [
      chapters,
      bookmarks,
      highlights,
    ]);
  });
}
