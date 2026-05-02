import 'dart:io';
import 'dart:typed_data';

import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monitoring/monitoring.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart' show Uuid;

import 'book_deletion_scope.dart';
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
    Logger? logger,
  }) : _db = database,
       _dao = database.booksDao,
       _booksDir = booksDirectory,
       _logger = logger;

  final AppDatabase _db;
  final BooksDao _dao;
  final Directory _booksDir;
  final Logger? _logger;

  Future<List<Book>> getBooks({int? limit, int? offset}) async {
    try {
      final rows = await _dao.allBooks(limit: limit, offset: offset);
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
  ///
  /// When [onProgress] is provided the copy is streamed chunk-by-chunk so
  /// the caller can show a real progress bar. Progress values are mapped
  /// `0.0..0.95` for the byte-copy phase and reach `1.0` after cover and
  /// DB rows are written. When `null` the function uses [File.copy] for
  /// the fast path.
  Future<Book> addBook({
    required File sourceFile,
    required String title,
    required BookFormat format,
    String? author,
    Uint8List? coverData,
    String? coverMimeType,
    void Function(double progress)? onProgress,
  }) async {
    final id = _uuid.v4();
    final bookDir = Directory(p.join(_booksDir.path, id));
    try {
      final now = DateTime.now();

      // Create per-book directory.
      await bookDir.create(recursive: true);

      // Copy book file.
      final ext = p.extension(sourceFile.path).toLowerCase();
      final bookFileName = 'book$ext';
      final destPath = p.join(bookDir.path, bookFileName);

      if (onProgress != null) {
        onProgress(0);
        final total = await sourceFile.length();
        final sink = File(destPath).openWrite();
        var copied = 0;
        try {
          await for (final chunk in sourceFile.openRead()) {
            sink.add(chunk);
            copied += chunk.length;
            // Reserve last 5% of the bar for cover + DB insert below.
            final scaled = total == 0 ? 0.95 : (copied / total) * 0.95;
            onProgress(scaled.clamp(0.0, 0.95));
          }
          await sink.flush();
        } finally {
          await sink.close();
        }
      } else {
        await sourceFile.copy(destPath);
      }

      // Save cover image.
      String? coverFileName;
      if (coverData != null) {
        final coverExt = _extensionForMime(coverMimeType);
        coverFileName = 'cover$coverExt';
        await File(
          p.join(bookDir.path, coverFileName),
        ).writeAsBytes(coverData);
      }
      onProgress?.call(0.98);

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
      onProgress?.call(1.0);
      return _resolve(book);
    } catch (e, st) {
      // Best-effort cleanup of the partially-written directory so a
      // long sequence of failed imports doesn't accumulate orphan
      // bytes on disk. Swallowed if the directory isn't there or
      // can't be removed; the original exception still propagates.
      try {
        if (await bookDir.exists()) {
          await bookDir.delete(recursive: true);
        }
      } catch (_) {}
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

  /// Deletes the book in a single transaction. The fate of dependent
  /// rows (highlights, flashcards, dictionary entries, FSRS review state)
  /// is decided by [scope]:
  ///
  ///   * [BookDeletionScope.keepLearningData] (default) — only the book
  ///     row, its highlights and the highlight FSRS state are purged.
  ///     Saved flashcards keep their dead `deckId` (Practice surfaces
  ///     them by id, not by deck) and dictionary entries are detached
  ///     from the book by nulling their `sourceId`. The user keeps
  ///     everything they explicitly added to learn.
  ///   * [BookDeletionScope.deleteEverything] — full cascade: every
  ///     row that referenced this book id is removed alongside the book.
  ///
  /// File cleanup of the per-book directory is best-effort and runs
  /// after the DB transaction commits, so a filesystem error can't roll
  /// back the row deletes (orphaned directories are recoverable; a
  /// half-deleted DB state is not).
  Future<void> deleteBook(
    String id, {
    BookDeletionScope scope = BookDeletionScope.keepLearningData,
  }) async {
    try {
      await _db.transaction(() async {
        switch (scope) {
          case BookDeletionScope.keepLearningData:
            // Highlights are anchored to text positions inside this book
            // file — they have no meaning once the file is gone. Carry
            // their FSRS rows with them.
            await _db.reviewItemsDao.deleteItemsBySourceAndType(
              id,
              ReviewableType.highlight.name,
            );
            await _db.highlightsDao.deleteHighlightsBySource(id);
            // Detach saved words from the source so the user still sees
            // them in Dictionary without dangling FK-style references.
            await _db.dictionaryDao.clearSourceForEntries(id);
          case BookDeletionScope.deleteEverything:
            await _db.reviewItemsDao.deleteItemsBySource(id);
            await _db.highlightsDao.deleteHighlightsBySource(id);
            await _db.flashcardsDao.deleteFlashcardsByDeck(id);
            await _db.dictionaryDao.deleteEntriesBySource(id);
        }
        await _dao.deleteBook(id);
      });
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
    // Best-effort cleanup — DB row is gone, so the user-visible delete
    // succeeded; an orphaned directory is recoverable. Log instead of
    // swallowing so a permission/lock failure shows up in observability.
    final bookDir = Directory(p.join(_booksDir.path, id));
    try {
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
    } catch (e, st) {
      _logger?.warn(
        'BookRepository: failed to delete book directory ${bookDir.path}',
        error: e,
        stackTrace: st,
      );
    }
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
