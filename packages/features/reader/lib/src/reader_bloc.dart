import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:stream_transform/stream_transform.dart';

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
    on<ReaderPositionUpdated>(
      _onPositionUpdated,
      transformer: _debounce(_positionSaveDelay),
    );
    on<ReaderHighlightsRefreshed>(_onHighlightsRefreshed);
  }

  final BookRepository _bookRepository;
  final ArticleRepository _articleRepository;
  final HighlightRepository _highlightRepository;

  static const _positionSaveDelay = Duration(seconds: 2);

  static EventTransformer<E> _debounce<E>(Duration duration) {
    return (events, mapper) => events.debounce(duration).asyncExpand(mapper);
  }

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
        await _bookRepository.updateBook(
          state.book!.copyWith(
            currentCfi: event.cfi,
            readingProgress: event.progress,
          ),
        );
      } else if (state.article != null) {
        await _articleRepository.updateArticle(
          state.article!.copyWith(
            currentScrollOffset: event.scrollOffset,
          ),
        );
      }
    } catch (e, st) {
      addError(e, st);
    }
  }

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
