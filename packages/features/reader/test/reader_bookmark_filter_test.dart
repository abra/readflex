import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bookmark_filter.dart';

void main() {
  final first = SourceBookmark(
    id: 'bookmark-1',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    cfi: 'epubcfi(/6/2)',
    content: '',
    progress: 0.42,
    chapterTitle: 'Dependency Injection',
    createdAt: DateTime(2026, 5, 17),
  );
  final second = SourceBookmark(
    id: 'bookmark-2',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    cfi: 'epubcfi(/6/4)',
    content: 'Factory Method overview',
    progress: 0.64,
    chapterTitle: 'Creational Patterns',
    createdAt: DateTime(2026, 5, 17, 1),
  );
  final bookmarks = [first, second];

  test('returns all bookmarks for an empty query', () {
    expect(filterReaderBookmarks(bookmarks, '  '), bookmarks);
  });

  test('matches bookmark content case-insensitively', () {
    expect(filterReaderBookmarks(bookmarks, 'factory'), [second]);
  });

  test('matches chapter title when bookmark content is empty', () {
    expect(filterReaderBookmarks(bookmarks, 'dependency'), [first]);
  });

  test('matches generated fallback text for empty bookmark content', () {
    expect(filterReaderBookmarks(bookmarks, 'bookmarked page'), [first]);
  });

  test('matches percentage labels', () {
    expect(filterReaderBookmarks(bookmarks, '64%'), [second]);
  });
}
