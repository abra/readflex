import 'dart:io';
import 'dart:typed_data';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
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
