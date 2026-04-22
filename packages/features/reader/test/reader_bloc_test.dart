import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  late FakeBookRepository bookRepository;
  late FakeArticleRepository articleRepository;
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

  final testArticle = Article(
    id: 'article-1',
    title: 'Test Article',
    url: 'https://example.com/article',
    contentPath: '/articles/article-1.html',
    addedAt: DateTime(2024, 1, 1),
    siteName: 'Example',
    currentScrollOffset: 0.5,
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
    articleRepository = FakeArticleRepository();
    highlightRepository = FakeHighlightRepository();
  });

  ReaderBloc buildBloc() => ReaderBloc(
    bookRepository: bookRepository,
    articleRepository: articleRepository,
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
        expect(bloc.state.article, isNull);
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
              .having((s) => s.sourceType, 'sourceType', SourceType.book)
              .having((s) => s.title, 'title', 'Test Book')
              .having((s) => s.book, 'book', isNotNull)
              .having((s) => s.highlights, 'highlights', hasLength(1)),
        ],
        verify: (_) {
          // Should have updated lastOpenedAt
          expect(bookRepository.updatedBook, isNotNull);
          expect(bookRepository.updatedBook!.lastOpenedAt, isNotNull);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'loads article by ID when no book matches',
        setUp: () {
          articleRepository.seedArticle(
            testArticle,
            content: '<p>Hello from disk</p>',
          );
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'article-1')),
        expect: () => [
          const ReaderState(status: ReaderStatus.loading),
          isA<ReaderState>()
              .having((s) => s.status, 'status', ReaderStatus.ready)
              .having((s) => s.sourceType, 'sourceType', SourceType.article)
              .having((s) => s.title, 'title', 'Test Article')
              .having((s) => s.article, 'article', isNotNull),
        ],
        verify: (_) {
          expect(articleRepository.updatedArticle, isNotNull);
          expect(articleRepository.updatedArticle!.lastOpenedAt, isNotNull);
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
        'prefers book when both a book and an article match the same id',
        // Books win over articles by ordering in the parallel resolver.
        // Guards the invariant: id collisions load the book, not the article.
        setUp: () {
          bookRepository.seedBook(testBook);
          articleRepository.seedArticle(
            Article(
              id: testBook.id,
              title: 'Collider',
              url: 'https://example.com/collider',
              contentPath: '/articles/collider.html',
              addedAt: DateTime(2024, 1, 1),
            ),
          );
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(ReaderSourceLoadRequested(sourceId: testBook.id)),
        verify: (bloc) {
          expect(bloc.state.sourceType, SourceType.book);
          expect(bloc.state.book, isNotNull);
          expect(bloc.state.article, isNull);
        },
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
          sourceType: SourceType.book,
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
        verify: (_) => expect(bookRepository.updatedBook, isNull),
      );
    });

    group('ReaderArticlePositionUpdated', () {
      blocTest<ReaderBloc, ReaderState>(
        'updates article scroll offset',
        setUp: () {
          articleRepository.seedArticle(testArticle);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          sourceType: SourceType.article,
          title: testArticle.title,
          article: testArticle,
        ),
        act: (bloc) => bloc.add(
          const ReaderArticlePositionUpdated(scrollOffset: 0.75),
        ),
        wait: const Duration(seconds: 3),
        verify: (_) {
          expect(articleRepository.updatedArticle, isNotNull);
          expect(articleRepository.updatedArticle!.currentScrollOffset, 0.75);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'no-op when no article in state',
        build: buildBloc,
        seed: () => const ReaderState(status: ReaderStatus.ready),
        act: (bloc) => bloc.add(
          const ReaderArticlePositionUpdated(scrollOffset: 0.75),
        ),
        wait: const Duration(seconds: 3),
        verify: (_) => expect(articleRepository.updatedArticle, isNull),
      );
    });

    group('ReaderHighlightsRefreshed', () {
      blocTest<ReaderBloc, ReaderState>(
        'refetches highlights for current source',
        setUp: () {
          highlightRepository.seedHighlights('book-1', [testHighlight]);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          sourceType: SourceType.book,
          book: testBook,
        ),
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
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          sourceType: SourceType.book,
          book: testBook,
        ),
        act: (bloc) => bloc.add(const ReaderHighlightsRefreshed()),
        expect: () => <ReaderState>[],
        errors: () => [isA<Exception>()],
      );
    });

    group('ReaderState computed', () {
      test('sourceId returns book id', () {
        final state = ReaderState(book: testBook);
        expect(state.sourceId, 'book-1');
      });

      test('sourceId returns article id', () {
        final state = ReaderState(article: testArticle);
        expect(state.sourceId, 'article-1');
      });

      test('isBook returns true for book sourceType', () {
        const state = ReaderState(sourceType: SourceType.book);
        expect(state.isBook, isTrue);
        expect(state.isArticle, isFalse);
      });

      test('isArticle returns true for article sourceType', () {
        const state = ReaderState(sourceType: SourceType.article);
        expect(state.isArticle, isTrue);
        expect(state.isBook, isFalse);
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
