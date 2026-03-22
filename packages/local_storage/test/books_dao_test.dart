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

  BooksTableCompanion _book({
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

  ArticlesTableCompanion _article({
    String id = 'a1',
    String title = 'Test Article',
    String url = 'https://example.com',
    String cleanedHtml = '<p>Content</p>',
    String addedAt = '2026-01-01T00:00:00.000Z',
  }) => ArticlesTableCompanion.insert(
    id: id,
    title: title,
    url: url,
    cleanedHtml: cleanedHtml,
    addedAt: addedAt,
  );

  group('BooksDao', () {
    test('insertBook and allBooks returns inserted book', () async {
      await dao.insertBook(_book());
      final books = await dao.allBooks();
      expect(books, hasLength(1));
      expect(books.first.title, 'Test Book');
    });

    test('bookById returns correct book', () async {
      await dao.insertBook(_book(id: 'b1'));
      await dao.insertBook(_book(id: 'b2', title: 'Other'));
      final book = await dao.bookById('b1');
      expect(book, isNotNull);
      expect(book!.title, 'Test Book');
    });

    test('bookById returns null for missing id', () async {
      final book = await dao.bookById('missing');
      expect(book, isNull);
    });

    test('updateBook modifies existing book', () async {
      await dao.insertBook(_book());
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
      await dao.insertBook(_book());
      await dao.deleteBook('b1');
      final books = await dao.allBooks();
      expect(books, isEmpty);
    });
  });

  group('BooksDao — articles', () {
    test('insertArticle and allArticles returns inserted article', () async {
      await dao.insertArticle(_article());
      final articles = await dao.allArticles();
      expect(articles, hasLength(1));
      expect(articles.first.title, 'Test Article');
    });

    test('articleById returns correct article', () async {
      await dao.insertArticle(_article());
      final article = await dao.articleById('a1');
      expect(article, isNotNull);
      expect(article!.url, 'https://example.com');
    });

    test('deleteArticle removes article', () async {
      await dao.insertArticle(_article());
      await dao.deleteArticle('a1');
      final articles = await dao.allArticles();
      expect(articles, isEmpty);
    });
  });
}
