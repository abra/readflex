import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/articles_table.dart';

part 'articles_dao.g.dart';

@DriftAccessor(tables: [ArticlesTable])
class ArticlesDao extends DatabaseAccessor<AppDatabase>
    with _$ArticlesDaoMixin {
  ArticlesDao(super.db);

  Future<List<ArticlesTableData>> allArticles() =>
      (select(articlesTable)..orderBy([
            (t) => OrderingTerm.desc(t.lastOpenedAt),
            (t) => OrderingTerm.desc(t.addedAt),
          ]))
          .get();

  Future<ArticlesTableData?> articleById(String id) =>
      (select(articlesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertArticle(ArticlesTableCompanion article) =>
      into(articlesTable).insert(article);

  Future<void> updateArticle(ArticlesTableCompanion article) => (update(
    articlesTable,
  )..where((t) => t.id.equals(article.id.value))).write(article);

  Future<void> deleteArticle(String id) =>
      (delete(articlesTable)..where((t) => t.id.equals(id))).go();
}
