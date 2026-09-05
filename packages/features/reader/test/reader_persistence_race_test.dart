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

void main() {
  setUp(() {
    final previous = Bloc.transformer;
    Bloc.transformer = (events, mapper) => events.asyncExpand(mapper);
    addTearDown(() => Bloc.transformer = previous);
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
