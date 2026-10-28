import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:monitoring/monitoring.dart';
import 'package:vellum/vellum.dart'
    show
        BookMetadata,
        VellumException,
        readComicMetadata,
        readEpubMetadata,
        readFb2Metadata,
        readMobiMetadata,
        readPdfMetadata;

import 'book_import_exception.dart';

/// Supported book file extensions for the file picker. Mirrors the
/// formats the in-app reader can actually render — the list and
/// `BookFormat` must stay in sync, otherwise the picker would let the
/// user import a file that can never actually open.
const bookExtensions = [
  'epub',
  'fb2',
  'mobi',
  'pdf',
  'azw3',
  'cbz',
];

/// Formats whose metadata the native engine reads; grows as `vellum`
/// takes formats over from the WebView.

/// Opens the platform file picker filtered to [bookExtensions]. Returns
/// the selected [File] or `null` when the user cancels (or picks a file
/// without a usable path).
Future<File?> pickBookFile() async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: bookExtensions,
  );
  if (result == null || result.files.isEmpty) return null;
  final filePath = result.files.first.path;
  if (filePath == null) return null;
  return File(filePath);
}

/// Imports an already-picked [sourceFile] into the repository.
///
/// Reads the title, author and cover with `vellum` (the format from the
/// file's extension, EPUB when it has none) and persists via
/// [BookRepository.addBook], forwarding [onProgress] so callers can show
/// a real progress bar during the byte-copy phase. Returns the persisted
/// [Book] on success or `null` if any step fails (the failure is logged);
/// a file the engine refuses throws [BookImportException] with its reason.
Future<Book?> importBookFile({
  required File sourceFile,
  required BookRepository bookRepository,
  required Logger logger,
  void Function(double progress)? onProgress,
}) async {
  final filePath = sourceFile.path;
  final ext = filePath.split('.').last.toLowerCase();
  final format = BookFormat.fromExtension(ext) ?? BookFormat.epub;

  try {
    final metadata = await _readMetadata(filePath, format);
    return await bookRepository.addBook(
      sourceFile: sourceFile,
      title: metadata.title,
      format: format,
      author: metadata.author,
      coverData: metadata.cover?.bytes,
      coverMimeType: metadata.cover?.mimeType,
      onProgress: onProgress,
    );
  } on BookImportException catch (e, st) {
    // Bubble up the typed exception so callers can use its `message`
    // (the engine's reason) in the failure UI. Still log it so the
    // warning shows up alongside other warnings.
    logger.warn('Book import failed', error: e, stackTrace: st);
    rethrow;
  } catch (e, st) {
    logger.warn('Book import failed', error: e, stackTrace: st);
    return null;
  }
}

Future<BookMetadata> _readMetadata(String filePath, BookFormat format) async {
  try {
    return switch (format) {
      BookFormat.pdf => await readPdfMetadata(filePath),
      BookFormat.epub => await readEpubMetadata(filePath),
      BookFormat.fb2 => await readFb2Metadata(filePath),
      BookFormat.mobi || BookFormat.azw3 => await readMobiMetadata(filePath),
      BookFormat.cbz => await readComicMetadata(filePath),
    };
  } on VellumException catch (e) {
    throw BookImportException(e.message);
  }
}
