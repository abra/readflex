import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:monitoring/monitoring.dart';
import 'package:reader_webview/reader_webview.dart';

/// Supported book file extensions for the file picker. .txt is not
/// in the list because foliate-js (the in-app reader) has no plain
/// text renderer — accepting a .txt would let the user import a file
/// that can never actually open.
const bookExtensions = ['epub', 'fb2', 'mobi', 'pdf', 'azw3', 'cbz'];

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
/// Pulls metadata via foliate-js and forwards [onProgress] to
/// [BookRepository.addBook] so callers can show a real progress bar
/// during the byte-copy phase. Returns the persisted [Book] on success
/// or `null` if any step fails (the failure is logged).
Future<Book?> importBookFile({
  required File sourceFile,
  required BookRepository bookRepository,
  required int readerServerPort,
  required Logger logger,
  void Function(double progress)? onProgress,
}) async {
  final filePath = sourceFile.path;
  final ext = filePath.split('.').last.toLowerCase();
  final format = BookFormat.fromExtension(ext) ?? BookFormat.epub;

  try {
    final extractor = BookMetadataExtractor(serverPort: readerServerPort);
    final metadata = await extractor.extract(filePath);

    return await bookRepository.addBook(
      sourceFile: sourceFile,
      title: metadata.title,
      format: format,
      author: metadata.author,
      coverData: metadata.coverData,
      coverMimeType: metadata.coverMimeType,
      onProgress: onProgress,
    );
  } catch (e, st) {
    logger.warn('Book import failed', error: e, stackTrace: st);
    return null;
  }
}

/// Backwards-compatible single-call helper for callers that don't need
/// progress tracking. Picks a file, imports it, and returns whether a
/// book was successfully added. Newer callers should prefer
/// [pickBookFile] + [importBookFile] so they can show progress.
Future<bool> importBook({
  required BookRepository bookRepository,
  required int readerServerPort,
  required Logger logger,
}) async {
  final file = await pickBookFile();
  if (file == null) return false;
  final book = await importBookFile(
    sourceFile: file,
    bookRepository: bookRepository,
    readerServerPort: readerServerPort,
    logger: logger,
  );
  return book != null;
}
