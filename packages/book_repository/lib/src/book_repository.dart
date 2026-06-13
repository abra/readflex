import 'dart:io';
import 'dart:typed_data';

import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart' show QueryRow, Variable;
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
///   book.<ext>    — the book file (epub, fb2, mobi, pdf, cbz, azw3)
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
        final coverDiagnostics = _CoverDiagnostics.from(
          mimeType: coverMimeType,
          data: coverData,
        );
        final coverExt =
            _extensionForDetectedFormat(coverDiagnostics.detectedFormat) ??
            _extensionForMime(coverMimeType);
        _logCoverDiagnostics(
          id: id,
          title: title,
          diagnostics: coverDiagnostics,
          extension: coverExt,
          data: coverData,
        );
        if (coverDiagnostics.isFlutterSupported) {
          coverFileName = 'cover$coverExt';
          await File(
            p.join(bookDir.path, coverFileName),
          ).writeAsBytes(coverData);
        }
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

  Future<List<SourceBookmark>> getBookmarksBySource(String sourceId) async {
    try {
      final rows = await _db
          .customSelect(
            '''
                SELECT id, source_id, source_type, cfi, content, progress,
                       chapter_title, anchor_exact, anchor_prefix,
                       anchor_suffix, anchor_section_index,
                       anchor_section_page, created_at
                FROM bookmarks_table
                WHERE source_id = ?
                ORDER BY progress ASC, created_at ASC
                ''',
            variables: [Variable<String>(sourceId)],
          )
          .get();
      return rows.map(_bookmarkRowToDomain).toList(growable: false);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<SourceBookmark> addBookmark({
    required String sourceId,
    required SourceType sourceType,
    required String cfi,
    required String content,
    required double progress,
    String? chapterTitle,
    String? anchorExact,
    String? anchorPrefix,
    String? anchorSuffix,
    int? anchorSectionIndex,
    int? anchorSectionPage,
  }) async {
    try {
      final existing = await _bookmarkBySourceAndAnchor(
        sourceId: sourceId,
        cfi: cfi,
        anchorExact: anchorExact,
        anchorPrefix: anchorPrefix,
        anchorSuffix: anchorSuffix,
        anchorSectionIndex: anchorSectionIndex,
        anchorSectionPage: anchorSectionPage,
      );
      if (existing != null) return existing;

      final bookmark = SourceBookmark(
        id: _uuid.v4(),
        sourceId: sourceId,
        sourceType: sourceType,
        cfi: cfi,
        content: content,
        progress: progress.clamp(0.0, 1.0).toDouble(),
        chapterTitle: chapterTitle,
        anchorExact: anchorExact,
        anchorPrefix: anchorPrefix,
        anchorSuffix: anchorSuffix,
        anchorSectionIndex: anchorSectionIndex,
        anchorSectionPage: anchorSectionPage,
        createdAt: DateTime.now(),
      );
      await _db.customStatement(
        '''
        INSERT INTO bookmarks_table
          (id, source_id, source_type, cfi, content, progress, chapter_title,
           anchor_exact, anchor_prefix, anchor_suffix, anchor_section_index,
           anchor_section_page, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          bookmark.id,
          bookmark.sourceId,
          bookmark.sourceType.name,
          bookmark.cfi,
          bookmark.content,
          bookmark.progress,
          bookmark.chapterTitle,
          bookmark.anchorExact,
          bookmark.anchorPrefix,
          bookmark.anchorSuffix,
          bookmark.anchorSectionIndex,
          bookmark.anchorSectionPage,
          bookmark.createdAt.toIso8601String(),
        ],
      );
      return await _bookmarkById(sourceId, bookmark.id) ?? bookmark;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> deleteBookmarkById(String sourceId, String bookmarkId) async {
    try {
      await _db.customStatement(
        '''
        DELETE FROM bookmarks_table
        WHERE source_id = ? AND id = ?
        ''',
        [sourceId, bookmarkId],
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<void> deleteBookmarkBySourceAndCfi(
    String sourceId,
    String cfi,
  ) async {
    try {
      await _db.customStatement(
        '''
        DELETE FROM bookmarks_table
        WHERE source_id = ? AND cfi = ?
        ''',
        [sourceId, cfi],
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<SourceBookmark?> _bookmarkBySourceAndAnchor({
    required String sourceId,
    required String cfi,
    required String? anchorExact,
    required String? anchorPrefix,
    required String? anchorSuffix,
    required int? anchorSectionIndex,
    required int? anchorSectionPage,
  }) async {
    if (anchorExact == null &&
        anchorPrefix == null &&
        anchorSuffix == null &&
        anchorSectionIndex == null &&
        anchorSectionPage == null) {
      return _bookmarkBySourceAndCfi(sourceId, cfi);
    }

    final row = await _db
        .customSelect(
          '''
              SELECT id, source_id, source_type, cfi, content, progress,
                     chapter_title, anchor_exact, anchor_prefix,
                     anchor_suffix, anchor_section_index,
                     anchor_section_page, created_at
              FROM bookmarks_table
              WHERE source_id = ?
                AND cfi = ?
                AND COALESCE(anchor_exact, '') = ?
                AND COALESCE(anchor_prefix, '') = ?
                AND COALESCE(anchor_suffix, '') = ?
                AND COALESCE(anchor_section_index, -1) = ?
                AND COALESCE(anchor_section_page, -1) = ?
              LIMIT 1
              ''',
          variables: [
            Variable<String>(sourceId),
            Variable<String>(cfi),
            Variable<String>(anchorExact ?? ''),
            Variable<String>(anchorPrefix ?? ''),
            Variable<String>(anchorSuffix ?? ''),
            Variable<int>(anchorSectionIndex ?? -1),
            Variable<int>(anchorSectionPage ?? -1),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _bookmarkRowToDomain(row);
  }

  Future<SourceBookmark?> _bookmarkBySourceAndCfi(
    String sourceId,
    String cfi,
  ) async {
    final row = await _db
        .customSelect(
          '''
              SELECT id, source_id, source_type, cfi, content, progress,
                     chapter_title, anchor_exact, anchor_prefix,
                     anchor_suffix, anchor_section_index,
                     anchor_section_page, created_at
              FROM bookmarks_table
              WHERE source_id = ? AND cfi = ?
              LIMIT 1
              ''',
          variables: [Variable<String>(sourceId), Variable<String>(cfi)],
        )
        .getSingleOrNull();
    return row == null ? null : _bookmarkRowToDomain(row);
  }

  Future<SourceBookmark?> _bookmarkById(
    String sourceId,
    String bookmarkId,
  ) async {
    final row = await _db
        .customSelect(
          '''
              SELECT id, source_id, source_type, cfi, content, progress,
                     chapter_title, anchor_exact, anchor_prefix,
                     anchor_suffix, anchor_section_index,
                     anchor_section_page, created_at
              FROM bookmarks_table
              WHERE source_id = ? AND id = ?
              LIMIT 1
              ''',
          variables: [
            Variable<String>(sourceId),
            Variable<String>(bookmarkId),
          ],
        )
        .getSingleOrNull();
    return row == null ? null : _bookmarkRowToDomain(row);
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
        await _db.customStatement(
          'DELETE FROM bookmarks_table WHERE source_id = ?',
          [id],
        );
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

  SourceBookmark _bookmarkRowToDomain(QueryRow row) {
    return SourceBookmark(
      id: row.read<String>('id'),
      sourceId: row.read<String>('source_id'),
      sourceType: SourceType.from(row.read<String>('source_type')),
      cfi: row.read<String>('cfi'),
      content: row.read<String>('content'),
      progress: row.read<double>('progress').clamp(0.0, 1.0).toDouble(),
      chapterTitle: row.readNullable<String>('chapter_title'),
      anchorExact: row.readNullable<String>('anchor_exact'),
      anchorPrefix: row.readNullable<String>('anchor_prefix'),
      anchorSuffix: row.readNullable<String>('anchor_suffix'),
      anchorSectionIndex: row.readNullable<int>('anchor_section_index'),
      anchorSectionPage: row.readNullable<int>('anchor_section_page'),
      createdAt: DateTime.parse(row.read<String>('created_at')),
    );
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
    return switch (_normalizedMime(mime)) {
      'image/jpeg' || 'image/jpg' => '.jpeg',
      'image/png' => '.png',
      'image/gif' => '.gif',
      'image/webp' => '.webp',
      _ => '.jpeg',
    };
  }

  void _logCoverDiagnostics({
    required String id,
    required String title,
    required _CoverDiagnostics diagnostics,
    required String extension,
    required Uint8List data,
  }) {
    if (!diagnostics.isSuspicious) return;

    _logger?.warn(
      'BookRepository: suspicious cover data '
      '(bookId=$id, title="$title", mime=${diagnostics.mimeType}, '
      'ext=$extension, bytes=${data.length}, '
      'detected=${diagnostics.detectedFormat}, '
      'signature=${diagnostics.signature})',
    );
  }
}

String? _extensionForDetectedFormat(String format) {
  return switch (format) {
    'jpeg' => '.jpeg',
    'png' => '.png',
    'gif' => '.gif',
    'webp' => '.webp',
    _ => null,
  };
}

/// Signature and MIME diagnostics for imported cover bytes.
///
/// Used only for warning logs and extension correction; image decoding still
/// happens in Flutter's image pipeline.
final class _CoverDiagnostics {
  const _CoverDiagnostics({
    required this.mimeType,
    required this.detectedFormat,
    required this.signature,
    required this.isSuspicious,
    required this.isFlutterSupported,
  });

  final String mimeType;
  final String detectedFormat;
  final String signature;
  final bool isSuspicious;
  final bool isFlutterSupported;

  static _CoverDiagnostics from({
    required String? mimeType,
    required Uint8List data,
  }) {
    final normalizedMime = _normalizedMime(mimeType) ?? '<none>';
    final mimeFormat = _formatForMime(mimeType);
    final detectedFormat = _detectImageFormat(data);
    final supportedFormat = _isFlutterImageFormat(detectedFormat);
    final mismatch =
        mimeFormat != null && supportedFormat && mimeFormat != detectedFormat;

    return _CoverDiagnostics(
      mimeType: normalizedMime,
      detectedFormat: detectedFormat,
      signature: _hexSignature(data),
      isFlutterSupported: supportedFormat,
      isSuspicious:
          data.isEmpty || !supportedFormat || mimeFormat == 'svg' || mismatch,
    );
  }
}

String? _normalizedMime(String? mime) {
  final normalized = mime?.split(';').first.trim().toLowerCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String? _formatForMime(String? mime) {
  return switch (_normalizedMime(mime)) {
    'image/jpeg' || 'image/jpg' => 'jpeg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/svg+xml' => 'svg',
    _ => null,
  };
}

bool _isFlutterImageFormat(String format) {
  return switch (format) {
    'jpeg' || 'png' || 'gif' || 'webp' => true,
    _ => false,
  };
}

String _detectImageFormat(Uint8List data) {
  if (data.isEmpty) return 'empty';
  if (data.length >= 3 &&
      data[0] == 0xFF &&
      data[1] == 0xD8 &&
      data[2] == 0xFF) {
    return 'jpeg';
  }
  if (data.length >= 8 &&
      data[0] == 0x89 &&
      data[1] == 0x50 &&
      data[2] == 0x4E &&
      data[3] == 0x47 &&
      data[4] == 0x0D &&
      data[5] == 0x0A &&
      data[6] == 0x1A &&
      data[7] == 0x0A) {
    return 'png';
  }
  if (data.length >= 6) {
    final header = String.fromCharCodes(data.take(6));
    if (header == 'GIF87a' || header == 'GIF89a') return 'gif';
  }
  if (data.length >= 12) {
    final riff = String.fromCharCodes(data.take(4));
    final webp = String.fromCharCodes(data.skip(8).take(4));
    if (riff == 'RIFF' && webp == 'WEBP') return 'webp';
  }

  final prefix = String.fromCharCodes(data.take(512)).trimLeft().toLowerCase();
  if (prefix.startsWith('<svg') ||
      (prefix.startsWith('<?xml') && prefix.contains('<svg'))) {
    return 'svg';
  }

  return 'unknown';
}

String _hexSignature(Uint8List data) {
  if (data.isEmpty) return '<empty>';
  final length = data.length < 12 ? data.length : 12;
  return data
      .take(length)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join(' ');
}
