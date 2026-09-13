import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

Book _book() => Book(
  id: 'book',
  title: 'Book',
  filePath: '/books/book.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026),
  readingProgress: 0.1,
);

class _DelayedLoadRepository extends FakeBookRepository {
  final loading = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<Book?> getBookById(String id) async {
    final snapshot = await super.getBookById(id);
    if (!loading.isCompleted) {
      loading.complete();
      await gate.future;
    }
    return snapshot;
  }
}

class _DelayedWriteRepository extends FakeBookRepository {
  _DelayedWriteRepository({required this.failFirstWrite});

  final bool failFirstWrite;
  final writing = Completer<void>();
  final gate = Completer<void>();

  @override
  Future<Book> updateBook(Book book) async {
    if (!writing.isCompleted) {
      writing.complete();
      await gate.future;
      if (failFirstWrite) throw StateError('First write failed');
    }
    return super.updateBook(book);
  }
}

class _DelayedHighlightRepository extends FakeHighlightRepository {
  final writing = Completer<void>();
  final gate = Completer<void>();
  int reads = 0;
  bool failFirstColor = false;

  @override
  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    reads++;
    return super.getHighlightsBySource(sourceId);
  }

  @override
  Future<void> updateHighlightColor(String id, HighlightColor color) async {
    if (!writing.isCompleted) {
      writing.complete();
      await gate.future;
      if (failFirstColor) throw StateError('Color write failed');
    }
    await super.updateHighlightColor(id, color);
  }
}

Highlight _highlight() => Highlight(
  id: 'highlight',
  sourceId: 'book',
  sourceType: SourceType.book,
  text: 'Words',
  note: 'Old note',
  createdAt: DateTime(2026),
);

void main() {
  setUp(() {
    final previous = Bloc.transformer;
    Bloc.transformer = (events, mapper) => events.asyncExpand(mapper);
    addTearDown(() => Bloc.transformer = previous);
  });

  for (final failFirstColor in [false, true]) {
    test(
      'highlight edits are ordered without blocking position (failure=$failFirstColor)',
      () async {
        final books = FakeBookRepository()..seedBook(_book());
        final highlights = _DelayedHighlightRepository()
          ..failFirstColor = failFirstColor
          ..seedHighlights('book', [_highlight()]);
        final bloc = ReaderBloc(
          bookRepository: books,
          highlightRepository: highlights,
          initialSource: _book(),
        );
        addTearDown(bloc.close);
        addTearDown(() {
          if (!highlights.gate.isCompleted) highlights.gate.complete();
        });
        final loaded = bloc.stream.firstWhere(
          (state) => state.highlights.isNotEmpty,
        );
        bloc.add(const ReaderHighlightsRefreshed());
        await loaded;
        final originalHighlights = bloc.state.highlights;
        bloc.add(
          const ReaderHighlightColorChangeRequested(
            highlightId: 'highlight',
            color: HighlightColor.blue,
          ),
        );
        await highlights.writing.future;
        bloc.add(
          const ReaderHighlightNoteChangeRequested(
            highlightId: 'highlight',
            note: 'New note',
          ),
        );
        bloc.add(
          const ReaderHighlightColorChangeRequested(
            highlightId: 'highlight',
            color: HighlightColor.yellow,
          ),
        );
        final moved = bloc.stream.firstWhere(
          (state) => state.document?.currentCfi == 'position-100',
        );
        for (var i = 1; i <= 100; i++) {
          bloc.add(
            ReaderBookPositionUpdated(
              cfi: 'position-$i',
              progress: 0.1 + i / 1000,
            ),
          );
        }
        await moved;
        expect(bloc.state.highlights, same(originalHighlights));
        expect(
          highlights.reads,
          1,
          reason: 'Position events must not reload annotations',
        );
        expect(
          bloc.state.highlightEffect,
          isNull,
          reason: 'Storage has not completed',
        );
        final finished = bloc.stream.firstWhere(
          (state) => state.highlightEffect?.version == (failFirstColor ? 2 : 3),
        );
        highlights.gate.complete();
        await finished;
        expect(
          bloc.state.highlights.single,
          _highlight().copyWith(note: 'New note'),
        );
        expect(highlights.reads, failFirstColor ? 2 : 4);
        expect(highlights.updatedHighlights, hasLength(failFirstColor ? 1 : 3));
        await bloc.close();
        expect(books.updatedBook?.currentCfi, 'position-100');
        expect(
          books.updateCallCount,
          1,
          reason: 'Burst still collapses into one position write',
        );
      },
    );
  }

  test(
    'a source reload cannot restore highlights captured before an edit',
    () async {
      final books = _DelayedLoadRepository()..seedBook(_book());
      final highlights = FakeHighlightRepository()
        ..seedHighlights('book', [_highlight()]);
      final bloc = ReaderBloc(
        bookRepository: books,
        highlightRepository: highlights,
        initialSource: _book(),
      );
      addTearDown(bloc.close);
      addTearDown(() {
        if (!books.gate.isCompleted) books.gate.complete();
      });
      final initial = bloc.stream.firstWhere(
        (state) => state.highlights.isNotEmpty,
      );
      bloc.add(const ReaderHighlightsRefreshed());
      await initial;
      bloc.add(const ReaderSourceLoadRequested(sourceId: 'book'));
      await books.loading.future;
      final edited = bloc.stream.firstWhere(
        (state) => state.highlightEffect != null,
      );
      bloc.add(
        const ReaderHighlightNoteChangeRequested(
          highlightId: 'highlight',
          note: 'New note',
        ),
      );
      await edited;
      final loaded = bloc.stream.firstWhere(
        (state) => state.document?.lastOpenedAt != null,
      );
      books.gate.complete();
      await loaded;
      expect(bloc.state.highlights.single.note, 'New note');
    },
  );

  test('closing the reader drains queued annotation edits', () async {
    final highlights = _DelayedHighlightRepository()
      ..seedHighlights('book', [_highlight()]);
    final bloc = ReaderBloc(
      bookRepository: FakeBookRepository(),
      highlightRepository: highlights,
      initialSource: _book(),
    );
    addTearDown(bloc.close);
    addTearDown(() {
      if (!highlights.gate.isCompleted) highlights.gate.complete();
    });
    final loaded = bloc.stream.firstWhere(
      (state) => state.highlights.isNotEmpty,
    );
    bloc.add(const ReaderHighlightsRefreshed());
    await loaded;
    bloc.add(
      const ReaderHighlightColorChangeRequested(
        highlightId: 'highlight',
        color: HighlightColor.blue,
      ),
    );
    await highlights.writing.future;
    bloc.add(
      const ReaderHighlightNoteChangeRequested(
        highlightId: 'highlight',
        note: 'New note',
      ),
    );
    final closing = bloc.close();
    highlights.gate.complete();
    await closing;
    expect(
      highlights.highlightsBySourceId['book']!.single,
      _highlight().copyWith(color: HighlightColor.blue, note: 'New note'),
    );
  });

  test(
    'source load preserves a newer live position and opened timestamp',
    () async {
      final repo = _DelayedLoadRepository()..seedBook(_book());
      final bloc = ReaderBloc(
        bookRepository: repo,
        highlightRepository: FakeHighlightRepository(),
        initialSource: _book(),
      );
      addTearDown(bloc.close);
      bloc.add(const ReaderSourceLoadRequested(sourceId: 'book'));
      await repo.loading.future;
      final moved = bloc.stream.firstWhere(
        (s) => s.document?.readingProgress == 0.7,
      );
      bloc.add(
        const ReaderBookPositionUpdated(cfi: 'latest-position', progress: 0.7),
      );
      await moved;
      const features = ReaderDocumentFeatures(
        format: 'epub',
        hasSearchableText: true,
      );
      final featuresReceived = bloc.stream.firstWhere(
        (s) => s.documentFeatures == features,
      );
      bloc.add(const ReaderDocumentFeaturesUpdated(features: features));
      await featuresReceived;
      final loaded = bloc.stream.firstWhere(
        (s) => s.document?.lastOpenedAt != null,
      );
      repo.gate.complete();
      await loaded;
      expect(bloc.state.document!.readingProgress, 0.7);
      expect(bloc.state.document!.currentCfi, 'latest-position');
      expect(bloc.state.documentFeatures, same(features));
      await bloc.close();
      expect(repo.updatedBook!.readingProgress, 0.7);
      expect(repo.updatedBook!.lastOpenedAt, isNotNull);
    },
  );

  for (final failFirstWrite in [false, true]) {
    test(
      'close drains pending position after an active ${failFirstWrite ? 'failed' : 'successful'} write',
      () async {
        final repo = _DelayedWriteRepository(failFirstWrite: failFirstWrite)
          ..seedBook(_book());
        final bloc = ReaderBloc(
          bookRepository: repo,
          highlightRepository: FakeHighlightRepository(),
          initialSource: _book(),
        );
        bloc.add(const ReaderBookPositionUpdated(cfi: 'first', progress: 0.4));
        await repo.writing.future;
        expect(repo.writing.isCompleted, isTrue);
        final moved = bloc.stream.firstWhere(
          (state) => state.document?.readingProgress == 0.7,
        );
        bloc.add(const ReaderBookPositionUpdated(cfi: 'latest', progress: 0.7));
        await moved;
        var closed = false;
        final closing = bloc.close().then((_) => closed = true);
        await Future<void>.delayed(Duration.zero);
        final closedBeforeWrite = closed;
        repo.gate.complete();
        await closing;
        expect(closedBeforeWrite, isFalse);
        expect(repo.updatedBook!.currentCfi, 'latest');
        expect(repo.updatedBook!.readingProgress, 0.7);
        expect(repo.updateCallCount, failFirstWrite ? 1 : 2);
      },
    );
  }

  test('failed retry leaves loading and a later retry can succeed', () async {
    final repo = FakeBookRepository()..seedBook(_book());
    final bloc = ReaderBloc(
      bookRepository: repo,
      highlightRepository: FakeHighlightRepository(),
      initialSource: _book(),
    );
    addTearDown(bloc.close);
    final failed = bloc.stream.firstWhere(
      (s) => s.status == ReaderStatus.failure,
    );
    bloc.add(
      const ReaderWebViewFailed(
        sourceId: 'book',
        failure: ReaderLoadFailure(ReaderLoadFailureKind.document),
      ),
    );
    await failed;
    repo.shouldThrow = true;
    final retry = bloc.stream.take(2).toList();
    bloc.add(const ReaderSourceLoadRequested(sourceId: 'book'));
    expect(
      (await retry.timeout(const Duration(seconds: 3))).map((s) => s.status),
      [ReaderStatus.loading, ReaderStatus.failure],
    );
    repo.shouldThrow = false;
    final ready = bloc.stream.firstWhere((s) => s.status == ReaderStatus.ready);
    bloc.add(const ReaderSourceLoadRequested(sourceId: 'book'));
    await ready;
  });

  test('a pending source load cannot clear a WebView failure', () async {
    final repo = _DelayedLoadRepository()..seedBook(_book());
    final bloc = ReaderBloc(
      bookRepository: repo,
      highlightRepository: FakeHighlightRepository(),
      initialSource: _book(),
    );
    addTearDown(bloc.close);
    bloc.add(const ReaderSourceLoadRequested(sourceId: 'book'));
    await repo.loading.future;
    final failed = bloc.stream.firstWhere(
      (s) => s.status == ReaderStatus.failure,
    );
    bloc.add(
      const ReaderWebViewFailed(
        sourceId: 'book',
        failure: ReaderLoadFailure(ReaderLoadFailureKind.rendererTerminated),
      ),
    );
    await failed;
    repo.gate.complete();
    await bloc.close();
    expect(bloc.state.status, ReaderStatus.failure);
    expect(repo.updateCallCount, 0);
  });
}
