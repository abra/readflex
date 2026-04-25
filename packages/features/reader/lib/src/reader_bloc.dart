import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'reader_event.dart';
part 'reader_state.dart';

/// Owns the loaded source (book or article) and its highlights for the
/// reader screen.
///
/// Responsibilities:
///   * resolve a [sourceId] into either a [Book] or [Article] on load and
///     bump its `lastOpenedAt` timestamp;
///   * debounce position updates (2s) coming from the WebView and persist
///     them back to the repository;
///   * refresh highlights when a TextAction (e.g. "Highlight") completes.
///
/// UI-only concerns (chrome visibility, selection, review-reminder banner)
/// live in separate cubits — see [ReaderChromeCubit], [ReaderSelectionCubit],
/// [ReaderReviewReminderCubit].
class ReaderBloc extends Bloc<ReaderEvent, ReaderState> {
  ReaderBloc({
    required BookRepository bookRepository,
    required ArticleRepository articleRepository,
    required HighlightRepository highlightRepository,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _highlightRepository = highlightRepository,
       super(const ReaderState()) {
    on<ReaderSourceLoadRequested>(_onSourceLoadRequested);
    // No debounce here on purpose: the bottom chrome reads progress out of
    // [ReaderState], so it has to update on every page turn. Each handler
    // run does one indexed `updateBook` / `updateArticle` write; SQLite
    // handles that volume comfortably for typical reading speeds.
    on<ReaderBookPositionUpdated>(_onBookPositionUpdated);
    on<ReaderHighlightsRefreshed>(_onHighlightsRefreshed);
  }

  final BookRepository _bookRepository;
  final ArticleRepository _articleRepository;
  final HighlightRepository _highlightRepository;

  Future<void> _onSourceLoadRequested(
    ReaderSourceLoadRequested event,
    Emitter<ReaderState> emit,
  ) async {
    emit(state.copyWith(status: ReaderStatus.loading));

    try {
      // Load book, article, and highlights in parallel. Only one of book/article
      // will resolve to a non-null row for a given sourceId.
      final (book, article, highlights) = await (
        _bookRepository.getBookById(event.sourceId),
        _articleRepository.getArticleById(event.sourceId),
        _highlightRepository.getHighlightsBySource(event.sourceId),
      ).wait;

      if (book != null) {
        await _bookRepository.updateBook(
          book.copyWith(lastOpenedAt: DateTime.now()),
        );
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            sourceType: SourceType.book,
            title: book.title,
            book: book,
            highlights: highlights,
          ),
        );
        return;
      }

      if (article != null) {
        await _articleRepository.updateArticle(
          article.copyWith(lastOpenedAt: DateTime.now()),
        );
        emit(
          state.copyWith(
            status: ReaderStatus.ready,
            sourceType: SourceType.article,
            title: article.title,
            article: article,
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
  /// currently-open source. Books and articles share the same event:
  /// articles render through foliate-js too, so the position model is
  /// identical (CFI for restore, fraction for the library cover's
  /// progress pill).
  ///
  /// foliate-js can occasionally report a fraction slightly above 1.0
  /// (overshoot at end-of-content / re-entry); we clamp to `[0, 1]` so
  /// the catalog cover's progress pill stays sensible.
  Future<void> _onBookPositionUpdated(
    ReaderBookPositionUpdated event,
    Emitter<ReaderState> emit,
  ) async {
    final progress = event.progress.clamp(0.0, 1.0);
    try {
      if (state.book != null) {
        final updated = state.book!.copyWith(
          currentCfi: event.cfi,
          readingProgress: progress,
        );
        await _bookRepository.updateBook(updated);
        emit(state.copyWith(book: updated));
      } else if (state.article != null) {
        final updated = state.article!.copyWith(
          currentCfi: event.cfi,
          currentScrollOffset: progress,
        );
        await _articleRepository.updateArticle(updated);
        emit(state.copyWith(article: updated));
      }
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
