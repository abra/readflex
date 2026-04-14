import 'dart:io';
import 'dart:typed_data';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/book_to_domain.dart';
import 'mappers/book_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for books.
///
/// Wraps [BooksDao] from `local_storage` and owns on-disk storage of
/// book files and cover images. Each book lives in its own directory
/// under [booksDirectory]:
///
/// ```
/// books/<uuid>/
///   book.<ext>    — the book file (epub, fb2, mobi, pdf)
///   cover.<ext>   — extracted cover image (if available)
/// ```
///
/// The DB row stores only filenames (`book.epub`, `cover.jpeg`) —
/// this repo resolves them against the per-book directory on every read,
/// so the DB survives iOS Documents-UUID changes.
class BookRepository {
  BookRepository({
    required AppDatabase database,
    required Directory booksDirectory,
  }) : _dao = database.booksDao,
       _booksDir = booksDirectory;

  final BooksDao _dao;
  final Directory _booksDir;

  Future<List<Book>> getBooks() async {
    try {
      final rows = await _dao.allBooks();
      return rows.map(_rowToDomain).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Book?> getBookById(String id) async {
    try {
      final row = await _dao.bookById(id);
      return row != null ? _rowToDomain(row) : null;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Imports a book from [sourceFile] into the repository.
  ///
  /// Copies the file to `books/<uuid>/book.<ext>`, optionally saves
  /// [coverData] as `cover.<ext>`, and creates the DB row.
  Future<Book> addBook({
    required File sourceFile,
    required String title,
    required BookFormat format,
    String? author,
    Uint8List? coverData,
    String? coverMimeType,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now();

      // Create per-book directory.
      final bookDir = Directory(p.join(_booksDir.path, id));
      await bookDir.create(recursive: true);

      // Copy book file.
      final ext = p.extension(sourceFile.path).toLowerCase();
      final bookFileName = 'book$ext';
      await sourceFile.copy(p.join(bookDir.path, bookFileName));

      // Save cover image.
      String? coverFileName;
      if (coverData != null) {
        final coverExt = _extensionForMime(coverMimeType);
        coverFileName = 'cover$coverExt';
        await File(
          p.join(bookDir.path, coverFileName),
        ).writeAsBytes(coverData);
      }

      final book = Book(
        id: id,
        title: title,
        filePath: bookFileName,
        format: format,
        addedAt: now,
        author: author,
        coverImagePath: coverFileName,
      );
      await _dao.insertBook(book.toStorageModel());
      return _resolve(book);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Book> updateBook(Book book) async {
    try {
      // The caller works with resolved (absolute) paths, but the DB must
      // store only filenames so toDomainModel can re-resolve them against
      // the current booksDir on every read.
      final storageBook = _unresolve(book);
      await _dao.updateBook(storageBook.toStorageModel());
      return book;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Deletes the book from DB and removes its directory from disk.
  Future<void> deleteBook(String id) async {
    try {
      await _dao.deleteBook(id);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
    // Best-effort cleanup — orphaned dirs get reclaimed on maintenance pass.
    final bookDir = Directory(p.join(_booksDir.path, id));
    try {
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
    } catch (_) {}
  }

  // ── Helpers ──

  Book _rowToDomain(BooksTableData row) {
    return row.toDomainModel(booksDir: _booksDir);
  }

  /// Strips absolute paths back to relative filenames for DB storage.
  ///
  /// The inverse of [_resolve]. If the path is already relative (just a
  /// filename), returns it as-is.
  Book _unresolve(Book book) {
    return book.copyWith(
      filePath: p.basename(book.filePath),
      coverImagePath: book.coverImagePath != null
          ? p.basename(book.coverImagePath!)
          : null,
    );
  }

  /// Resolves relative paths in a newly created [Book] to absolute paths.
  Book _resolve(Book book) {
    final bookDir = p.join(_booksDir.path, book.id);
    return book.copyWith(
      filePath: p.join(bookDir, book.filePath),
      coverImagePath: book.coverImagePath != null
          ? p.join(bookDir, book.coverImagePath!)
          : null,
    );
  }

  static String _extensionForMime(String? mime) {
    return switch (mime) {
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      _ => '.jpeg',
    };
  }
}
