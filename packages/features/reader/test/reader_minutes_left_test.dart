import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_highlight_repository.dart';

void main() {
  final book = Book(
    id: 'book-1',
    title: 'Test Book',
    filePath: '/books/test.epub',
    format: BookFormat.epub,
    addedAt: DateTime(2024, 1, 1),
    readingProgress: 0.1,
  );
  final article = Article(
    id: 'article-1',
    title: 'Saved Article',
    url: 'https://example.com/article',
    siteName: 'Example',
    contentPath: '/articles/article-1/article.json',
    addedAt: DateTime(2024, 1, 1),
  );
  late FakeBookRepository bookRepository;
  late FakeArticleRepository articleRepository;

  setUp(() {
    bookRepository = FakeBookRepository()..seedBook(book);
    articleRepository = FakeArticleRepository()..seedArticle(article);
  });

  ReaderBloc buildBloc() => ReaderBloc(
    bookRepository: bookRepository,
    articleRepository: articleRepository,
    highlightRepository: FakeHighlightRepository(),
  );

  ReaderState bookState() => ReaderState(
    status: ReaderStatus.ready,
    title: book.title,
    document: ReaderDocument.fromBook(book),
  );

  group('ReaderBookPositionUpdated.fromBookPosition', () {
    test('maps a book relocation; books carry no estimate', () {
      final event = ReaderBookPositionUpdated.fromBookPosition(
        BookPosition.fromMap({
          'cfi': 'epubcfi(/6/4!/4/2)',
          'percentage': 0.35,
          'chapterTitle': 'Chapter 1',
          'chapterCurrentPage': 5,
          'chapterTotalPages': 20,
          'bookCurrentPage': 84,
          'bookTotalPages': 200,
          'sizeTotal': 480000,
          'pageProgressionDirection': 'rtl',
          'atStart': false,
          'atEnd': false,
          // A former book payload key, now ignored.
          'sectionMinutesLeft': 6.5,
          'bookmark': {'exists': true, 'cfi': 'epubcfi(/6/4)', 'id': 'bm'},
        }),
      );

      expect(
        event,
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.35,
          chapterTitle: 'Chapter 1',
          chapterCurrentPage: 5,
          chapterTotalPages: 20,
          bookCurrentPage: 84,
          bookTotalPages: 200,
          sizeTotal: 480000,
          pageProgressionRtl: true,
          currentPageBookmarked: true,
          currentPageBookmarkCfi: 'epubcfi(/6/4)',
          currentPageBookmarkId: 'bm',
        ),
      );
    });

    test('maps an article position: minutes left, no page metrics', () {
      final event = ReaderBookPositionUpdated.fromBookPosition(
        BookPosition.fromMap({
          'cfi': 'readflex-html-position:abc',
          'percentage': 0.4,
          'chapterTitle': 'Intro',
          'reason': 'scroll',
          'atStart': false,
          'atEnd': false,
          'minutesLeft': 11.25,
          'bookmark': {'exists': false},
        }),
      );

      expect(
        event,
        const ReaderBookPositionUpdated(
          cfi: 'readflex-html-position:abc',
          progress: 0.4,
          chapterTitle: 'Intro',
          minutesLeft: 11.25,
        ),
      );
    });

    test('an invalid estimate maps to null', () {
      final event = ReaderBookPositionUpdated.fromBookPosition(
        BookPosition.fromMap({
          'cfi': 'epubcfi(/6/4)',
          'percentage': 0.2,
          'minutesLeft': -3,
        }),
      );
      expect(event.minutesLeft, isNull);
    });
  });

  group('minutesLeft', () {
    blocTest<ReaderBloc, ReaderState>(
      'is carried into state',
      build: buildBloc,
      seed: bookState,
      act: (bloc) => bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.2,
          minutesLeft: 7.5,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.minutesLeft, 7.5),
    );

    blocTest<ReaderBloc, ReaderState>(
      'a change of the estimate alone emits',
      build: buildBloc,
      seed: () => bookState().copyWith(
        document: ReaderDocument.fromBook(
          book,
        ).copyWith(currentCfi: 'epubcfi(/6/4!/4/2)', readingProgress: 0.2),
        minutesLeft: 7.5,
      ),
      act: (bloc) => bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.2,
          minutesLeft: 3,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => [
        isA<ReaderState>().having(
          (s) => s.minutesLeft,
          'minutesLeft',
          3,
        ),
      ],
    );

    blocTest<ReaderBloc, ReaderState>(
      'an unchanged estimate does not emit',
      build: buildBloc,
      seed: () => bookState().copyWith(
        document: ReaderDocument.fromBook(
          book,
        ).copyWith(currentCfi: 'epubcfi(/6/4!/4/2)', readingProgress: 0.2),
        minutesLeft: 7.5,
      ),
      act: (bloc) => bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/4!/4/2)',
          progress: 0.2,
          minutesLeft: 7.5,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      expect: () => <ReaderState>[],
    );

    blocTest<ReaderBloc, ReaderState>(
      'a missing estimate clears the previous one',
      build: buildBloc,
      seed: () => bookState().copyWith(minutesLeft: 7.5),
      act: (bloc) => bloc.add(
        const ReaderBookPositionUpdated(
          cfi: 'epubcfi(/6/6!/4/2)',
          progress: 0.3,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.minutesLeft, isNull),
    );

    blocTest<ReaderBloc, ReaderState>(
      'articles carry minutes left in the article',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(ReaderSourceLoadRequested(sourceId: article.id));
        await bloc.stream.firstWhere((s) => s.status == ReaderStatus.ready);
        bloc.add(
          ReaderBookPositionUpdated.fromBookPosition(
            BookPosition.fromMap({
              'cfi': 'readflex-html-position:abc',
              'percentage': 0.4,
              'minutesLeft': 9.5,
            }),
          ),
        );
      },
      wait: const Duration(milliseconds: 100),
      verify: (bloc) {
        expect(bloc.state.sourceType, SourceType.article);
        expect(bloc.state.minutesLeft, 9.5);
      },
    );

    blocTest<ReaderBloc, ReaderState>(
      'a delayed source reload keeps the live estimate',
      build: () => ReaderBloc(
        bookRepository: bookRepository,
        highlightRepository: FakeHighlightRepository(),
        initialSource: book,
      ),
      act: (bloc) async {
        bloc.add(ReaderSourceLoadRequested(sourceId: book.id));
        bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/2)',
            progress: 0.2,
            minutesLeft: 4,
          ),
        );
      },
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.status, ReaderStatus.ready);
        expect(bloc.state.minutesLeft, 4);
      },
    );
  });

  test('ReaderState.copyWith keeps or clears minutesLeft', () {
    const state = ReaderState(minutesLeft: 2);
    expect(state.copyWith().minutesLeft, 2);
    expect(state.copyWith(minutesLeft: null).minutesLeft, isNull);
    expect(state.copyWith(minutesLeft: 5.0).minutesLeft, 5);
    expect(state, isNot(const ReaderState(minutesLeft: 3)));
  });
}
