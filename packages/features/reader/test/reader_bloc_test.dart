import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:shared/shared.dart';

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
    cleanedHtml: '<p>Content</p>',
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
        expect(bloc.state.hasSelection, isFalse);
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
          articleRepository.seedArticle(testArticle);
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
        'emits failure when repository throws',
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
      );
    });

    group('ReaderPositionUpdated', () {
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
          const ReaderPositionUpdated(location: 200, progress: 0.2),
        ),
        verify: (_) {
          expect(bookRepository.updatedBook, isNotNull);
          expect(bookRepository.updatedBook!.currentLocation, 200);
          expect(bookRepository.updatedBook!.readingProgress, 0.2);
        },
      );

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
          const ReaderPositionUpdated(scrollOffset: 0.75),
        ),
        verify: (_) {
          expect(articleRepository.updatedArticle, isNotNull);
          expect(articleRepository.updatedArticle!.currentScrollOffset, 0.75);
        },
      );
    });

    group('ReaderTextSelected / Deselected', () {
      blocTest<ReaderBloc, ReaderState>(
        'text selected updates selection state',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const ReaderTextSelected(
            selectedText: 'Some text',
            cfiRange: 'epubcfi(/6/4)',
            pageNumber: 42,
          ),
        ),
        expect: () => [
          isA<ReaderState>()
              .having((s) => s.hasSelection, 'hasSelection', isTrue)
              .having((s) => s.selectedText, 'selectedText', 'Some text')
              .having((s) => s.selectionCfiRange, 'cfiRange', 'epubcfi(/6/4)')
              .having((s) => s.selectionPageNumber, 'pageNumber', 42),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'text deselected clears selection',
        build: buildBloc,
        seed: () => const ReaderState(
          selectedText: 'Some text',
          hasSelection: true,
        ),
        act: (bloc) => bloc.add(const ReaderTextDeselected()),
        expect: () => [
          isA<ReaderState>().having(
            (s) => s.hasSelection,
            'hasSelection',
            isFalse,
          ),
        ],
      );
    });

    group('Review reminder', () {
      blocTest<ReaderBloc, ReaderState>(
        'show review reminder',
        build: buildBloc,
        act: (bloc) => bloc.add(const ReaderReviewReminderShown()),
        expect: () => [
          isA<ReaderState>().having(
            (s) => s.showReviewReminder,
            'showReviewReminder',
            isTrue,
          ),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'dismiss review reminder',
        build: buildBloc,
        seed: () => const ReaderState(showReviewReminder: true),
        act: (bloc) => bloc.add(const ReaderReviewReminderDismissed()),
        expect: () => [
          isA<ReaderState>().having(
            (s) => s.showReviewReminder,
            'showReviewReminder',
            isFalse,
          ),
        ],
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
    });
  });
}
