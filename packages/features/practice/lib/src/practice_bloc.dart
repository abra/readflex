import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:highlight_repository/highlight_repository.dart';
import 'package:shared/shared.dart';

part 'practice_event.dart';
part 'practice_item.dart';
part 'practice_state.dart';

class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc({
    required FlashcardRepository flashcardRepository,
    required HighlightRepository highlightRepository,
  }) : _flashcardRepository = flashcardRepository,
       _highlightRepository = highlightRepository,
       super(const PracticeState()) {
    on<PracticeLoadRequested>(_onLoadRequested);
    on<PracticeCardRated>(_onCardRated);
    on<PracticeCardRevealed>(_onCardRevealed);
    on<PracticeItemNext>(_onItemNext);
  }

  final FlashcardRepository _flashcardRepository;
  final HighlightRepository _highlightRepository;

  Future<void> _onLoadRequested(
    PracticeLoadRequested event,
    Emitter<PracticeState> emit,
  ) async {
    emit(state.copyWith(status: PracticeStatus.loading));

    try {
      final dueCards = await _flashcardRepository.getDueFlashcards();
      final highlights = await _highlightRepository.getHighlights();

      final items = <PracticeItem>[
        ...dueCards.map(PracticeItem.flashcard),
        ...highlights.map(PracticeItem.highlight),
      ];

      if (items.isEmpty) {
        emit(state.copyWith(status: PracticeStatus.empty, items: []));
      } else {
        emit(
          state.copyWith(
            status: PracticeStatus.reviewing,
            items: items,
            currentIndex: 0,
            isRevealed: false,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }

  void _onCardRevealed(
    PracticeCardRevealed event,
    Emitter<PracticeState> emit,
  ) {
    emit(state.copyWith(isRevealed: true));
  }

  Future<void> _onCardRated(
    PracticeCardRated event,
    Emitter<PracticeState> emit,
  ) async {
    final item = state.currentItem;
    if (item is! FlashcardItem) return;

    try {
      await _flashcardRepository.recordReview(item.flashcard, event.rating);
      _advance(emit);
    } catch (e) {
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }

  void _onItemNext(
    PracticeItemNext event,
    Emitter<PracticeState> emit,
  ) {
    _advance(emit);
  }

  void _advance(Emitter<PracticeState> emit) {
    final nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.items.length) {
      emit(state.copyWith(status: PracticeStatus.completed));
    } else {
      emit(state.copyWith(currentIndex: nextIndex, isRevealed: false));
    }
  }
}
