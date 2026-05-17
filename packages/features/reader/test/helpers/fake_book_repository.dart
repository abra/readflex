import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  final List<Book> books = [];
  final Map<String, List<SourceBookmark>> bookmarksBySourceId = {};

  Book? updatedBook;

  /// Number of times [updateBook] has been called. Used by debounce
  /// tests to verify rapid position updates collapse into a single
  /// trailing write.
  int updateCallCount = 0;

  void seedBook(Book book) => books.add(book);

  void seedBookmarks(String sourceId, List<SourceBookmark> bookmarks) {
    bookmarksBySourceId[sourceId] = bookmarks;
  }

  @override
  Future<Book?> getBookById(String id) async {
    if (shouldThrow) throw Exception('getBookById failed');
    return books.where((b) => b.id == id).firstOrNull;
  }

  @override
  Future<Book> updateBook(Book book) async {
    if (shouldThrow) throw Exception('updateBook failed');
    updatedBook = book;
    updateCallCount += 1;
    return book;
  }

  @override
  Future<List<SourceBookmark>> getBookmarksBySource(String sourceId) async {
    if (shouldThrow) throw Exception('getBookmarksBySource failed');
    return bookmarksBySourceId[sourceId] ?? [];
  }

  @override
  Future<SourceBookmark> addBookmark({
    required String sourceId,
    required SourceType sourceType,
    required String cfi,
    required String content,
    required double progress,
    String? chapterTitle,
  }) async {
    if (shouldThrow) throw Exception('addBookmark failed');
    final existing = (bookmarksBySourceId[sourceId] ?? [])
        .where((bookmark) => bookmark.cfi == cfi)
        .firstOrNull;
    if (existing != null) return existing;

    final bookmark = SourceBookmark(
      id: 'bookmark-${bookmarksBySourceId.length + 1}',
      sourceId: sourceId,
      sourceType: sourceType,
      cfi: cfi,
      content: content,
      progress: progress,
      chapterTitle: chapterTitle,
      createdAt: DateTime(2026, 5, 17, bookmarksBySourceId.length),
    );
    bookmarksBySourceId.update(
      sourceId,
      (bookmarks) => [...bookmarks, bookmark],
      ifAbsent: () => [bookmark],
    );
    return bookmark;
  }

  @override
  Future<void> deleteBookmarkBySourceAndCfi(String sourceId, String cfi) async {
    if (shouldThrow) throw Exception('deleteBookmark failed');
    bookmarksBySourceId.update(
      sourceId,
      (bookmarks) => [
        for (final bookmark in bookmarks)
          if (bookmark.cfi != cfi) bookmark,
      ],
      ifAbsent: () => const [],
    );
  }
}
