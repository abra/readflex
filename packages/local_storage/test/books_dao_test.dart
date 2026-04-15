import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';

void main() {
  late AppDatabase db;
  late BooksDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.booksDao;
  });

  tearDown(() => db.close());

  BooksTableCompanion makeBook({
    String id = 'b1',
    String title = 'Test Book',
    String format = 'epub',
    String filePath = '/books/test.epub',
    String addedAt = '2026-01-01T00:00:00.000Z',
  }) => BooksTableCompanion.insert(
    id: id,
    title: title,
    format: format,
    filePath: filePath,
    addedAt: addedAt,
  );

  group('BooksDao', () {
    test('insertBook and allBooks returns inserted book', () async {
      await dao.insertBook(makeBook());
      final books = await dao.allBooks();
      expect(books, hasLength(1));
      expect(books.first.title, 'Test Book');
    });

    test('bookById returns correct book', () async {
      await dao.insertBook(makeBook(id: 'b1'));
      await dao.insertBook(makeBook(id: 'b2', title: 'Other'));
      final book = await dao.bookById('b1');
      expect(book, isNotNull);
      expect(book!.title, 'Test Book');
    });

    test('bookById returns null for missing id', () async {
      final book = await dao.bookById('missing');
      expect(book, isNull);
    });

    test('updateBook modifies existing book', () async {
      await dao.insertBook(makeBook());
      await dao.updateBook(
        const BooksTableCompanion(
          id: Value('b1'),
          title: Value('Updated Title'),
        ),
      );
      final book = await dao.bookById('b1');
      expect(book!.title, 'Updated Title');
    });

    test('deleteBook removes book', () async {
      await dao.insertBook(makeBook());
      await dao.deleteBook('b1');
      final books = await dao.allBooks();
      expect(books, isEmpty);
    });
  });
}
