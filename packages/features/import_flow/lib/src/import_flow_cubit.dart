import 'dart:async' show unawaited;
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:reader_webview/reader_webview.dart';

import 'article_url_utils.dart';

part 'import_flow_state.dart';

/// Pick book file from disk. Returns `null` if the user cancelled, or
/// a [File] handle to the selected book otherwise. The cubit owns the
/// transition into [ImportFlowBookUploading] when this resolves to a
/// non-null file.
typedef PickBookFile = Future<File?> Function();

typedef IsBookImportTermsAccepted = bool Function();
typedef AcceptBookImportTerms = Future<void> Function();

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

/// Current phase of saving a web article.
enum ImportFlowArticleStage {
  fetching,
  saving,
}

/// Extracts, cleans, and persists a web article by URL.
typedef ImportArticleUrl =
    Future<Article?> Function(
      String url, {
      void Function(ImportFlowArticleStage stage)? onStage,
    });

/// User-facing failure raised by the app layer when article extraction has
/// a meaningful backend reason (unsupported URL, extraction failed, etc.).
class ArticleImportException implements Exception {
  const ArticleImportException(this.message);

  final String message;

  @override
  String toString() => 'ArticleImportException: $message';
}

/// Drives the multi-step Add-to-Library bottom sheet. State is a sealed
/// hierarchy ([ImportFlowState]) — each step has the exact data it
/// needs (filename, progress) so the UI can switch on the concrete
/// type without nullable-everywhere ceremony.
class ImportFlowCubit extends Cubit<ImportFlowState> {
  ImportFlowCubit({
    required PickBookFile onPickBookFile,
    required ImportBookFile onImportBook,
    required ImportArticleUrl onImportArticle,
    IsBookImportTermsAccepted? isBookImportTermsAccepted,
    AcceptBookImportTerms? acceptBookImportTerms,
  }) : _onPickBookFile = onPickBookFile,
       _onImportBook = onImportBook,
       _onImportArticle = onImportArticle,
       _isBookImportTermsAccepted = isBookImportTermsAccepted ?? (() => true),
       _acceptBookImportTerms = acceptBookImportTerms ?? (() async {}),
       super(const ImportFlowMenu());

  final PickBookFile _onPickBookFile;
  final ImportBookFile _onImportBook;
  final ImportArticleUrl _onImportArticle;
  final IsBookImportTermsAccepted _isBookImportTermsAccepted;
  final AcceptBookImportTerms _acceptBookImportTerms;

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
  bool _isImportingArticle = false;

  void showArticleUrlEntry() {
    emit(const ImportFlowArticleUrlEntry());
  }

  void articleUrlChanged(String rawUrl) {
    final current = state;
    if (current is! ImportFlowArticleUrlEntry) return;
    emit(current.withUrl(rawUrl));
  }

  Future<void> submitArticleUrl() async {
    final current = state;
    if (current is! ImportFlowArticleUrlEntry || _isImportingArticle) return;

    final rawUrl = current.url;
    if (rawUrl.trim().isEmpty) {
      emit(current.withError('Enter an article URL'));
      return;
    }

    final url = current.normalizedUrl;
    if (url == null) {
      emit(current.withError('Enter a valid article URL'));
      return;
    }

    await importArticle(url);
  }

  void requestBookImport() {
    if (_isBookImportTermsAccepted()) {
      unawaited(pickAndImportBook());
      return;
    }
    emit(const ImportFlowBookTermsRequired());
  }

  void cancelBookImportTerms() {
    emit(const ImportFlowMenu());
  }

  Future<void> acceptTermsAndPickBook() async {
    await _acceptBookImportTerms();
    if (isClosed) return;
    emit(const ImportFlowMenu());
    await pickAndImportBook();
  }

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

    // Coalesce onProgress emits below a 1% delta. Chunked file writers
    // can fire onProgress hundreds of times per second on large books
    // (each fragment of the byte-copy emits), and re-rendering the
    // indeterminate→determinate uploading view that often is wasteful
    // and visually no-op — the bar can't move sub-1% per pixel anyway.
    // The closure-local `lastEmitted` resets implicitly when this
    // import finishes, so the next import starts fresh.
    const progressEpsilon = 0.01;
    double? lastEmittedProgress;

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
          final clamped = progress.clamp(0.0, 1.0);
          // Always let through the very first emit (transitions
          // indeterminate→determinate) and the final 1.0 (so the bar
          // hits its end before success). In between, coalesce.
          final last = lastEmittedProgress;
          if (last != null &&
              clamped < 1.0 &&
              (clamped - last).abs() < progressEpsilon) {
            return;
          }
          lastEmittedProgress = clamped;
          if (state case ImportFlowBookUploading(:final filename)) {
            emit(
              ImportFlowBookUploading(
                filename: filename,
                progress: clamped,
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
    } catch (e, st) {
      if (isClosed) return;
      addError(e, st);
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

  Future<void> importArticle(String rawUrl) async {
    if (_isImportingArticle) return;
    final url = normalizeArticleUrl(rawUrl);
    if (url == null) {
      emit(
        const ImportFlowFailure(
          message: 'Enter a valid article URL',
          retryTarget: ImportFlowRetryTarget.article,
        ),
      );
      return;
    }

    _isImportingArticle = true;
    emit(ImportFlowArticleUploading(url: url));
    try {
      final article = await _onImportArticle(
        url,
        onStage: (stage) {
          if (isClosed) return;
          if (state case ImportFlowArticleUploading(:final url)) {
            emit(ImportFlowArticleUploading(url: url, stage: stage));
          }
        },
      );
      if (isClosed) return;
      if (article == null) {
        emit(
          ImportFlowFailure(
            message: 'Failed to save the article',
            filename: url,
            retryTarget: ImportFlowRetryTarget.article,
          ),
        );
        return;
      }
      emit(ImportFlowArticleDone(title: article.title));
    } on ArticleImportException catch (e) {
      if (!isClosed) {
        emit(
          ImportFlowFailure(
            message: e.message,
            filename: url,
            retryTarget: ImportFlowRetryTarget.article,
          ),
        );
      }
    } catch (e, st) {
      if (!isClosed) {
        addError(e, st);
        emit(
          ImportFlowFailure(
            message: 'Failed to save the article',
            filename: url,
            retryTarget: ImportFlowRetryTarget.article,
          ),
        );
      }
    } finally {
      _isImportingArticle = false;
    }
  }

  /// Reset to the menu — used by the failure-screen "Try again" button.
  void backToMenu() {
    emit(const ImportFlowMenu());
  }

  void retryAfterFailure() {
    final current = state;
    if (current is ImportFlowFailure &&
        current.retryTarget == ImportFlowRetryTarget.article) {
      emit(const ImportFlowArticleUrlEntry());
      return;
    }
    pickAndImportBook();
  }
}
