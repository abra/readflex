import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:domain_models/domain_models.dart';

enum FlashcardStatus { idle, saving, success, failure }

final class FlashcardState extends Equatable {
  const FlashcardState({
    this.status = FlashcardStatus.idle,
    this.front = '',
    this.back = '',
    this.hint = '',
  });

  final FlashcardStatus status;
  final String front;
  final String back;
  final String hint;

  bool get canSave => front.isNotEmpty && back.isNotEmpty;

  FlashcardState copyWith({
    FlashcardStatus? status,
    String? front,
    String? back,
    String? hint,
  }) => FlashcardState(
    status: status ?? this.status,
    front: front ?? this.front,
    back: back ?? this.back,
    hint: hint ?? this.hint,
  );

  @override
  List<Object?> get props => [status, front, back, hint];
}

class FlashcardCubit extends Cubit<FlashcardState> {
  FlashcardCubit({required FlashcardRepository flashcardRepository})
    : _repository = flashcardRepository,
      super(const FlashcardState());

  final FlashcardRepository _repository;

  void setFront(String front) {
    emit(state.copyWith(front: front));
  }

  void setBack(String back) {
    emit(state.copyWith(back: back));
  }

  void setHint(String hint) {
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
    } catch (e) {
      emit(state.copyWith(status: FlashcardStatus.failure));
    }
  }
}
