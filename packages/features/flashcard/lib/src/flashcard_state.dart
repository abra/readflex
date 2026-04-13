part of 'flashcard_cubit.dart';

enum FlashcardStatus { idle, saving, success, failure }

class FlashcardState extends Equatable {
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
