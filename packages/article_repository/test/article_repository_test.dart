import 'package:article_repository/article_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late ArticleRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ArticleRepository(articlesDao: db.articlesDao);
  });

  tearDown(() => db.close());

  group('ArticleRepository', () {
    test('addArticle creates an article and returns it', () async {
      final article = await repo.addArticle(
        title: 'My Article',
        url: 'https://example.com/article',
        cleanedHtml: '<p>Hello</p>',
        siteName: 'Example',
      );
      expect(article.title, 'My Article');
      expect(article.siteName, 'Example');
      expect(article.id, isNotEmpty);
    });

    test('getArticles returns all added articles', () async {
      await repo.addArticle(
        title: 'Art 1',
        url: 'https://a.com/1',
        cleanedHtml: '<p>1</p>',
      );
      await repo.addArticle(
        title: 'Art 2',
        url: 'https://a.com/2',
        cleanedHtml: '<p>2</p>',
      );
      final articles = await repo.getArticles();
      expect(articles, hasLength(2));
    });

    test('getArticleById returns correct article', () async {
      final created = await repo.addArticle(
        title: 'Find Article',
        url: 'https://a.com/find',
        cleanedHtml: '<p>found</p>',
      );
      final found = await repo.getArticleById(created.id);
      expect(found, isNotNull);
      expect(found!.title, 'Find Article');
    });

    test('deleteArticle removes article', () async {
      final created = await repo.addArticle(
        title: 'Remove',
        url: 'https://a.com/del',
        cleanedHtml: '<p>bye</p>',
      );
      await repo.deleteArticle(created.id);
      final articles = await repo.getArticles();
      expect(articles, isEmpty);
    });

    test('updateArticle persists scroll offset', () async {
      final created = await repo.addArticle(
        title: 'Scroll',
        url: 'https://a.com/scroll',
        cleanedHtml: '<p>content</p>',
      );
      final updated = created.copyWith(currentScrollOffset: 123.4);
      await repo.updateArticle(updated);
      final fetched = await repo.getArticleById(created.id);
      expect(fetched!.currentScrollOffset, 123.4);
    });
  });
}
