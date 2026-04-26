import 'dart:io';
import 'dart:typed_data';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late Directory tempDir;
  late Directory booksDir;
  late BookRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('book_repo_test_');
    booksDir = Directory(p.join(tempDir.path, 'books'));
    await booksDir.create();
    repo = BookRepository(database: db, booksDirectory: booksDir);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a temporary epub file with dummy content for testing.
  Future<File> createTempBookFile({String name = 'test.epub'}) async {
    final file = File(p.join(tempDir.path, name));
    await file.writeAsString('fake-epub-content');
    return file;
  }

  group('BookRepository', () {
    test('addBook copies file and returns book with resolved paths', () async {
      final sourceFile = await createTempBookFile();
      final book = await repo.addBook(
        sourceFile: sourceFile,
        title: 'My Book',
        format: BookFormat.epub,
        author: 'Author',
      );

      expect(book.title, 'My Book');
      expect(book.author, 'Author');
      expect(book.format, BookFormat.epub);
      expect(book.id, isNotEmpty);

      // File was copied into books/<uuid>/book.epub.
      expect(File(book.filePath).existsSync(), isTrue);
      expect(book.filePath, contains('book.epub'));
      expect(book.filePath, contains(book.id));
    });

    test('addBook saves cover image when provided', () async {
      final sourceFile = await createTempBookFile();
      final coverData = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

      final book = await repo.addBook(
        sourceFile: sourceFile,
        title: 'With Cover',
        format: BookFormat.epub,
        coverData: coverData,
        coverMimeType: 'image/jpeg',
      );

      expect(book.coverImagePath, isNotNull);
      expect(File(book.coverImagePath!).existsSync(), isTrue);
      expect(book.coverImagePath, contains('cover.jpeg'));

      final savedBytes = await File(book.coverImagePath!).readAsBytes();
      expect(savedBytes, coverData);
    });

    test('addBook works without cover', () async {
      final sourceFile = await createTempBookFile();
      final book = await repo.addBook(
        sourceFile: sourceFile,
        title: 'No Cover',
        format: BookFormat.fb2,
      );

      expect(book.coverImagePath, isNull);
    });

    test('addBook preserves file extension', () async {
      final sourceFile = await createTempBookFile(name: 'book.fb2');
      final book = await repo.addBook(
        sourceFile: sourceFile,
        title: 'FB2 Book',
        format: BookFormat.fb2,
      );

      expect(book.filePath, endsWith('book.fb2'));
    });

    test('getBooks returns all added books with resolved paths', () async {
      await repo.addBook(
        sourceFile: await createTempBookFile(name: '1.epub'),
        title: 'Book 1',
        format: BookFormat.epub,
      );
      await repo.addBook(
        sourceFile: await createTempBookFile(name: '2.fb2'),
        title: 'Book 2',
        format: BookFormat.fb2,
      );

      final books = await repo.getBooks();
      expect(books, hasLength(2));

      for (final book in books) {
        expect(File(book.filePath).existsSync(), isTrue);
      }
    });

    test('getBookById returns correct book', () async {
      final created = await repo.addBook(
        sourceFile: await createTempBookFile(),
        title: 'Find Me',
        format: BookFormat.epub,
      );

      final found = await repo.getBookById(created.id);
      expect(found, isNotNull);
      expect(found!.title, 'Find Me');
      expect(File(found.filePath).existsSync(), isTrue);
    });

    test('getBookById returns null for missing id', () async {
      final found = await repo.getBookById('missing');
      expect(found, isNull);
    });

    test('updateBook persists changes', () async {
      final created = await repo.addBook(
        sourceFile: await createTempBookFile(),
        title: 'Original',
        format: BookFormat.epub,
      );

      final updated = created.copyWith(
        title: 'Updated',
        readingProgress: 0.5,
      );
      await repo.updateBook(updated);

      final fetched = await repo.getBookById(created.id);
      expect(fetched!.title, 'Updated');
      expect(fetched.readingProgress, 0.5);
    });

    test('updateBook preserves paths after round-trip', () async {
      final created = await repo.addBook(
        sourceFile: await createTempBookFile(),
        title: 'Round Trip',
        format: BookFormat.epub,
        coverData: Uint8List.fromList([0xFF, 0xD8]),
        coverMimeType: 'image/jpeg',
      );

      // created has resolved (absolute) paths from addBook.
      expect(created.filePath, contains(booksDir.path));
      expect(created.coverImagePath, contains(booksDir.path));

      // Update with the resolved book (simulates reader saving progress).
      await repo.updateBook(created.copyWith(readingProgress: 0.7));

      // After re-reading, paths should still be valid absolute paths.
      final fetched = await repo.getBookById(created.id);
      expect(fetched!.readingProgress, 0.7);
      expect(File(fetched.filePath).existsSync(), isTrue);
      expect(File(fetched.coverImagePath!).existsSync(), isTrue);
    });

    test('deleteBook removes book from DB and disk', () async {
      final created = await repo.addBook(
        sourceFile: await createTempBookFile(),
        title: 'Delete Me',
        format: BookFormat.epub,
      );

      final bookDir = Directory(p.join(booksDir.path, created.id));
      expect(bookDir.existsSync(), isTrue);

      await repo.deleteBook(created.id);

      final books = await repo.getBooks();
      expect(books, isEmpty);
      expect(bookDir.existsSync(), isFalse);
    });

    test('deleteBook cascades to highlights, flashcards, dictionary,'
        ' and review items', () async {
      final created = await repo.addBook(
        sourceFile: await createTempBookFile(),
        title: 'Cascade source',
        format: BookFormat.epub,
      );
      final otherBook = await repo.addBook(
        sourceFile: await createTempBookFile(name: 'other.epub'),
        title: 'Untouched',
        format: BookFormat.epub,
      );

      // Seed dependents linked to the book being deleted.
      await db.highlightsDao.insertHighlight(
        HighlightsTableCompanion.insert(
          id: 'h-1',
          sourceId: created.id,
          sourceType: 'book',
          highlightText: 'foo',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await db.flashcardsDao.insertFlashcard(
        FlashcardsTableCompanion.insert(
          id: 'f-1',
          deckId: created.id,
          front: 'Q',
          back: 'A',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await db.dictionaryDao.insertEntry(
        DictionaryTableCompanion.insert(
          id: 'd-1',
          word: 'word',
          translation: 'слово',
          addedAt: DateTime.now().toIso8601String(),
          sourceId: Value(created.id),
        ),
      );
      await db.reviewItemsDao.insertItem(
        ReviewItemsTableCompanion.insert(
          itemId: 'h-1',
          itemType: 'highlight',
          sourceId: Value(created.id),
        ),
      );
      // A second review item tied to the OTHER book — must survive the
      // cascade so we can prove deletion is scoped to the right source.
      await db.highlightsDao.insertHighlight(
        HighlightsTableCompanion.insert(
          id: 'h-keep',
          sourceId: otherBook.id,
          sourceType: 'book',
          highlightText: 'untouched',
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
      await db.reviewItemsDao.insertItem(
        ReviewItemsTableCompanion.insert(
          itemId: 'h-keep',
          itemType: 'highlight',
          sourceId: Value(otherBook.id),
        ),
      );

      await repo.deleteBook(created.id);

      expect(
        await db.highlightsDao.highlightsBySource(created.id),
        isEmpty,
      );
      expect(
        await db.flashcardsDao.flashcardsByDeck(created.id),
        isEmpty,
      );
      expect(
        await db.dictionaryDao.entriesBySource(created.id),
        isEmpty,
      );
      expect(await db.reviewItemsDao.byItemId('h-1'), isNull);

      // Other book's data must survive — proves cascade is scoped.
      expect(
        await db.highlightsDao.highlightsBySource(otherBook.id),
        hasLength(1),
      );
      expect(await db.reviewItemsDao.byItemId('h-keep'), isNotNull);
    });

    test('deleteBook handles missing directory gracefully', () async {
      final created = await repo.addBook(
        sourceFile: await createTempBookFile(),
        title: 'Already Gone',
        format: BookFormat.epub,
      );

      // Manually delete directory before repo does.
      final bookDir = Directory(p.join(booksDir.path, created.id));
      await bookDir.delete(recursive: true);

      // Should not throw.
      await repo.deleteBook(created.id);

      final books = await repo.getBooks();
      expect(books, isEmpty);
    });

    test('addBook with png cover uses .png extension', () async {
      final sourceFile = await createTempBookFile();
      final coverData = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]);

      final book = await repo.addBook(
        sourceFile: sourceFile,
        title: 'PNG Cover',
        format: BookFormat.epub,
        coverData: coverData,
        coverMimeType: 'image/png',
      );

      expect(book.coverImagePath, contains('cover.png'));
    });

    test('source file is not modified after import', () async {
      final sourceFile = await createTempBookFile();
      final originalContent = await sourceFile.readAsString();

      await repo.addBook(
        sourceFile: sourceFile,
        title: 'Copy Test',
        format: BookFormat.epub,
      );

      // Source file should still exist and be unchanged.
      expect(sourceFile.existsSync(), isTrue);
      expect(await sourceFile.readAsString(), originalContent);
    });
  });
}
