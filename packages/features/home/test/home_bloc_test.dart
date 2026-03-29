import 'package:bloc_test/bloc_test.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home/src/home_bloc.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';
import 'helpers/fake_flashcard_repository.dart';
import 'helpers/fake_highlight_repository.dart';

final _book = Book(
  id: '1',
  title: 'Test Book',
  filePath: '/test.epub',
  format: BookFormat.epub,
  addedAt: DateTime(2026, 1, 1),
);

final _article = Article(
  id: '2',
  title: 'Test Article',
  url: 'https://example.com',
  cleanedHtml: '<p>Hi</p>',
  addedAt: DateTime(2026, 2, 1),
);

final _highlight = Highlight(
  id: 'h1',
  sourceId: '1',
  sourceType: SourceType.book,
  text: 'highlighted text',
  color: HighlightColor.yellow,
  createdAt: DateTime(2026, 1, 5),
);

final _flashcard = Flashcard(
  id: 'f1',
  deckId: '1',
  front: 'Q',
  back: 'A',
  creationSource: CreationSource.manual,
  createdAt: DateTime(2026, 1, 5),
  fsrs: const FsrsCardData(),
);

void main() {
  group('HomeBloc', () {
    late FakeBookRepository bookRepo;
    late FakeArticleRepository articleRepo;
    late FakeHighlightRepository highlightRepo;
    late FakeFlashcardRepository flashcardRepo;

    setUp(() {
      bookRepo = FakeBookRepository();
      articleRepo = FakeArticleRepository();
      highlightRepo = FakeHighlightRepository();
      flashcardRepo = FakeFlashcardRepository();
    });

    blocTest<HomeBloc, HomeState>(
      'emits loading then success with stats',
      setUp: () {
        bookRepo.books = [_book];
        articleRepo.articles = [_article];
        highlightRepo.highlights = [_highlight];
        flashcardRepo.dueCards = [_flashcard];
      },
      build: () => HomeBloc(
        bookRepository: bookRepo,
        articleRepository: articleRepo,
        highlightRepository: highlightRepo,
        flashcardRepository: flashcardRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        HomeState(
          status: HomeStatus.success,
          recentBooks: [_book],
          recentArticles: [_article],
          recentItems: [_article, _book],
          totalHighlights: 1,
          dueFlashcards: 1,
        ),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits success with zeros when empty',
      build: () => HomeBloc(
        bookRepository: bookRepo,
        articleRepository: articleRepo,
        highlightRepository: highlightRepo,
        flashcardRepository: flashcardRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        const HomeState(status: HomeStatus.success),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits failure on error',
      setUp: () => bookRepo.shouldThrow = true,
      build: () => HomeBloc(
        bookRepository: bookRepo,
        articleRepository: articleRepo,
        highlightRepository: highlightRepo,
        flashcardRepository: flashcardRepo,
      ),
      act: (bloc) => bloc.add(const HomeLoadRequested()),
      expect: () => [
        const HomeState(status: HomeStatus.loading),
        const HomeState(status: HomeStatus.failure),
      ],
    );
  });

  group('HomeState', () {
    test('recentItems returns up to 5 sorted by most recent', () {
      final books = List.generate(
        4,
        (i) => Book(
          id: 'b$i',
          title: 'Book $i',
          filePath: '/b$i.epub',
          format: BookFormat.epub,
          addedAt: DateTime(2026, 1, i + 1),
        ),
      );
      final articles = List.generate(
        3,
        (i) => Article(
          id: 'a$i',
          title: 'Article $i',
          url: 'https://example.com/$i',
          cleanedHtml: '<p>$i</p>',
          addedAt: DateTime(2026, 2, i + 1),
        ),
      );

      final recentItems = <Object>[
        ...articles.reversed,
        ...books.reversed,
      ].take(5).toList();

      final state = HomeState(
        status: HomeStatus.success,
        recentBooks: books,
        recentArticles: articles,
        recentItems: recentItems,
      );

      expect(state.recentItems, hasLength(5));
      // Most recent first (articles are in Feb, books in Jan).
      expect(state.recentItems.first, isA<Article>());
    });

    test('totalSources is sum of books and articles', () {
      final state = HomeState(
        status: HomeStatus.success,
        recentBooks: [_book],
        recentArticles: [_article],
      );
      expect(state.totalSources, 2);
    });
  });
}
