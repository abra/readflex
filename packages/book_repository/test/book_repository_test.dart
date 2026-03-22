import 'package:book_repository/book_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

void main() {
  late AppDatabase db;
  late BookRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = BookRepository(booksDao: db.booksDao);
  });

  tearDown(() => db.close());

  group('BookRepository — books', () {
    test('addBook creates a book and returns it', () async {
      final book = await repo.addBook(
        title: 'My Book',
        filePath: '/books/my.epub',
        format: BookFormat.epub,
        author: 'Author',
      );
      expect(book.title, 'My Book');
      expect(book.author, 'Author');
      expect(book.format, BookFormat.epub);
      expect(book.id, isNotEmpty);
    });

    test('getBooks returns all added books', () async {
      await repo.addBook(
        title: 'Book 1',
        filePath: '/books/1.epub',
        format: BookFormat.epub,
      );
      await repo.addBook(
        title: 'Book 2',
        filePath: '/books/2.fb2',
        format: BookFormat.fb2,
      );
      final books = await repo.getBooks();
      expect(books, hasLength(2));
    });

    test('getBookById returns correct book', () async {
      final created = await repo.addBook(
        title: 'Find Me',
        filePath: '/books/find.epub',
        format: BookFormat.epub,
      );
      final found = await repo.getBookById(created.id);
      expect(found, isNotNull);
      expect(found!.title, 'Find Me');
    });

    test('getBookById returns null for missing id', () async {
      final found = await repo.getBookById('missing');
      expect(found, isNull);
    });

    test('updateBook persists changes', () async {
      final created = await repo.addBook(
        title: 'Original',
        filePath: '/books/orig.epub',
        format: BookFormat.epub,
      );
      final updated = created.copyWith(title: 'Updated', readingProgress: 0.5);
      await repo.updateBook(updated);
      final fetched = await repo.getBookById(created.id);
      expect(fetched!.title, 'Updated');
      expect(fetched.readingProgress, 0.5);
    });

    test('deleteBook removes book', () async {
      final created = await repo.addBook(
        title: 'Delete Me',
        filePath: '/books/del.epub',
        format: BookFormat.epub,
      );
      await repo.deleteBook(created.id);
      final books = await repo.getBooks();
      expect(books, isEmpty);
    });
  });
}
