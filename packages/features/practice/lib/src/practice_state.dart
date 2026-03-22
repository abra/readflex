part of 'practice_bloc.dart';

enum PracticeStatus { initial, loading, reviewing, empty, completed, failure }

final class PracticeState extends Equatable {
  const PracticeState({
    this.status = PracticeStatus.initial,
    this.dueCards = const [],
    this.currentIndex = 0,
    this.isRevealed = false,
  });

  final PracticeStatus status;
  final List<Flashcard> dueCards;
  final int currentIndex;
  final bool isRevealed;

  Flashcard? get currentCard =>
      currentIndex < dueCards.length ? dueCards[currentIndex] : null;

  int get remaining => dueCards.length - currentIndex;
  int get reviewed => currentIndex;

  PracticeState copyWith({
    PracticeStatus? status,
    List<Flashcard>? dueCards,
    int? currentIndex,
    bool? isRevealed,
  }) => PracticeState(
    status: status ?? this.status,
    dueCards: dueCards ?? this.dueCards,
    currentIndex: currentIndex ?? this.currentIndex,
    isRevealed: isRevealed ?? this.isRevealed,
  );

  @override
  List<Object?> get props => [status, dueCards, currentIndex, isRevealed];
}
