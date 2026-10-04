import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  final book = Book(
    id: 'book',
    title: 'Book',
    filePath: '/book.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2026),
  );
  final bookmark = SourceBookmark(
    id: 'saved',
    sourceId: book.id,
    sourceType: SourceType.book,
    cfi: 'epubcfi(/6/2)',
    content: 'Original page',
    progress: .3,
    createdAt: DateTime(2025),
    chapterTitle: 'Chapter',
    anchorExact: 'Original page',
    anchorSectionIndex: 1,
    anchorSectionPage: 3,
  );
  late FakeBookRepository repository;
  late ReaderBloc bloc;

  Future<ReaderState> send(
    ReaderEvent event,
    bool Function(ReaderState) matches,
  ) {
    final result = bloc.stream
        .firstWhere(matches)
        .timeout(const Duration(seconds: 3));
    bloc.add(event);
    return result;
  }

  setUp(() async {
    repository = FakeBookRepository()
      ..seedBook(book)
      ..seedBookmarks(book.id, [bookmark]);
    bloc = ReaderBloc(
      bookRepository: repository,
      highlightRepository: FakeHighlightRepository(),
      initialSource: book,
    );
    await send(
      ReaderSourceLoadRequested(sourceId: book.id),
      (s) => s.bookmarks.isNotEmpty,
    );
  });
  tearDown(() => bloc.close());

  test(
    'delete persists immediately; undo restores exact identity and anchor',
    () async {
      await send(
        ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id),
        (s) => s.bookmarkEdits.removed.isNotEmpty,
      );
      expect(bloc.state.bookmarks, isEmpty);
      expect(repository.bookmarksBySourceId[book.id], isEmpty);
      expect(bloc.state.bookmarkEdits.removed, [bookmark]);
      await send(
        ReaderBookmarkRestored(sourceId: book.id, id: bookmark.id),
        (s) => s.bookmarks.isNotEmpty,
      );
      expect(bloc.state.bookmarks, [bookmark]);
      expect(repository.bookmarksBySourceId[book.id], [bookmark]);
      expect(bloc.state.bookmarkEdits.removed, isEmpty);
    },
  );

  test('delete failure retains row and reports recoverable error', () async {
    repository.shouldThrow = true;
    await send(
      ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id),
      (s) => s.bookmarkEdits.failedId != null,
    );
    expect(bloc.state.bookmarks, [bookmark]);
    expect(bloc.state.bookmarkEdits.removed, isEmpty);
    expect(bloc.state.bookmarkEdits.busyId, isNull);
  });

  test('restore failure retains undo and can be retried', () async {
    await send(
      ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id),
      (s) => s.bookmarkEdits.removed.isNotEmpty,
    );
    repository.shouldThrow = true;
    await send(
      ReaderBookmarkRestored(sourceId: book.id, id: bookmark.id),
      (s) => s.bookmarkEdits.failedId != null,
    );
    expect(bloc.state.bookmarkEdits.removed, [bookmark]);
    repository.shouldThrow = false;
    await send(
      ReaderBookmarkRestored(sourceId: book.id, id: bookmark.id),
      (s) => s.bookmarks.isNotEmpty,
    );
    expect(bloc.state.bookmarkEdits.failedId, isNull);
  });

  test(
    'closing Contents clears undo after pending deletion, not persistence',
    () async {
      final cleared = bloc.stream.firstWhere(
        (s) =>
            s.bookmarks.isEmpty &&
            s.bookmarkEdits.busyId == null &&
            s.bookmarkEdits.removed.isEmpty,
      );
      bloc.add(ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id));
      bloc.add(const ReaderBookmarkUndoDismissed());
      await cleared;
      expect(repository.bookmarksBySourceId[book.id], isEmpty);
    },
  );

  test(
    'multiple deletions can be undone independently in either order',
    () async {
      final second = SourceBookmark(
        id: 'second',
        sourceId: book.id,
        sourceType: SourceType.book,
        cfi: 'epubcfi(/6/4)',
        content: 'Second page',
        progress: .6,
        createdAt: DateTime(2026),
      );
      repository.seedBookmarks(book.id, [bookmark, second]);
      await send(
        ReaderSourceLoadRequested(sourceId: book.id),
        (s) => s.bookmarks.length == 2,
      );
      await send(
        ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id),
        (s) => s.bookmarkEdits.removed.length == 1,
      );
      await send(
        ReaderBookmarkDeleted(sourceId: book.id, id: second.id),
        (s) => s.bookmarkEdits.removed.length == 2,
      );
      await send(
        ReaderBookmarkRestored(sourceId: book.id, id: bookmark.id),
        (s) => s.bookmarks.length == 1,
      );
      expect(bloc.state.bookmarkEdits.removed, [second]);
      await send(
        ReaderBookmarkRestored(sourceId: book.id, id: second.id),
        (s) => s.bookmarks.length == 2,
      );
      expect(bloc.state.bookmarks, [bookmark, second]);
      expect(bloc.state.bookmarkEdits.removed, isEmpty);
    },
  );

  test(
    'duplicate and foreign-source operations cannot add duplicate rows',
    () async {
      bloc.add(const ReaderBookmarkDeleted(sourceId: 'other', id: 'saved'));
      bloc.add(ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id));
      await send(
        ReaderBookmarkDeleted(sourceId: book.id, id: bookmark.id),
        (s) => s.bookmarkEdits.removed.isNotEmpty,
      );
      expect(bloc.state.bookmarkEdits.removed, [bookmark]);
      bloc.add(ReaderBookmarkRestored(sourceId: book.id, id: bookmark.id));
      await send(
        ReaderBookmarkRestored(sourceId: book.id, id: bookmark.id),
        (s) => s.bookmarks.isNotEmpty,
      );
      expect(repository.bookmarksBySourceId[book.id], [bookmark]);
    },
  );
}
