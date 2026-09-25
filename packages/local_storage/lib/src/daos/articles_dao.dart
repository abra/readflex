import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/articles_table.dart';

part 'articles_dao.g.dart';

/// Stored metadata for lists. Deliberately excludes body text and reader anchors.
typedef ArticleListEntry = ({
  String id,
  String title,
  String url,
  String? author,
  String? siteName,
  String? hostname,
  String? language,
  int textLength,
  int estimatedWordCount,
  double readingProgress,
  String addedAt,
  String? lastOpenedAt,
  bool isFinished,
});

/// CRUD access to [ArticlesTable]. Repository owns filesystem cleanup and
/// maps storage exceptions into domain-level errors.
@DriftAccessor(tables: [ArticlesTable])
class ArticlesDao extends DatabaseAccessor<AppDatabase>
    with _$ArticlesDaoMixin {
  ArticlesDao(super.db);

  Future<List<ArticleListEntry>> libraryEntries() {
    // Avoid a JoinedSelect TypedResult/expression map for every library row.
    final query = customSelect(
      '''
      SELECT id, title, url, author, site_name, hostname, language,
             text_length, estimated_word_count, reading_progress,
             added_at, last_opened_at, is_finished
      FROM articles_table
      ORDER BY last_opened_at DESC, added_at DESC
    ''',
      readsFrom: {articlesTable},
    );
    return query
        .map(
          (row) => (
            id: row.read<String>('id'),
            title: row.read<String>('title'),
            url: row.read<String>('url'),
            author: row.readNullable<String>('author'),
            siteName: row.readNullable<String>('site_name'),
            hostname: row.readNullable<String>('hostname'),
            language: row.readNullable<String>('language'),
            textLength: row.read<int>('text_length'),
            estimatedWordCount: row.read<int>('estimated_word_count'),
            readingProgress: row.read<double>('reading_progress'),
            addedAt: row.read<String>('added_at'),
            lastOpenedAt: row.readNullable<String>('last_opened_at'),
            isFinished: row.read<bool>('is_finished'),
          ),
        )
        .get();
  }

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
