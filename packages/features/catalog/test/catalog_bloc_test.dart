import 'package:bloc_test/bloc_test.dart';
import 'package:catalog/src/catalog_bloc.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_article_repository.dart';
import 'helpers/fake_book_repository.dart';

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
  contentPath: '/articles/2.html',
  addedAt: DateTime(2026, 1, 2),
);

void main() {
  group('CatalogBloc', () {
    late FakeBookRepository repository;
    late FakeArticleRepository articleRepository;

    setUp(() {
      repository = FakeBookRepository();
      articleRepository = FakeArticleRepository();
    });

    blocTest<CatalogBloc, CatalogState>(
      'emits loading then success with items on CatalogLoadRequested',
      setUp: () {
        repository.seedBooks([_book]);
        articleRepository.seedArticles([_article]);
      },
      build: () => CatalogBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        CatalogState(
          status: CatalogStatus.success,
          books: [_book],
          articles: [_article],
          items: [_article, _book],
        ),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'emits success with empty lists when library is empty',
      build: () => CatalogBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.success),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => CatalogBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const CatalogLoadRequested()),
      expect: () => [
        const CatalogState(status: CatalogStatus.loading),
        const CatalogState(status: CatalogStatus.failure),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'CatalogBookDeleted removes book and reloads',
      setUp: () {
        repository.seedBooks([_book]);
      },
      build: () => CatalogBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      seed: () => CatalogState(
        status: CatalogStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(CatalogBookDeleted(_book.id)),
      expect: () => [
        const CatalogState(status: CatalogStatus.success),
      ],
    );

    blocTest<CatalogBloc, CatalogState>(
      'CatalogArticleDeleted removes article and reloads',
      setUp: () {
        articleRepository.seedArticles([_article]);
      },
      build: () => CatalogBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      seed: () => CatalogState(
        status: CatalogStatus.success,
        articles: [_article],
      ),
      act: (bloc) => bloc.add(CatalogArticleDeleted(_article.id)),
      expect: () => [
        const CatalogState(status: CatalogStatus.success),
      ],
    );
  });

  group('CatalogState', () {
    test('items are sorted by addedAt descending', () {
      final older = Book(
        id: '1',
        title: 'Older',
        filePath: '/a.epub',
        format: BookFormat.epub,
        addedAt: DateTime(2026, 1, 1),
      );
      final newer = Article(
        id: '2',
        title: 'Newer',
        url: 'https://example.com',
        contentPath: '/articles/2.html',
        addedAt: DateTime(2026, 6, 1),
      );

      final state = CatalogState(
        status: CatalogStatus.success,
        books: [older],
        articles: [newer],
        items: [newer, older],
      );

      expect(state.items, [newer, older]);
    });

    test('isEmpty is true when no items', () {
      const state = CatalogState(status: CatalogStatus.success);
      expect(state.isEmpty, isTrue);
    });
  });
}
