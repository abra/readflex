import 'dart:io';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:monitoring/monitoring.dart';
import 'package:reader_webview/reader_webview.dart';

/// Supported book file extensions for the file picker.
const bookExtensions = ['epub', 'fb2', 'mobi', 'pdf', 'azw3', 'cbz', 'txt'];

/// Opens a file picker, extracts metadata via foliate-js, and saves the
/// book to the repository. Returns `true` if a book was successfully added.
Future<bool> importBook({
  required BookRepository bookRepository,
  required int readerServerPort,
  required Logger logger,
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: bookExtensions,
  );
  if (result == null || result.files.isEmpty) return false;

  final pickedFile = result.files.first;
  final filePath = pickedFile.path;
  if (filePath == null) return false;

  final sourceFile = File(filePath);
  final ext = filePath.split('.').last.toLowerCase();

  // Map azw3 to mobi (KF8 variant), cbz/txt to epub fallback for format enum.
  final format = BookFormat.fromExtension(ext) ?? BookFormat.epub;

  try {
    final extractor = BookMetadataExtractor(serverPort: readerServerPort);
    final metadata = await extractor.extract(filePath);

    await bookRepository.addBook(
      sourceFile: sourceFile,
      title: metadata.title,
      format: format,
      author: metadata.author,
      coverData: metadata.coverData,
      coverMimeType: metadata.coverMimeType,
    );

    return true;
  } catch (e, st) {
    logger.warn('Book import failed', error: e, stackTrace: st);
    return false;
  }
}
