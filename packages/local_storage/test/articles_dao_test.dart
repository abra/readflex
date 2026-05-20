import 'package:drift/drift.dart' hide isNotNull, isNull;
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
    String title = 'Article',
    String addedAt = '2026-01-01T00:00:00.000Z',
    Value<String?> lastOpenedAt = const Value.absent(),
  }) {
    return ArticlesTableCompanion.insert(
      id: id,
      title: title,
      url: 'https://example.com/$id',
      contentPath: 'article.json',
      addedAt: addedAt,
      lastOpenedAt: lastOpenedAt,
    );
  }

  group('ArticlesDao', () {
    test('insertArticle and articleById returns inserted article', () async {
      await dao.insertArticle(makeArticle());

      final article = await dao.articleById('a1');

      expect(article, isNotNull);
      expect(article!.title, 'Article');
    });

    test('allArticles sorts recently opened articles first', () async {
      await dao.insertArticle(makeArticle(id: 'old', title: 'Old'));
      await dao.insertArticle(
        makeArticle(
          id: 'opened',
          title: 'Opened',
          lastOpenedAt: const Value('2026-01-02T00:00:00.000Z'),
        ),
      );

      final articles = await dao.allArticles();

      expect(articles.map((article) => article.id), ['opened', 'old']);
    });

    test('deleteArticle removes article', () async {
      await dao.insertArticle(makeArticle());
      await dao.deleteArticle('a1');

      expect(await dao.articleById('a1'), isNull);
    });
  });
}
