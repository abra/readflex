import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';

import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  late FakeBookRepository bookRepository;
  late FakeHighlightRepository highlightRepository;

  final testBook = Book(
    id: 'book-1',
    title: 'Test Book',
    filePath: '/books/test.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2024, 1, 1),
    author: 'Author',
    totalLocations: 1000,
    currentLocation: 100,
    readingProgress: 0.1,
  );

  final testHighlight = Highlight(
    id: 'h-1',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    text: 'Highlighted text',
    createdAt: DateTime(2024, 1, 2),
  );

  setUp(() {
    bookRepository = FakeBookRepository();
    highlightRepository = FakeHighlightRepository();
  });

  ReaderBloc buildBloc() => ReaderBloc(
    bookRepository: bookRepository,
    highlightRepository: highlightRepository,
  );

  group('ReaderBloc', () {
    blocTest<ReaderBloc, ReaderState>(
      'initial state has initial status',
      build: buildBloc,
      verify: (bloc) {
        expect(bloc.state.status, ReaderStatus.initial);
        expect(bloc.state.title, '');
        expect(bloc.state.book, isNull);
      },
    );

    group('ReaderSourceLoadRequested', () {
      blocTest<ReaderBloc, ReaderState>(
        'loads book by ID',
        setUp: () {
          bookRepository.seedBook(testBook);
          highlightRepository.seedHighlights('book-1', [testHighlight]);
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'book-1')),
        expect: () => [
          const ReaderState(status: ReaderStatus.loading),
          isA<ReaderState>()
              .having((s) => s.status, 'status', ReaderStatus.ready)
              .having((s) => s.title, 'title', 'Test Book')
              .having((s) => s.book, 'book', isNotNull)
              .having((s) => s.highlights, 'highlights', hasLength(1)),
        ],
        verify: (_) {
          expect(bookRepository.updatedBook, isNotNull);
          expect(bookRepository.updatedBook!.lastOpenedAt, isNotNull);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'emits failure when source not found',
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'unknown')),
        expect: () => [
          const ReaderState(status: ReaderStatus.loading),
          const ReaderState(status: ReaderStatus.failure),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'emits failure AND reports error when repository throws',
        setUp: () {
          bookRepository.shouldThrow = true;
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'book-1')),
        expect: () => [
          const ReaderState(status: ReaderStatus.loading),
          const ReaderState(status: ReaderStatus.failure),
        ],
        // Must reach AppBlocObserver / error reporter — a silent failure
        // swallows stacktrace and blinds observability.
        errors: () => hasLength(1),
      );
    });

    group('ReaderBookPositionUpdated', () {
      blocTest<ReaderBloc, ReaderState>(
        'updates book position',
        setUp: () {
          bookRepository.seedBook(testBook);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook,
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/2)',
            progress: 0.2,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (_) {
          expect(bookRepository.updatedBook, isNotNull);
          expect(
            bookRepository.updatedBook!.currentCfi,
            'epubcfi(/6/4!/4/2)',
          );
          expect(bookRepository.updatedBook!.readingProgress, 0.2);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'clamps progress > 1.0 to 1.0',
        setUp: () {
          bookRepository.seedBook(testBook);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook,
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/2)',
            progress: 1.05,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (_) {
          expect(bookRepository.updatedBook!.readingProgress, 1.0);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'no-op when no book in state',
        build: buildBloc,
        seed: () => const ReaderState(status: ReaderStatus.ready),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/2)',
            progress: 0.2,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (_) {
          expect(bookRepository.updatedBook, isNull);
        },
      );
    });

    group('ReaderHighlightsRefreshed', () {
      blocTest<ReaderBloc, ReaderState>(
        'refetches highlights for current source',
        setUp: () {
          highlightRepository.seedHighlights('book-1', [testHighlight]);
        },
        build: buildBloc,
        seed: () => ReaderState(status: ReaderStatus.ready, book: testBook),
        act: (bloc) => bloc.add(const ReaderHighlightsRefreshed()),
        expect: () => [
          isA<ReaderState>().having(
            (s) => s.highlights,
            'highlights',
            hasLength(1),
          ),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'emits nothing when no source loaded',
        build: buildBloc,
        act: (bloc) => bloc.add(const ReaderHighlightsRefreshed()),
        expect: () => <ReaderState>[],
      );

      blocTest<ReaderBloc, ReaderState>(
        'reports error when repository throws',
        setUp: () {
          highlightRepository.shouldThrow = true;
        },
        build: buildBloc,
        seed: () => ReaderState(status: ReaderStatus.ready, book: testBook),
        act: (bloc) => bloc.add(const ReaderHighlightsRefreshed()),
        expect: () => <ReaderState>[],
        errors: () => [isA<Exception>()],
      );

      // The reader screen subscribes to `state.highlights` via
      // `context.select` and relies on default `List` reference equality
      // to detect changes — `copyWith` must hand back a fresh list
      // instance, otherwise the selector won't fire and newly created
      // highlights stay invisible until the reader is reopened.
      blocTest<ReaderBloc, ReaderState>(
        'emits a fresh highlights list reference (selector contract)',
        setUp: () {
          highlightRepository.seedHighlights('book-1', [testHighlight]);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          book: testBook,
          highlights: const [],
        ),
        act: (bloc) => bloc.add(const ReaderHighlightsRefreshed()),
        verify: (bloc) {
          // Sanity: state actually contains the seeded highlight.
          expect(bloc.state.highlights, hasLength(1));
          // The contract: post-refresh list must NOT be `identical` to
          // the seed's `const []` — context.select compares by `==`,
          // which for List is reference equality.
          expect(identical(bloc.state.highlights, const []), isFalse);
        },
      );
    });

    group('ReaderState computed', () {
      test('sourceId returns book id', () {
        final state = ReaderState(book: testBook);
        expect(state.sourceId, 'book-1');
      });

      test('copyWith preserves unrelated fields', () {
        final state = ReaderState(title: 'T', book: testBook);
        final copy = state.copyWith(highlights: []);
        expect(copy.title, 'T');
        expect(copy.book, testBook);
      });
    });
  });
}
