import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late ArticlesDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.articlesDao;
  });

  tearDown(() => db.close());

  ArticlesTableCompanion makeArticle({
    String id = 'a1',
    String title = 'Test Article',
    String url = 'https://example.com',
    String contentPath = '/articles/a1.html',
    String addedAt = '2026-01-01T00:00:00.000Z',
  }) => ArticlesTableCompanion.insert(
    id: id,
    title: title,
    url: url,
    contentPath: contentPath,
    addedAt: addedAt,
  );

  group('ArticlesDao', () {
    test('insertArticle and allArticles returns inserted article', () async {
      await dao.insertArticle(makeArticle());
      final articles = await dao.allArticles();
      expect(articles, hasLength(1));
      expect(articles.first.title, 'Test Article');
    });

    test('articleById returns correct article', () async {
      await dao.insertArticle(makeArticle());
      final article = await dao.articleById('a1');
      expect(article, isNotNull);
      expect(article!.url, 'https://example.com');
    });

    test('deleteArticle removes article', () async {
      await dao.insertArticle(makeArticle());
      await dao.deleteArticle('a1');
      final articles = await dao.allArticles();
      expect(articles, isEmpty);
    });
  });
}
