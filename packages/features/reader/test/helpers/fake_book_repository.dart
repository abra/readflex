import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';

class FakeBookRepository implements BookRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  bool shouldThrow = false;

  /// Awaited before a restore completes, so tests can observe busy rows.
  Future<void>? restoreGate;

  final List<Book> books = [];
  final Map<String, List<SourceBookmark>> bookmarksBySourceId = {};
  int _bookmarkSequence = 0;

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
    if (shouldThrow) throw const StorageException(cause: 'getBookById failed');
    return books.where((b) => b.id == id).firstOrNull;
  }

  @override
  Future<Book> updateBook(Book book) async {
    if (shouldThrow) throw const StorageException(cause: 'updateBook failed');
    updatedBook = book;
    updateCallCount += 1;
    final index = books.indexWhere((existing) => existing.id == book.id);
    if (index >= 0) books[index] = book;
    return book;
  }

  @override
  Future<void> markOpened(String id, DateTime openedAt) async {
    final book = books.where((book) => book.id == id).firstOrNull;
    if (book != null) await updateBook(book.copyWith(lastOpenedAt: openedAt));
  }

  @override
  Future<void> updateReadingPosition(
    String id, {
    required String? cfi,
    required double progress,
  }) async {
    final book = books.where((book) => book.id == id).firstOrNull;
    if (book != null) {
      await updateBook(
        book.copyWith(currentCfi: cfi, readingProgress: progress),
      );
    }
  }

  @override
  Future<List<SourceBookmark>> getBookmarksBySource(String sourceId) async {
    if (shouldThrow) {
      throw const StorageException(cause: 'getBookmarksBySource failed');
    }
    return List<SourceBookmark>.of(bookmarksBySourceId[sourceId] ?? [])..sort((
      a,
      b,
    ) {
      final byProgress = a.progress.compareTo(b.progress);
      return byProgress != 0 ? byProgress : a.createdAt.compareTo(b.createdAt);
    });
  }

  @override
  Future<SourceBookmark> addBookmark({
    required String sourceId,
    required SourceType sourceType,
    required String cfi,
    required String content,
    required double progress,
    String? chapterTitle,
    String? anchorExact,
    String? anchorPrefix,
    String? anchorSuffix,
    int? anchorSectionIndex,
    int? anchorSectionPage,
    int? anchorVersion,
  }) async {
    if (shouldThrow) throw const StorageException(cause: 'addBookmark failed');
    final existing = _bookmarkAt(
      sourceId: sourceId,
      cfi: cfi,
      anchorExact: anchorExact,
      anchorPrefix: anchorPrefix,
      anchorSuffix: anchorSuffix,
      anchorSectionIndex: anchorSectionIndex,
      anchorSectionPage: anchorSectionPage,
    );
    if (existing != null) return existing;

    String id;
    do {
      id = 'bookmark-${++_bookmarkSequence}';
    } while (bookmarksBySourceId.values
        .expand((items) => items)
        .any(
          (bookmark) => bookmark.id == id,
        ));
    final bookmark = SourceBookmark(
      id: id,
      sourceId: sourceId,
      sourceType: sourceType,
      cfi: cfi,
      content: content,
      progress: progress.clamp(0.0, 1.0).toDouble(),
      chapterTitle: chapterTitle,
      anchorExact: anchorExact,
      anchorPrefix: anchorPrefix,
      anchorSuffix: anchorSuffix,
      anchorSectionIndex: anchorSectionIndex,
      anchorSectionPage: anchorSectionPage,
      anchorVersion: anchorVersion,
      createdAt: DateTime(2026, 5, 17, 0, 0, _bookmarkSequence),
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
    if (shouldThrow) {
      throw const StorageException(cause: 'deleteBookmark failed');
    }
    bookmarksBySourceId.update(
      sourceId,
      (bookmarks) => [
        for (final bookmark in bookmarks)
          if (bookmark.cfi != cfi) bookmark,
      ],
      ifAbsent: () => const [],
    );
  }

  @override
  Future<void> deleteBookmarkById(String sourceId, String bookmarkId) async {
    if (shouldThrow) {
      throw const StorageException(cause: 'deleteBookmark failed');
    }
    bookmarksBySourceId.update(
      sourceId,
      (bookmarks) => [
        for (final bookmark in bookmarks)
          if (bookmark.id != bookmarkId) bookmark,
      ],
      ifAbsent: () => const [],
    );
  }

  @override
  Future<SourceBookmark> restoreBookmark(SourceBookmark bookmark) async {
    await restoreGate;
    if (shouldThrow) {
      throw const StorageException(cause: 'restoreBookmark failed');
    }
    final existing = _bookmarkAt(
      sourceId: bookmark.sourceId,
      cfi: bookmark.cfi,
      anchorExact: bookmark.anchorExact,
      anchorPrefix: bookmark.anchorPrefix,
      anchorSuffix: bookmark.anchorSuffix,
      anchorSectionIndex: bookmark.anchorSectionIndex,
      anchorSectionPage: bookmark.anchorSectionPage,
    );
    if (existing != null) return existing;
    bookmarksBySourceId.update(
      bookmark.sourceId,
      (items) => [...items, bookmark],
      ifAbsent: () => [bookmark],
    );
    return bookmark;
  }

  SourceBookmark? _bookmarkAt({
    required String sourceId,
    required String cfi,
    String? anchorExact,
    String? anchorPrefix,
    String? anchorSuffix,
    int? anchorSectionIndex,
    int? anchorSectionPage,
  }) => (bookmarksBySourceId[sourceId] ?? []).where((bookmark) {
    if (bookmark.cfi != cfi) return false;
    if (anchorExact == null &&
        anchorPrefix == null &&
        anchorSuffix == null &&
        anchorSectionIndex == null &&
        anchorSectionPage == null) {
      return true;
    }
    return (bookmark.anchorExact ?? '') == (anchorExact ?? '') &&
        (bookmark.anchorPrefix ?? '') == (anchorPrefix ?? '') &&
        (bookmark.anchorSuffix ?? '') == (anchorSuffix ?? '') &&
        (bookmark.anchorSectionIndex ?? -1) == (anchorSectionIndex ?? -1) &&
        (bookmark.anchorSectionPage ?? -1) == (anchorSectionPage ?? -1);
  }).firstOrNull;
}
