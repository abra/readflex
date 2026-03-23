import 'package:bloc_test/bloc_test.dart';
import 'package:content_library/src/content_library_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:domain_models/domain_models.dart';

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
  group('ContentLibraryBloc', () {
    late FakeBookRepository repository;
    late FakeArticleRepository articleRepository;

    setUp(() {
      repository = FakeBookRepository();
      articleRepository = FakeArticleRepository();
    });

    blocTest<ContentLibraryBloc, ContentLibraryState>(
      'emits loading then success with items on ContentLibraryLoadRequested',
      setUp: () {
        repository.seedBooks([_book]);
        articleRepository.seedArticles([_article]);
      },
      build: () => ContentLibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const ContentLibraryLoadRequested()),
      expect: () => [
        const ContentLibraryState(status: ContentLibraryStatus.loading),
        ContentLibraryState(
          status: ContentLibraryStatus.success,
          books: [_book],
          articles: [_article],
          items: [_article, _book],
        ),
      ],
    );

    blocTest<ContentLibraryBloc, ContentLibraryState>(
      'emits success with empty lists when library is empty',
      build: () => ContentLibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const ContentLibraryLoadRequested()),
      expect: () => [
        const ContentLibraryState(status: ContentLibraryStatus.loading),
        const ContentLibraryState(status: ContentLibraryStatus.success),
      ],
    );

    blocTest<ContentLibraryBloc, ContentLibraryState>(
      'emits failure when repository throws',
      setUp: () => repository.shouldThrow = true,
      build: () => ContentLibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      act: (bloc) => bloc.add(const ContentLibraryLoadRequested()),
      expect: () => [
        const ContentLibraryState(status: ContentLibraryStatus.loading),
        const ContentLibraryState(status: ContentLibraryStatus.failure),
      ],
    );

    blocTest<ContentLibraryBloc, ContentLibraryState>(
      'ContentLibraryBookDeleted removes book and reloads',
      setUp: () {
        repository.seedBooks([_book]);
      },
      build: () => ContentLibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      seed: () => ContentLibraryState(
        status: ContentLibraryStatus.success,
        books: [_book],
      ),
      act: (bloc) => bloc.add(ContentLibraryBookDeleted(_book.id)),
      expect: () => [
        const ContentLibraryState(status: ContentLibraryStatus.success),
      ],
    );

    blocTest<ContentLibraryBloc, ContentLibraryState>(
      'ContentLibraryArticleDeleted removes article and reloads',
      setUp: () {
        articleRepository.seedArticles([_article]);
      },
      build: () => ContentLibraryBloc(
        bookRepository: repository,
        articleRepository: articleRepository,
      ),
      seed: () => ContentLibraryState(
        status: ContentLibraryStatus.success,
        articles: [_article],
      ),
      act: (bloc) => bloc.add(ContentLibraryArticleDeleted(_article.id)),
      expect: () => [
        const ContentLibraryState(status: ContentLibraryStatus.success),
      ],
    );
  });

  group('ContentLibraryState', () {
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

      final state = ContentLibraryState(
        status: ContentLibraryStatus.success,
        books: [older],
        articles: [newer],
        items: [newer, older],
      );

      expect(state.items, [newer, older]);
    });

    test('isEmpty is true when no items', () {
      const state = ContentLibraryState(status: ContentLibraryStatus.success);
      expect(state.isEmpty, isTrue);
    });
  });
}
