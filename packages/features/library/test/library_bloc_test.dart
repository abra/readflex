import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:content_library/src/library_bloc.dart';
import 'package:shared/shared.dart';

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
  cleanedHtml: '<p>Hello</p>',
  addedAt: DateTime(2026, 1, 2),
);

void main() {
  group('LibraryBloc', () {
    late FakeBookRepository repository;
    late FakeArticleRepository articleRepository;

    setUp(() {
      repository = FakeBookRepository();
      articleRepository = FakeArticleRepository();
    });

    blocTest<LibraryBloc, LibraryState>(
      'emits loading then success with items on LibraryLoadRequested',
      setUp: () {
        repository.seedBooks([_book]);
        articleRepository.seedArticles([_article]);
      },
      build: () => LibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      expect: () => [
        const LibraryState(status: LibraryStatus.loading),
        LibraryState(
          status: LibraryStatus.success,
          books: [_book],
          articles: [_article],
          items: [_article, _book],
        ),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits success with empty lists when library is empty',
      build: () => LibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      expect: () => [
        const LibraryState(status: LibraryStatus.loading),
        const LibraryState(status: LibraryStatus.success),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => LibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const LibraryLoadRequested()),
      expect: () => [
        const LibraryState(status: LibraryStatus.loading),
        const LibraryState(status: LibraryStatus.failure),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibraryBookDeleted removes book and reloads',
      setUp: () {
        repository.seedBooks([_book]);
      },
      build: () => LibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(LibraryBookDeleted(_book.id)),
      expect: () => [
        const LibraryState(status: LibraryStatus.success),
      ],
    );

    blocTest<LibraryBloc, LibraryState>(
      'LibraryArticleDeleted removes article and reloads',
      setUp: () {
        articleRepository.seedArticles([_article]);
      },
      build: () => LibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      seed: () => LibraryState(
        status: LibraryStatus.success,
        articles: [_article],
      ),
      act: (bloc) => bloc.add(LibraryArticleDeleted(_article.id)),
      expect: () => [
        const LibraryState(status: LibraryStatus.success),
      ],
    );
  });

  group('LibraryState', () {
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
        cleanedHtml: '<p>hi</p>',
        addedAt: DateTime(2026, 6, 1),
      );

      final state = LibraryState(
        status: LibraryStatus.success,
        books: [older],
        articles: [newer],
        items: [newer, older],
      );

      expect(state.items, [newer, older]);
    });

    test('isEmpty is true when no items', () {
      const state = LibraryState(status: LibraryStatus.success);
      expect(state.isEmpty, isTrue);
    });
  });
}
