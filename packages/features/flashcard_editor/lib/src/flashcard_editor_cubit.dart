import 'package:equatable/equatable.dart';
import 'package:flashcard_repository/flashcard_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared/shared.dart';

enum FlashcardEditorStatus { idle, saving, success, failure }

final class FlashcardEditorState extends Equatable {
  const FlashcardEditorState({
    this.status = FlashcardEditorStatus.idle,
    this.front = '',
    this.back = '',
    this.hint = '',
  });

  final FlashcardEditorStatus status;
  final String front;
  final String back;
  final String hint;

  bool get canSave => front.isNotEmpty && back.isNotEmpty;

  FlashcardEditorState copyWith({
    FlashcardEditorStatus? status,
    String? front,
    String? back,
    String? hint,
  }) => FlashcardEditorState(
    status: status ?? this.status,
    front: front ?? this.front,
    back: back ?? this.back,
    hint: hint ?? this.hint,
  );

  @override
  List<Object?> get props => [status, front, back, hint];
}

class FlashcardEditorCubit extends Cubit<FlashcardEditorState> {
  FlashcardEditorCubit({required FlashcardRepository flashcardRepository})
    : _repository = flashcardRepository,
      super(const FlashcardEditorState());

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

    emit(state.copyWith(status: FlashcardEditorStatus.saving));

    try {
      await _repository.addFlashcard(
        deckId: sourceId,
        front: state.front,
        back: state.back,
        hint: state.hint.isEmpty ? null : state.hint,
        sourceHighlightId: sourceHighlightId,
      );
      emit(state.copyWith(status: FlashcardEditorStatus.success));
    } catch (e) {
      emit(state.copyWith(status: FlashcardEditorStatus.failure));
    }
  }
}
