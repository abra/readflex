import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;

import 'package:book_repository/src/mappers/book_to_domain.dart';
import 'package:book_repository/src/mappers/book_to_storage.dart';

void main() {
  final now = DateTime(2026, 4, 1);
  late Directory booksDir;

  setUp(() {
    booksDir = Directory.systemTemp.createTempSync('books_test_');
  });

  tearDown(() {
    if (booksDir.existsSync()) booksDir.deleteSync(recursive: true);
  });

  group('BookToDomain', () {
    test('resolves paths against books directory', () {
      final row = BooksTableData(
        id: 'b1',
        title: 'Test Book',
        author: 'Author',
        coverImagePath: 'cover.jpg',
        format: 'epub',
        filePath: 'book.epub',
        totalLocations: 1000,
        currentLocation: 50,
        currentCfi: 'epubcfi(/6/4)',
        readingProgress: 0.05,
        addedAt: now.toIso8601String(),
        lastOpenedAt: now.toIso8601String(),
        isFinished: false,
      );

      final book = row.toDomainModel(booksDir: booksDir);
      final expectedDir = p.join(booksDir.path, 'b1');

      expect(book.id, 'b1');
      expect(book.title, 'Test Book');
      expect(book.author, 'Author');
      expect(book.coverImagePath, p.join(expectedDir, 'cover.jpg'));
      expect(book.format, BookFormat.epub);
      expect(book.filePath, p.join(expectedDir, 'book.epub'));
      expect(book.totalLocations, 1000);
      expect(book.currentLocation, 50);
      expect(book.currentCfi, 'epubcfi(/6/4)');
      expect(book.readingProgress, 0.05);
      expect(book.addedAt, now);
      expect(book.lastOpenedAt, now);
      expect(book.isFinished, false);
    });

    test('handles null optional fields', () {
      final row = BooksTableData(
        id: 'b2',
        title: 'Minimal',
        author: null,
        coverImagePath: null,
        format: 'pdf',
        filePath: 'doc.pdf',
        totalLocations: 0,
        currentLocation: 0,
        currentCfi: null,
        readingProgress: 0.0,
        addedAt: now.toIso8601String(),
        lastOpenedAt: null,
        isFinished: false,
      );

      final book = row.toDomainModel(booksDir: booksDir);

      expect(book.author, isNull);
      expect(book.coverImagePath, isNull);
      expect(book.currentCfi, isNull);
      expect(book.lastOpenedAt, isNull);
    });

    test('falls back to epoch for invalid date', () {
      final row = BooksTableData(
        id: 'b3',
        title: 'T',
        author: null,
        coverImagePath: null,
        format: 'epub',
        filePath: 'f.epub',
        totalLocations: 0,
        currentLocation: 0,
        currentCfi: null,
        readingProgress: 0.0,
        addedAt: 'invalid',
        lastOpenedAt: null,
        isFinished: false,
      );

      expect(
        row.toDomainModel(booksDir: booksDir).addedAt,
        DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
  });

  group('BookToStorage', () {
    test('maps all fields from domain to companion', () {
      final book = Book(
        id: 'b1',
        title: 'Test Book',
        author: 'Author',
        coverImagePath: '/path/cover.jpg',
        format: BookFormat.epub,
        filePath: '/path/book.epub',
        totalLocations: 1000,
        currentLocation: 50,
        currentCfi: 'epubcfi(/6/4)',
        readingProgress: 0.05,
        addedAt: now,
        lastOpenedAt: now,
      );

      final companion = book.toStorageModel();

      expect(companion.id, const Value('b1'));
      expect(companion.title, const Value('Test Book'));
      expect(companion.author, const Value('Author'));
      expect(companion.coverImagePath, const Value('/path/cover.jpg'));
      expect(companion.format, const Value('epub'));
      expect(companion.filePath, const Value('/path/book.epub'));
      expect(companion.totalLocations, const Value(1000));
      expect(companion.currentLocation, const Value(50));
      expect(companion.currentCfi, const Value('epubcfi(/6/4)'));
      expect(companion.readingProgress, const Value(0.05));
      expect(companion.addedAt, Value(now.toIso8601String()));
      expect(companion.lastOpenedAt, Value(now.toIso8601String()));
      expect(companion.isFinished, const Value(false));
    });

    test('handles null optional fields', () {
      final book = Book(
        id: 'b2',
        title: 'Minimal',
        format: BookFormat.pdf,
        filePath: '/path/doc.pdf',
        addedAt: now,
      );

      final companion = book.toStorageModel();

      expect(companion.author, const Value(null));
      expect(companion.coverImagePath, const Value(null));
      expect(companion.currentCfi, const Value(null));
      expect(companion.lastOpenedAt, const Value(null));
    });
  });
}
