import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

part 'flashcard_state.dart';

class FlashcardCubit extends Cubit<FlashcardState> {
  FlashcardCubit({required FlashcardRepository flashcardRepository})
    : _repository = flashcardRepository,
      super(const FlashcardState());

  final FlashcardRepository _repository;

  void setFront(String front) {
    if (state.front == front) return;
    emit(state.copyWith(front: front));
  }

  void setBack(String back) {
    if (state.back == back) return;
    emit(state.copyWith(back: back));
  }

  void setHint(String hint) {
    if (state.hint == hint) return;
    emit(state.copyWith(hint: hint));
  }

  Future<void> save({
    required String sourceId,
    required SourceType sourceType,
    String? sourceHighlightId,
  }) async {
    if (!state.canSave) return;

    emit(state.copyWith(status: FlashcardStatus.saving));

    try {
      await _repository.addFlashcard(
        deckId: sourceId,
        front: state.front,
        back: state.back,
        hint: state.hint.isEmpty ? null : state.hint,
        sourceHighlightId: sourceHighlightId,
      );
      emit(state.copyWith(status: FlashcardStatus.success));
    } catch (e, st) {
      addError(e, st);
      emit(state.copyWith(status: FlashcardStatus.failure));
    }
  }
}
