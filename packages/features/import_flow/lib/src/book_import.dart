import 'dart:io';
import 'dart:typed_data';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:monitoring/monitoring.dart';
import 'package:reader_webview/reader_webview.dart'
    show BookImportException, BookMetadataExtractor;
import 'package:vellum/vellum.dart'
    show VellumException, readComicMetadata, readPdfMetadata;

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
const _nativeImportFormats = {BookFormat.cbz, BookFormat.pdf};

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
/// Reads the metadata with `vellum` when the file's format is in
/// [nativeFormats] (the formats the native reader draws) and the engine
/// reads that format; otherwise with foliate-js in a headless WebView.
/// Forwards [onProgress] to [BookRepository.addBook] so callers can show a
/// real progress bar during the byte-copy phase. Returns the persisted
/// [Book] on success or `null` if any step fails (the failure is logged).
Future<Book?> importBookFile({
  required File sourceFile,
  required BookRepository bookRepository,
  required Uri readerServerBaseUri,
  required Logger logger,
  Set<BookFormat> nativeFormats = const {},
  void Function(double progress)? onProgress,
}) async {
  final filePath = sourceFile.path;
  final ext = filePath.split('.').last.toLowerCase();
  final format = BookFormat.fromExtension(ext) ?? BookFormat.epub;

  try {
    final native =
        nativeFormats.contains(format) && _nativeImportFormats.contains(format);
    final metadata = native
        ? await _readNativeMetadata(filePath, format)
        : await _readWebViewMetadata(filePath, readerServerBaseUri);

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
    // (the engine's reason) in the failure UI. Still log it so the
    // warning shows up alongside other warnings.
    logger.warn('Book import failed', error: e, stackTrace: st);
    rethrow;
  } catch (e, st) {
    logger.warn('Book import failed', error: e, stackTrace: st);
    return null;
  }
}

typedef _ImportedMetadata = ({
  String title,
  String? author,
  Uint8List? coverData,
  String? coverMimeType,
});

Future<_ImportedMetadata> _readNativeMetadata(
  String filePath,
  BookFormat format,
) async {
  try {
    final metadata = switch (format) {
      BookFormat.pdf => await readPdfMetadata(filePath),
      _ => await readComicMetadata(filePath),
    };
    return (
      title: metadata.title,
      author: metadata.author,
      coverData: metadata.cover?.bytes,
      coverMimeType: metadata.cover?.mimeType,
    );
  } on VellumException catch (e) {
    throw BookImportException(e.message);
  }
}

Future<_ImportedMetadata> _readWebViewMetadata(
  String filePath,
  Uri readerServerBaseUri,
) async {
  final extractor = BookMetadataExtractor(serverBaseUri: readerServerBaseUri);
  final metadata = await extractor.extract(filePath);
  return (
    title: metadata.title,
    author: metadata.author,
    coverData: metadata.coverData,
    coverMimeType: metadata.coverMimeType,
  );
}
