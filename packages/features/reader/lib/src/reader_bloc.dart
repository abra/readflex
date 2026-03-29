import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'reader_event.dart';
part 'reader_state.dart';

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
    on<ReaderPositionUpdated>(_onPositionUpdated);
    on<ReaderTextSelected>(_onTextSelected);
    on<ReaderTextDeselected>(_onTextDeselected);
    on<ReaderReviewReminderShown>(_onReviewReminderShown);
    on<ReaderReviewReminderDismissed>(_onReviewReminderDismissed);
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
      // Try book first, then article
      final book = await _bookRepository.getBookById(event.sourceId);
      if (book != null) {
        final highlights = await _highlightRepository.getHighlightsBySource(
          event.sourceId,
        );

        // Update lastOpenedAt
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

      final article = await _articleRepository.getArticleById(event.sourceId);
      if (article != null) {
        final highlights = await _highlightRepository.getHighlightsBySource(
          event.sourceId,
        );

        // Update lastOpenedAt
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
    } catch (e) {
      emit(state.copyWith(status: ReaderStatus.failure));
    }
  }

  Future<void> _onPositionUpdated(
    ReaderPositionUpdated event,
    Emitter<ReaderState> emit,
  ) async {
    try {
      if (state.book != null) {
        final updated = state.book!.copyWith(
          currentLocation: event.location,
          readingProgress: event.progress,
        );
        await _bookRepository.updateBook(updated);
        emit(state.copyWith(book: updated));
      } else if (state.article != null) {
        final updated = state.article!.copyWith(
          currentScrollOffset: event.scrollOffset,
        );
        await _articleRepository.updateArticle(updated);
        emit(state.copyWith(article: updated));
      }
    } catch (_) {
      // Non-fatal: position save failed, don't disrupt reading
    }
  }

  void _onTextSelected(
    ReaderTextSelected event,
    Emitter<ReaderState> emit,
  ) {
    emit(
      state.copyWith(
        selectedText: event.selectedText,
        selectionCfiRange: event.cfiRange,
        selectionPageNumber: event.pageNumber,
        selectionScrollOffset: event.scrollOffset,
        hasSelection: true,
      ),
    );
  }

  void _onTextDeselected(
    ReaderTextDeselected event,
    Emitter<ReaderState> emit,
  ) {
    emit(state.copyWith(hasSelection: false));
  }

  void _onReviewReminderShown(
    ReaderReviewReminderShown event,
    Emitter<ReaderState> emit,
  ) {
    emit(state.copyWith(showReviewReminder: true));
  }

  void _onReviewReminderDismissed(
    ReaderReviewReminderDismissed event,
    Emitter<ReaderState> emit,
  ) {
    emit(state.copyWith(showReviewReminder: false));
  }
}
