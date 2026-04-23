part of 'flashcard_cubit.dart';

/// Lifecycle of the flashcard sheet's save action.
enum FlashcardStatus { idle, saving, success, failure }

/// Draft state of the flashcard sheet: front/back/hint fields plus the
/// save status that drives the button's enabled state and error text.
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
