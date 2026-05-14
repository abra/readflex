import 'package:book_repository/book_repository.dart';
import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';

part 'source_details_event.dart';
part 'source_details_state.dart';

class SourceDetailsBloc extends Bloc<SourceDetailsEvent, SourceDetailsState> {
  SourceDetailsBloc({
    required BookRepository bookRepository,
    required HighlightRepository highlightRepository,
    required FlashcardRepository flashcardRepository,
    required DictionaryRepository dictionaryRepository,
    Book? initialSource,
  }) : _bookRepository = bookRepository,
       _highlightRepository = highlightRepository,
       _flashcardRepository = flashcardRepository,
       _dictionaryRepository = dictionaryRepository,
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
  final HighlightRepository _highlightRepository;
  final FlashcardRepository _flashcardRepository;
  final DictionaryRepository _dictionaryRepository;

  Future<void> _onLoadRequested(
    SourceDetailsLoadRequested event,
    Emitter<SourceDetailsState> emit,
  ) async {
    if (state.source?.id != event.sourceId) {
      emit(state.copyWith(status: SourceDetailsStatus.loading));
    }
    try {
      final source = await _bookRepository.getBookById(event.sourceId);
      if (source == null) {
        emit(const SourceDetailsState(status: SourceDetailsStatus.notFound));
        return;
      }
      final reviewSummary = sourceSupportsReview(source)
          ? await _loadReviewSummary(event.sourceId)
          : const SourceReviewSummary.empty();
      emit(
        SourceDetailsState(
          status: SourceDetailsStatus.success,
          source: source,
          reviewSummary: reviewSummary,
        ),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emit(const SourceDetailsState(status: SourceDetailsStatus.failure));
    }
  }

  Future<SourceReviewSummary> _loadReviewSummary(String sourceId) async {
    final counts = await Future.wait<int>([
      _highlightRepository.getHighlightCountBySource(sourceId),
      _flashcardRepository.getFlashcardCountByDeck(sourceId),
      _dictionaryRepository.getEntryCountBySource(sourceId),
    ]);
    return SourceReviewSummary(
      highlightCount: counts[0],
      flashcardCount: counts[1],
      dictionaryEntryCount: counts[2],
    );
  }
}
