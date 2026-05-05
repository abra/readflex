import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:reader_webview/reader_webview.dart';

part 'import_flow_state.dart';

/// Pick book file from disk. Returns `null` if the user cancelled, or
/// a [File] handle to the selected book otherwise. The cubit owns the
/// transition into [ImportFlowBookUploading] when this resolves to a
/// non-null file.
typedef PickBookFile = Future<File?> Function();

/// Persist a picked book file. Implementations should parse metadata
/// (title/author/cover) and copy the file to the books directory.
///
/// The optional [onProgress] callback is fired through to
/// [BookRepository.addBook] so the UI can show a real progress bar
/// during the byte-copy phase. The first non-null progress value also
/// signals to the cubit that the parsing phase is over and the bar can
/// switch from indeterminate to determinate.
typedef ImportBookFile =
    Future<Book?> Function(
      File sourceFile, {
      void Function(double progress)? onProgress,
    });

/// Drives the multi-step Add-to-Library bottom sheet. State is a sealed
/// hierarchy ([ImportFlowState]) — each step has the exact data it
/// needs (filename, progress) so the UI can switch on the concrete
/// type without nullable-everywhere ceremony.
class ImportFlowCubit extends Cubit<ImportFlowState> {
  ImportFlowCubit({
    required PickBookFile onPickBookFile,
    required ImportBookFile onImportBook,
  }) : _onPickBookFile = onPickBookFile,
       _onImportBook = onImportBook,
       super(const ImportFlowMenu());

  final PickBookFile _onPickBookFile;
  final ImportBookFile _onImportBook;

  /// Re-entry guard for [pickAndImportBook]. Without it a double-tap
  /// on the menu's "Upload Book" tile (or the failure screen's "Try
  /// again" button) opens two platform pickers concurrently. The
  /// second resolves into a second `ImportFlowBookUploading` while the
  /// first is still running, racing on cubit state.
  ///
  /// Kept as a private flag instead of a new `ImportFlowPicking` state
  /// because the picker is a platform-rendered UI we don't draw — the
  /// sealed state hierarchy describes screens we paint. Process-control
  /// belongs in the cubit's private fields.
  bool _isPickingFile = false;

  /// Open the platform file picker, then drive book import through
  /// uploading → done. No-op when the picker is dismissed or a pick
  /// is already in flight.
  Future<void> pickAndImportBook() async {
    if (_isPickingFile) return;
    _isPickingFile = true;
    final File? file;
    try {
      file = await _onPickBookFile();
    } finally {
      _isPickingFile = false;
    }
    if (file == null || isClosed) return;

    final filename = p.basename(file.path);
    // Indeterminate phase: metadata parse is in flight, no bytes yet.
    emit(ImportFlowBookUploading(filename: filename));

    final Book? book;
    try {
      book = await _onImportBook(
        file,
        onProgress: (progress) {
          // Switching from indeterminate to determinate happens on the
          // first onProgress call from the repository. Guarded by
          // isClosed because the user can dismiss the sheet (which
          // closes the cubit) mid-copy — the repository's chunked
          // writer keeps firing onProgress until it hits the next
          // await point.
          if (isClosed) return;
          if (state case ImportFlowBookUploading(:final filename)) {
            emit(
              ImportFlowBookUploading(
                filename: filename,
                progress: progress.clamp(0.0, 1.0),
              ),
            );
          }
        },
      );
    } on BookImportException catch (e) {
      if (isClosed) return;
      // Surface the JS-side reason ("File type not supported", etc.)
      // rather than the generic fallback below — the whole reason
      // BookImportException exists is to carry that detail to the UI.
      emit(ImportFlowFailure(message: e.message, filename: filename));
      return;
    } catch (_) {
      if (isClosed) return;
      emit(
        ImportFlowFailure(
          message: 'Failed to import the book',
          filename: filename,
        ),
      );
      return;
    }

    if (isClosed) return;
    if (book == null) {
      emit(
        ImportFlowFailure(
          message: 'Failed to import the book',
          filename: filename,
        ),
      );
      return;
    }
    emit(ImportFlowBookDone(filename: filename, format: book.format));
  }

  /// Reset to the menu — used by the failure-screen "Try again" button.
  void backToMenu() {
    emit(const ImportFlowMenu());
  }
}
