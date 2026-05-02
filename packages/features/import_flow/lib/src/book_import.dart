import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:monitoring/monitoring.dart';
import 'package:reader_webview/reader_webview.dart';

/// Supported book file extensions for the file picker. Mirrors the
/// formats foliate-js (the in-app reader) can actually render — the
/// list and `BookFormat` must stay in sync, otherwise the picker
/// would let the user import a file that can never actually open.
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
  } on BookImportException catch (e, st) {
    // Bubble up the typed exception so callers can use its `message`
    // (the JS-side reason from foliate-js) in the failure UI. Still
    // log it so the warning shows up alongside other warnings.
    logger.warn('Book import failed', error: e, stackTrace: st);
    rethrow;
  } catch (e, st) {
    logger.warn('Book import failed', error: e, stackTrace: st);
    return null;
  }
}
