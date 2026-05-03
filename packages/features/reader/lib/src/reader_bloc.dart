import 'dart:async';

import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'reader_event.dart';
part 'reader_state.dart';

/// Owns the loaded book and its highlights for the reader screen.
///
/// Responsibilities:
///   * resolve a [sourceId] into a [Book] on load and bump its
///     `lastOpenedAt` timestamp;
///   * persist position updates (CFI + progress fraction) coming from the
///     WebView back to the repository;
///   * refresh highlights when a TextAction (e.g. "Highlight") completes.
///
/// UI-only concerns (chrome visibility, selection, review-reminder banner)
/// live in separate cubits — see [ReaderChromeCubit], [ReaderSelectionCubit],
/// [ReaderReviewReminderCubit].
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc({
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
  }) : _bookRepository = bookRepository,
       _highlightRepository = highlightRepository,
       super(const ReaderState()) {
    on<ReaderSourceLoadRequested>(_onSourceLoadRequested);
    on<ReaderBookPositionUpdated>(_onBookPositionUpdated);
    on<ReaderHighlightsRefreshed>(_onHighlightsRefreshed);
  }

  final BookRepository _bookRepository;
  final HighlightRepository _highlightRepository;

  /// Pending Book to persist to the repository. The bottom chrome's
  /// drag-to-seek fires `ReaderBookPositionUpdated` ~10×/sec while
  /// foliate-js navigates under the finger; we debounce the actual
  /// `updateBook` write so SQLite isn't taking a hit on every onRelocated.
  /// State is still emitted on every event so the chrome stays in sync.
  Book? _pendingPersist;
  Timer? _persistTimer;
  static const _persistDebounce = Duration(milliseconds: 500);

  @override
  Future<void> close() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    // Flush whatever's pending so closing the reader (or hot
    // restart) doesn't drop the latest position. Awaited so the
    // write actually completes before the bloc's stream closes.
    final pending = _pendingPersist;
    _pendingPersist = null;
    if (pending != null) {
      try {
        await _bookRepository.updateBook(pending);
      } catch (e, st) {
        addError(e, st);
      }
    }
    return super.close();
  }

  Future<void> _onSourceLoadRequested(
    ReaderSourceLoadRequested event,
    Emitter<ReaderState> emit,
  ) async {
    emit(state.copyWith(status: ReaderStatus.loading));

    try {
      final (book, highlights) = await (
        _bookRepository.getBookById(event.sourceId),
        _highlightRepository.getHighlightsBySource(event.sourceId),
      ).wait;

      if (book != null) {
        await _bookRepository.updateBook(
          book.copyWith(lastOpenedAt: DateTime.now()),
        );
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            title: book.title,
            book: book,
            highlights: highlights,
          ),
        );
        return;
      }

      emit(state.copyWith(status: ReaderStatus.failure));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: ReaderStatus.failure));
    }
  }

  /// Persists a CFI + progress fraction emitted by the WebView for the
  /// currently-open book.
  ///
  /// foliate-js can occasionally report a fraction slightly above 1.0
  /// (overshoot at end-of-content / re-entry); we clamp to `[0, 1]` so
  /// the catalog cover's progress pill stays sensible.
  Future<void> _onBookPositionUpdated(
    ReaderBookPositionUpdated event,
    Emitter<ReaderState> emit,
  ) async {
    if (state.book == null) return;
    final progress = event.progress.clamp(0.0, 1.0);
    final updated = state.book!.copyWith(
      currentCfi: event.cfi,
      readingProgress: progress,
    );
    // Emit immediately so chrome stays in sync with the WebView.
    emit(
      state.copyWith(
        book: updated,
        chapterTitle: event.chapterTitle,
        bookCurrentPage: event.bookCurrentPage,
        bookTotalPages: event.bookTotalPages,
      ),
    );
    // Persist with a trailing debounce — successive emits within the
    // window only update [_pendingPersist], so a 5-second drag that
    // fires ~50 onRelocated events still results in one write at the
    // end. The latest pending value is always the one persisted.
    _pendingPersist = updated;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _flushPersist);
  }

  Future<void> _flushPersist() async {
    _persistTimer = null;
    final pending = _pendingPersist;
    if (pending == null) return;
    _pendingPersist = null;
    try {
      await _bookRepository.updateBook(pending);
    } catch (e, st) {
      addError(e, st);
    }
  }

  /// Routes an external error through BLoC's error pipeline (e.g. from a
  /// widget that detects a failure but cannot emit state itself).
  void reportError(Object error, StackTrace stackTrace) =>
      addError(error, stackTrace);

  Future<void> _onHighlightsRefreshed(
    ReaderHighlightsRefreshed event,
    Emitter<ReaderState> emit,
  ) async {
    final sourceId = state.sourceId;
    if (sourceId == null) return;
    try {
      final highlights = await _highlightRepository.getHighlightsBySource(
        sourceId,
      );
      emit(state.copyWith(highlights: highlights));
    } catch (e, st) {
      addError(e, st);
    }
  }
}
