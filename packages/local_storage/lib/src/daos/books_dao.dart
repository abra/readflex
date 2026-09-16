import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/books_table.dart';

part 'books_dao.g.dart';

/// CRUD access to [BooksTable]. Lists sort by last-opened descending (nulls
/// last), then added-at descending. Library applies its own combined ordering.
/// `BookRepository` maps rows, wraps errors and owns the on-disk book files.
@DriftAccessor(tables: [BooksTable])
class BooksDao extends DatabaseAccessor<AppDatabase> with _$BooksDaoMixin {
  BooksDao(super.db);

  Future<List<BooksTableData>> allBooks({int? limit, int? offset}) {
    final query = select(booksTable)
      ..orderBy([
        (t) => OrderingTerm.desc(t.lastOpenedAt),
        (t) => OrderingTerm.desc(t.addedAt),
      ]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  Future<BooksTableData?> bookById(String id) =>
      (select(booksTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertBook(BooksTableCompanion book) =>
      into(booksTable).insert(book);

  Future<void> updateBook(BooksTableCompanion book) => (update(
    booksTable,
  )..where((t) => t.id.equals(book.id.value))).write(book);

  Future<void> deleteBook(String id) =>
      (delete(booksTable)..where((t) => t.id.equals(id))).go();
}
