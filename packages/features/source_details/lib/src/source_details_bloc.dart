import 'package:article_repository/article_repository.dart';
import 'package:book_repository/book_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'source_details_event.dart';
part 'source_details_state.dart';

class SourceDetailsBloc extends Bloc<SourceDetailsEvent, SourceDetailsState> {
  SourceDetailsBloc({
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
    ArticleRepository? articleRepository,
    LibrarySource? initialSource,
  }) : _bookRepository = bookRepository,
       _articleRepository = articleRepository,
       _highlightRepository = highlightRepository,
       super(
         initialSource == null
             ? const SourceDetailsState()
             : SourceDetailsState(
                 status: SourceDetailsStatus.success,
                 source: initialSource,
               ),
       ) {
    on<SourceDetailsLoadRequested>(_onLoadRequested);
  }

  final BookRepository _bookRepository;
  final ArticleRepository? _articleRepository;
  final HighlightRepository _highlightRepository;

  Future<void> _onLoadRequested(
    SourceDetailsLoadRequested event,
    Emitter<SourceDetailsState> emit,
  ) async {
    if (state.source?.id != event.sourceId) {
      emit(state.copyWith(status: SourceDetailsStatus.loading));
    }
    try {
      final book = await _bookRepository.getBookById(event.sourceId);
      if (book != null) {
        final source = LibrarySource.fromBook(book);
        final reviewSummary = source.supportsReview
            ? await _loadReviewSummary(event.sourceId)
            : const SourceReviewSummary.empty();
        emit(
          SourceDetailsState(
            status: SourceDetailsStatus.success,
            source: source,
            readerBook: book,
            reviewSummary: reviewSummary,
          ),
        );
        return;
      }

      final articleRepository = _articleRepository;
      if (articleRepository == null) {
        emit(const SourceDetailsState(status: SourceDetailsStatus.notFound));
        return;
      }
      final article = await articleRepository.getArticleById(event.sourceId);
      if (article == null) {
        emit(const SourceDetailsState(status: SourceDetailsStatus.notFound));
        return;
      }
      final source = LibrarySource.fromArticle(article);
      final reviewSummary = source.supportsReview
          ? await _loadReviewSummary(event.sourceId)
          : const SourceReviewSummary.empty();
      emit(
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: source,
          readerBook: articleRepository.toReaderBook(article),
          reviewSummary: reviewSummary,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const SourceDetailsState(status: SourceDetailsStatus.failure));
    }
  }

  Future<SourceReviewSummary> _loadReviewSummary(String sourceId) async {
    final highlightCount = await _highlightRepository.getHighlightCountBySource(
      sourceId,
    );
    return SourceReviewSummary(
      highlightCount: highlightCount,
    );
  }
}
