import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_bloc.dart';
import 'package:reader_webview/reader_webview.dart';

import 'helpers/fake_article_repository.dart';
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

  final testBookmark = SourceBookmark(
    id: 'bm-1',
    sourceId: 'book-1',
    sourceType: SourceType.book,
    cfi: 'epubcfi(/6/4)',
    content: 'Saved page',
    progress: 0.2,
    chapterTitle: 'Chapter 1',
    anchorExact: 'Saved page anchor',
    anchorSectionIndex: 12,
    anchorSectionPage: 1,
    createdAt: DateTime(2024, 1, 3),
  );

  setUp(() {
    bookRepository = FakeBookRepository();
    highlightRepository = FakeHighlightRepository();
  });

  ReaderBloc buildBloc() => ReaderBloc(
    bookRepository: bookRepository,
    highlightRepository: highlightRepository,
  );

  ReaderBloc buildBlocWithInitialSource(Book source) => ReaderBloc(
    bookRepository: bookRepository,
    highlightRepository: highlightRepository,
    initialSource: source,
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

    blocTest<ReaderBloc, ReaderState>(
      'stores document feature updates',
      build: () => buildBlocWithInitialSource(testBook),
      act: (bloc) => bloc.add(
        const ReaderDocumentFeaturesUpdated(
          features: ReaderDocumentFeatures(
            format: 'pdf',
            hasSearchableText: false,
          ),
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.documentFeatures?.format, 'pdf');
        expect(bloc.state.documentFeatures?.hasSearchableText, isFalse);
      },
    );

    blocTest<ReaderBloc, ReaderState>(
      'initial source starts ready before repository refresh',
      build: () => buildBlocWithInitialSource(testBook),
      verify: (bloc) {
        expect(bloc.state.status, ReaderStatus.ready);
        expect(bloc.state.title, testBook.title);
        expect(bloc.state.book, testBook);
      },
    );

    group('ReaderSourceLoadRequested', () {
      blocTest<ReaderBloc, ReaderState>(
        'loads book by ID',
        setUp: () {
          bookRepository.seedBook(testBook);
          highlightRepository.seedHighlights('book-1', [testHighlight]);
          bookRepository.seedBookmarks('book-1', [testBookmark]);
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
              .having((s) => s.highlights, 'highlights', hasLength(1))
              .having((s) => s.bookmarks, 'bookmarks', hasLength(1)),
        ],
        verify: (_) {
          expect(bookRepository.updatedBook, isNotNull);
          expect(bookRepository.updatedBook!.lastOpenedAt, isNotNull);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'infers rtl page progression for saved articles',
        setUp: () {},
        build: () {
          final articleRepository = FakeArticleRepository();
          articleRepository.seedArticle(
            Article(
              id: 'article-rtl',
              title: 'عنوان عربي',
              url: 'https://example.com/article',
              siteName: 'Example',
              language: 'ar',
              contentPath: '/articles/article-rtl/article.json',
              addedAt: DateTime(2024, 1, 1),
            ),
          );
          return ReaderBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
            highlightRepository: highlightRepository,
          );
        },
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'article-rtl')),
        expect: () => [
          const ReaderState(status: ReaderStatus.loading),
          isA<ReaderState>()
              .having((s) => s.status, 'status', ReaderStatus.ready)
              .having((s) => s.sourceType, 'sourceType', SourceType.article)
              .having((s) => s.pageProgressionRtl, 'pageProgressionRtl', true),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'refreshes initial source without returning to loading',
        setUp: () {
          bookRepository.seedBook(testBook.copyWith(readingProgress: 0.4));
          highlightRepository.seedHighlights('book-1', [testHighlight]);
        },
        build: () => buildBlocWithInitialSource(testBook),
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'book-1')),
        expect: () => [
          isA<ReaderState>()
              .having((s) => s.status, 'status', ReaderStatus.ready)
              .having((s) => s.book?.readingProgress, 'readingProgress', 0.4)
              .having((s) => s.book?.lastOpenedAt, 'lastOpenedAt', isNotNull)
              .having((s) => s.highlights, 'highlights', hasLength(1)),
        ],
        verify: (_) {
          expect(bookRepository.updatedBook, isNotNull);
          expect(bookRepository.updatedBook!.lastOpenedAt, isNotNull);
        },
      );

      // Catalog uses `lastOpenedAt` to decide between the "New"
      // label and a progress %. The bumped value must propagate
      // into [ReaderState.book] — otherwise the next position
      // event will copyWith on a stale book and overwrite the
      // just-persisted timestamp back to null.
      blocTest<ReaderBloc, ReaderState>(
        'state.book carries the bumped lastOpenedAt',
        setUp: () {
          bookRepository.seedBook(
            testBook.copyWith(),
            // lastOpenedAt stays null so we can detect the bump.
          );
        },
        build: buildBloc,
        act: (bloc) =>
            bloc.add(const ReaderSourceLoadRequested(sourceId: 'book-1')),
        verify: (bloc) {
          expect(bloc.state.book, isNotNull);
          expect(bloc.state.book!.lastOpenedAt, isNotNull);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'a position update preserves lastOpenedAt instead of '
        'reverting it',
        setUp: () => bookRepository.seedBook(testBook),
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ReaderSourceLoadRequested(sourceId: 'book-1'));
          // Wait for state.book to land before dispatching the
          // position update (otherwise the position event finds
          // state.book == null and no-ops).
          await bloc.stream.firstWhere(
            (s) => s.status == ReaderStatus.ready,
          );
          bloc.add(
            const ReaderBookPositionUpdated(
              cfi: 'epubcfi(/6/2)',
              progress: 0.05,
            ),
          );
        },
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          // The persisted book after the position update must still
          // carry the lastOpenedAt timestamp set on open.
          expect(bookRepository.updatedBook!.lastOpenedAt, isNotNull);
          // And state.book reflects the same.
          expect(bloc.state.book?.lastOpenedAt, isNotNull);
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

      // sizeTotal is a per-book constant the slider needs to predict the
      // page number while the user drags. The first onRelocated after
      // open carries it; we cache it in state so the bottom-chrome
      // driver can read it through `context.select`.
      blocTest<ReaderBloc, ReaderState>(
        'caches sizeTotal in state when present in event',
        setUp: () => bookRepository.seedBook(testBook),
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
            sizeTotal: 480000,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.sizeTotal, 480000);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'updates page progression direction from WebView position',
        setUp: () => bookRepository.seedBook(testBook),
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
            pageProgressionRtl: true,
          ),
        ),
        wait: const Duration(milliseconds: 50),
        verify: (bloc) {
          expect(bloc.state.pageProgressionRtl, isTrue);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'emits page progression direction even when position is unchanged',
        setUp: () => bookRepository.seedBook(
          testBook.copyWith(currentCfi: 'epubcfi(/6/4)', readingProgress: 0.1),
        ),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook.copyWith(
            currentCfi: 'epubcfi(/6/4)',
            readingProgress: 0.1,
          ),
          pageProgressionRtl: false,
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4)',
            progress: 0.1,
            pageProgressionRtl: true,
          ),
        ),
        expect: () => [
          isA<ReaderState>().having(
            (s) => s.pageProgressionRtl,
            'pageProgressionRtl',
            true,
          ),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'surfaces current page bookmark state',
        setUp: () => bookRepository.seedBook(testBook),
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
            currentPageBookmarked: true,
            currentPageBookmarkCfi: 'epubcfi(/6/4)',
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.currentPageBookmarked, isTrue);
          expect(bloc.state.currentPageBookmarkCfi, 'epubcfi(/6/4)');
        },
      );

      // A position event that arrives without sizeTotal must not wipe
      // the cache — sizeTotal is constant per book, but we don't want
      // a subtle bug somewhere in the JS bridge (e.g. an early relocate
      // that races SectionProgress construction) to drop it back to null
      // and force the slider into the approximate `bookTotalPages`
      // formula for the rest of the session.
      blocTest<ReaderBloc, ReaderState>(
        'preserves cached sizeTotal when event omits it',
        setUp: () => bookRepository.seedBook(testBook),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook,
          sizeTotal: 480000,
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/4)',
            progress: 0.3,
            // sizeTotal intentionally absent.
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.sizeTotal, 480000);
        },
      );

      // When the JS bridge does send a fresh sizeTotal value (e.g. on a
      // legitimate re-open of the same book in a different session),
      // the cache should follow it rather than ignore it.
      blocTest<ReaderBloc, ReaderState>(
        'overwrites cached sizeTotal when event provides a new one',
        setUp: () => bookRepository.seedBook(testBook),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook,
          sizeTotal: 480000,
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4!/4/4)',
            progress: 0.3,
            sizeTotal: 500000,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.sizeTotal, 500000);
        },
      );

      // foliate-js's paginator allows navigation onto two blank
      // trailing columns past the actual content (`atEnd: page >=
      // pages - 2`). On those it emits `progress=0` /
      // `bookCurrentPage=0` — not because we're at the start, but
      // because there's no real content under the viewport. Use
      // the paginator-reported `atEnd` flag to override those
      // bogus numbers with "100% / last page" — same trick readest
      // uses. Without the override the slider would snap to 0%
      // and the page counter would clear at the end of every book.
      blocTest<ReaderBloc, ReaderState>(
        'atEnd phantom: overrides progress=0 with 1.0 and pins page to last',
        setUp: () =>
            bookRepository.seedBook(testBook.copyWith(readingProgress: 0.99)),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook.copyWith(readingProgress: 0.99),
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(blank-trailing-column)',
            progress: 0.0,
            bookCurrentPage: 0,
            bookTotalPages: 200,
            atEnd: true,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.book?.readingProgress, 1.0);
          expect(bloc.state.bookCurrentPage, 199);
          expect(bloc.state.bookTotalPages, 200);
        },
      );

      // A legitimate position update that happens to start near
      // zero (book just reopened from the beginning, or user
      // dragged the slider to the start) carries `atEnd=false`,
      // so progress passes through unmodified.
      blocTest<ReaderBloc, ReaderState>(
        'atEnd=false: progress passes through unmodified',
        setUp: () =>
            bookRepository.seedBook(testBook.copyWith(readingProgress: 1.0)),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook.copyWith(readingProgress: 1.0),
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/2)',
            progress: 0.0,
            bookCurrentPage: 1,
            bookTotalPages: 200,
            atEnd: false,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          // Real seek from end to start: state updates to 0.0 / page 1.
          expect(bloc.state.book?.readingProgress, 0.0);
          expect(bloc.state.bookCurrentPage, 1);
        },
      );

      // Defensive: if foliate-js reports atEnd but bookTotalPages is
      // null (very early in the load before pagination settles), we
      // can't compute "last page", so the override must NOT engage —
      // the event passes through as-is.
      blocTest<ReaderBloc, ReaderState>(
        'atEnd with null bookTotalPages does not engage override',
        setUp: () =>
            bookRepository.seedBook(testBook.copyWith(readingProgress: 0.5)),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook.copyWith(readingProgress: 0.5),
        ),
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/2)',
            progress: 0.3,
            atEnd: true,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.book?.readingProgress, 0.3);
          expect(bloc.state.bookCurrentPage, isNull);
        },
      );

      // Bottom chrome reads chapterTitle / bookCurrentPage from
      // ReaderState. The bloc must surface the optional fields from
      // the event into state — they're transient (not persisted),
      // so they have no representation on Book and must travel
      // through copyWith.
      blocTest<ReaderBloc, ReaderState>(
        'surfaces chapterTitle and page metrics into state',
        setUp: () => bookRepository.seedBook(testBook),
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
            chapterTitle: 'Book IV',
            bookCurrentPage: 84,
            bookTotalPages: 200,
          ),
        ),
        wait: const Duration(seconds: 3),
        verify: (bloc) {
          expect(bloc.state.chapterTitle, 'Book IV');
          expect(bloc.state.bookCurrentPage, 84);
          expect(bloc.state.bookTotalPages, 200);
        },
      );

      // Drag-to-seek can fire ~10 ReaderBookPositionUpdated per
      // second. We must NOT do a DB write per event — debounce to a
      // single trailing write 500ms after the last event, holding
      // the latest value.
      blocTest<ReaderBloc, ReaderState>(
        'debounces persist: rapid position events collapse into one '
        'updateBook with the last value',
        setUp: () => bookRepository.seedBook(testBook),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          title: testBook.title,
          book: testBook,
        ),
        act: (bloc) {
          for (var i = 1; i <= 5; i++) {
            bloc.add(
              ReaderBookPositionUpdated(
                cfi: 'epubcfi($i)',
                progress: i * 0.1,
              ),
            );
          }
        },
        wait: const Duration(milliseconds: 700),
        verify: (_) {
          expect(bookRepository.updateCallCount, 1);
          expect(bookRepository.updatedBook!.currentCfi, 'epubcfi(5)');
          expect(bookRepository.updatedBook!.readingProgress, 0.5);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'duplicate position event does not schedule a persist',
        setUp: () => bookRepository.seedBook(testBook),
        build: buildBloc,
        seed: () {
          final positionedBook = testBook.copyWith(
            currentCfi: 'epubcfi(/6/4)',
            readingProgress: 0.2,
          );
          return ReaderState(
            status: ReaderStatus.ready,
            title: positionedBook.title,
            book: positionedBook,
            bookCurrentPage: 20,
            bookTotalPages: 200,
          );
        },
        act: (bloc) => bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(/6/4)',
            progress: 0.2,
            bookCurrentPage: 20,
            bookTotalPages: 200,
          ),
        ),
        wait: const Duration(milliseconds: 700),
        expect: () => <ReaderState>[],
        verify: (_) {
          expect(bookRepository.updateCallCount, 0);
        },
      );

      // Closing the bloc before the debounce window elapses must
      // still flush the pending write — otherwise navigating away
      // mid-drag (e.g. tap-to-go-home) drops the latest position.
      test('close() flushes pending persist before completing', () async {
        bookRepository.seedBook(testBook);
        final bloc = buildBloc();
        bloc.emit(
          ReaderState(
            status: ReaderStatus.ready,
            title: testBook.title,
            book: testBook,
          ),
        );
        bloc.add(
          const ReaderBookPositionUpdated(
            cfi: 'epubcfi(end)',
            progress: 0.9,
          ),
        );
        // Let the event handler run (state emits, persist is queued)
        // but DON'T wait for the 500ms debounce.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          bookRepository.updateCallCount,
          0,
          reason: 'persist should be debounced, not yet written',
        );
        await bloc.close();
        expect(bookRepository.updateCallCount, 1);
        expect(bookRepository.updatedBook!.currentCfi, 'epubcfi(end)');
        expect(bookRepository.updatedBook!.readingProgress, 0.9);
      });

      test(
        'persists first article progress immediately so catalog refresh sees it',
        () async {
          final articleRepository = FakeArticleRepository();
          articleRepository.seedArticle(
            Article(
              id: 'article-1',
              title: 'Saved Article',
              url: 'https://example.com/article',
              siteName: 'Example',
              contentPath: '/articles/article-1/article.json',
              addedAt: DateTime(2024, 1, 1),
            ),
          );
          final bloc = ReaderBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
            highlightRepository: highlightRepository,
          );
          addTearDown(bloc.close);

          bloc.add(const ReaderSourceLoadRequested(sourceId: 'article-1'));
          await bloc.stream.firstWhere(
            (s) => s.status == ReaderStatus.ready,
          );
          expect(articleRepository.updateCallCount, 1);

          bloc.add(
            const ReaderBookPositionUpdated(
              cfi: 'epubcfi(/6/2)',
              progress: 0.4,
            ),
          );
          await bloc.stream.firstWhere(
            (s) => s.book?.readingProgress == 0.4,
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(articleRepository.updateCallCount, 2);
          expect(articleRepository.updatedArticle?.readingProgress, 0.4);
        },
      );

      test(
        'treats a single-page article as fully progressed after opening',
        () async {
          final articleRepository = FakeArticleRepository();
          articleRepository.seedArticle(
            Article(
              id: 'article-1',
              title: 'Saved Article',
              url: 'https://example.com/article',
              siteName: 'Example',
              contentPath: '/articles/article-1/article.json',
              addedAt: DateTime(2024, 1, 1),
            ),
          );
          final bloc = ReaderBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
            highlightRepository: highlightRepository,
          );
          addTearDown(bloc.close);

          bloc.add(const ReaderSourceLoadRequested(sourceId: 'article-1'));
          await bloc.stream.firstWhere(
            (s) => s.status == ReaderStatus.ready,
          );

          bloc.add(
            const ReaderBookPositionUpdated(
              cfi: 'epubcfi(/6/2)',
              progress: 0,
              bookCurrentPage: 1,
              bookTotalPages: 1,
            ),
          );
          await bloc.stream.firstWhere(
            (s) => s.book?.readingProgress == 1,
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(bloc.state.book?.readingProgress, 1);
          expect(articleRepository.updatedArticle?.readingProgress, 1);
        },
      );

      test(
        'treats the first page of a multi-page article as visible progress',
        () async {
          final articleRepository = FakeArticleRepository();
          articleRepository.seedArticle(
            Article(
              id: 'article-1',
              title: 'Saved Article',
              url: 'https://example.com/article',
              siteName: 'Example',
              contentPath: '/articles/article-1/article.json',
              addedAt: DateTime(2024, 1, 1),
            ),
          );
          final bloc = ReaderBloc(
            bookRepository: bookRepository,
            articleRepository: articleRepository,
            highlightRepository: highlightRepository,
          );
          addTearDown(bloc.close);

          bloc.add(const ReaderSourceLoadRequested(sourceId: 'article-1'));
          await bloc.stream.firstWhere(
            (s) => s.status == ReaderStatus.ready,
          );

          bloc.add(
            const ReaderBookPositionUpdated(
              cfi: 'epubcfi(/6/2)',
              progress: 0,
              bookCurrentPage: 0,
              bookTotalPages: 4,
            ),
          );
          await bloc.stream.firstWhere(
            (s) => s.book?.readingProgress == 0.25,
          );
          await Future<void>.delayed(const Duration(milliseconds: 50));

          expect(bloc.state.book?.readingProgress, 0.25);
          expect(articleRepository.updatedArticle?.readingProgress, 0.25);
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

      // Pinned invariant for any future approach that subscribes to
      // highlights changes (context.select / BlocListener with
      // !identical / etc.) — `copyWith` must hand back a fresh list
      // reference on highlight refresh, otherwise the subscriber
      // won't fire. Currently the reader doesn't subscribe (causing
      // newly created highlights to only appear on reader reopen),
      // but the contract still matters.
      blocTest<ReaderBloc, ReaderState>(
        'emits a fresh highlights list reference on refresh',
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

    group('ReaderBookmarkChanged', () {
      blocTest<ReaderBloc, ReaderState>(
        'adds bookmark for current source',
        setUp: () => bookRepository.seedBook(testBook),
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          book: testBook,
          chapterTitle: 'Chapter 7',
        ),
        act: (bloc) => bloc.add(
          const ReaderBookmarkChanged(
            remove: false,
            cfi: 'epubcfi(/6/34)',
            content: 'Bookmark text',
            progress: 0.56,
            anchorExact: 'Bookmark text anchor',
            anchorPrefix: 'Before',
            anchorSuffix: 'After',
            anchorSectionIndex: 12,
            anchorSectionPage: 3,
          ),
        ),
        expect: () => [
          isA<ReaderState>()
              .having(
                (s) => s.bookmarks.single.content,
                'bookmark content',
                'Bookmark text',
              )
              .having(
                (s) => s.currentPageBookmarked,
                'current page bookmarked',
                isTrue,
              ),
        ],
        verify: (bloc) {
          final bookmarks = bookRepository.bookmarksBySourceId['book-1'];
          expect(bookmarks, hasLength(1));
          expect(bookmarks!.single.chapterTitle, 'Chapter 7');
          expect(bookmarks.single.anchorExact, 'Bookmark text anchor');
          expect(bookmarks.single.anchorSectionPage, 3);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'removes bookmark by id',
        setUp: () {
          bookRepository.seedBook(testBook);
          bookRepository.seedBookmarks('book-1', [testBookmark]);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          book: testBook,
          bookmarks: [testBookmark],
          currentPageBookmarked: true,
          currentPageBookmarkCfi: testBookmark.cfi,
          currentPageBookmarkId: testBookmark.id,
        ),
        act: (bloc) => bloc.add(
          ReaderBookmarkChanged(
            remove: true,
            id: testBookmark.id,
            cfi: testBookmark.cfi,
            content: '',
            progress: testBookmark.progress,
          ),
        ),
        expect: () => [
          isA<ReaderState>()
              .having((s) => s.bookmarks, 'bookmarks', isEmpty)
              .having(
                (s) => s.currentPageBookmarked,
                'current page bookmarked',
                isFalse,
              ),
        ],
        verify: (_) {
          expect(bookRepository.bookmarksBySourceId['book-1'], isEmpty);
        },
      );

      blocTest<ReaderBloc, ReaderState>(
        'removing a different bookmark preserves current page bookmark state',
        setUp: () {
          final otherBookmark = SourceBookmark(
            id: 'bm-2',
            sourceId: 'book-1',
            sourceType: SourceType.book,
            cfi: 'epubcfi(/6/8)',
            content: 'Another page',
            progress: 0.4,
            createdAt: DateTime(2024, 1, 4),
          );
          bookRepository.seedBook(testBook);
          bookRepository.seedBookmarks('book-1', [testBookmark, otherBookmark]);
        },
        build: buildBloc,
        seed: () => ReaderState(
          status: ReaderStatus.ready,
          book: testBook,
          bookmarks: [
            testBookmark,
            SourceBookmark(
              id: 'bm-2',
              sourceId: 'book-1',
              sourceType: SourceType.book,
              cfi: 'epubcfi(/6/8)',
              content: 'Another page',
              progress: 0.4,
              createdAt: DateTime(2024, 1, 4),
            ),
          ],
          currentPageBookmarked: true,
          currentPageBookmarkCfi: testBookmark.cfi,
          currentPageBookmarkId: testBookmark.id,
        ),
        act: (bloc) => bloc.add(
          const ReaderBookmarkChanged(
            remove: true,
            id: 'bm-2',
            cfi: 'epubcfi(/6/8)',
            content: '',
            progress: 0.4,
          ),
        ),
        expect: () => [
          isA<ReaderState>()
              .having((s) => s.bookmarks, 'bookmarks', hasLength(1))
              .having(
                (s) => s.bookmarks.single.id,
                'remaining bookmark id',
                testBookmark.id,
              )
              .having(
                (s) => s.currentPageBookmarked,
                'current page bookmarked',
                isTrue,
              )
              .having(
                (s) => s.currentPageBookmarkId,
                'current page bookmark id',
                testBookmark.id,
              ),
        ],
      );

      blocTest<ReaderBloc, ReaderState>(
        'ignores malformed add bookmark event without cfi',
        build: buildBloc,
        seed: () => ReaderState(status: ReaderStatus.ready, book: testBook),
        act: (bloc) => bloc.add(
          const ReaderBookmarkChanged(
            remove: false,
            cfi: '',
            content: 'No target',
            progress: 0.1,
          ),
        ),
        expect: () => <ReaderState>[],
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

      test(
        'copyWith preserves nullable chrome fields when not explicitly passed',
        () {
          final state = ReaderState(
            book: testBook,
            chapterTitle: 'Book IV',
            bookCurrentPage: 84,
            bookTotalPages: 200,
          );
          final copy = state.copyWith(highlights: const []);
          expect(copy.chapterTitle, 'Book IV');
          expect(copy.bookCurrentPage, 84);
          expect(copy.bookTotalPages, 200);
        },
      );

      test('copyWith can clear chapterTitle by passing null explicitly', () {
        final state = ReaderState(book: testBook, chapterTitle: 'Book IV');
        final copy = state.copyWith(chapterTitle: null);
        expect(copy.chapterTitle, isNull);
      });
    });
  });
}
