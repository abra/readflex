import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/articles_table.dart';

part 'articles_dao.g.dart';

/// CRUD access to [ArticlesTable]. List queries sort by most-recently-opened
/// first, falling back to added-at. Called only by `ArticleRepository`,
/// which wraps errors in `StorageException` and owns the on-disk article
/// files.
@DriftAccessor(tables: [ArticlesTable])
class ArticlesDao extends DatabaseAccessor<AppDatabase>
    with _$ArticlesDaoMixin {
  ArticlesDao(super.db);

  Future<List<ArticlesTableData>> allArticles({int? limit, int? offset}) {
    final query = select(articlesTable)
      ..orderBy([
        (t) => OrderingTerm.desc(t.lastOpenedAt),
        (t) => OrderingTerm.desc(t.addedAt),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

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
