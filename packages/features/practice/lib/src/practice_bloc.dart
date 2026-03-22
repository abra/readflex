import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

part 'practice_event.dart';
part 'practice_state.dart';

class PracticeBloc extends Bloc<PracticeEvent, PracticeState> {
  PracticeBloc({required FlashcardRepository flashcardRepository})
    : _repository = flashcardRepository,
      super(const PracticeState()) {
    on<PracticeLoadRequested>(_onLoadRequested);
    on<PracticeCardRated>(_onCardRated);
    on<PracticeCardRevealed>(_onCardRevealed);
  }

  final FlashcardRepository _repository;

  Future<void> _onLoadRequested(
    PracticeLoadRequested event,
    Emitter<PracticeState> emit,
  ) async {
    emit(state.copyWith(status: PracticeStatus.loading));

    try {
      final dueCards = await _repository.getDueFlashcards();
      if (dueCards.isEmpty) {
        emit(
          state.copyWith(
            status: PracticeStatus.empty,
            dueCards: [],
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: PracticeStatus.reviewing,
            dueCards: dueCards,
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
    final card = state.currentCard;
    if (card == null) return;

    try {
      await _repository.recordReview(card, event.rating);

      final nextIndex = state.currentIndex + 1;
      if (nextIndex >= state.dueCards.length) {
        emit(state.copyWith(status: PracticeStatus.completed));
      } else {
        emit(
          state.copyWith(
            currentIndex: nextIndex,
            isRevealed: false,
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(status: PracticeStatus.failure));
    }
  }
}
