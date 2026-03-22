import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/articles_table.dart';
import '../tables/books_table.dart';

part 'books_dao.g.dart';

@DriftAccessor(tables: [BooksTable, ArticlesTable])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<BooksTableData>> allBooks() =>
      (select(booksTable)..orderBy([
            (t) => OrderingTerm.desc(t.lastOpenedAt),
            (t) => OrderingTerm.desc(t.addedAt),
          ]))
          .get();

  Future<BooksTableData?> bookById(String id) =>
      (select(booksTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertBook(BooksTableCompanion book) =>
      into(booksTable).insert(book);

  Future<void> updateBook(BooksTableCompanion book) => (update(
    booksTable,
  )..where((t) => t.id.equals(book.id.value))).write(book);

  Future<void> deleteBook(String id) =>
      (delete(booksTable)..where((t) => t.id.equals(id))).go();

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
