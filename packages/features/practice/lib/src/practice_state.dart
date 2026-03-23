part of 'practice_bloc.dart';

enum PracticeStatus { initial, loading, reviewing, empty, completed, failure }

final class PracticeState extends Equatable {
  const PracticeState({
    this.status = PracticeStatus.initial,
    this.items = const [],
    this.currentIndex = 0,
    this.isRevealed = false,
  });

  final PracticeStatus status;
  final List<PracticeItem> items;
  final int currentIndex;
  final bool isRevealed;

  PracticeItem? get currentItem =>
      currentIndex < items.length ? items[currentIndex] : null;

  Flashcard? get currentCard => switch (currentItem) {
    FlashcardItem(:final flashcard) => flashcard,
    _ => null,
  };

  int get remaining => items.length - currentIndex;

  int get reviewed => currentIndex;

  PracticeState copyWith({
    PracticeStatus? status,
    List<PracticeItem>? items,
    int? currentIndex,
    bool? isRevealed,
  }) => PracticeState(
    status: status ?? this.status,
    items: items ?? this.items,
    currentIndex: currentIndex ?? this.currentIndex,
    isRevealed: isRevealed ?? this.isRevealed,
  );

  @override
  List<Object?> get props => [status, items, currentIndex, isRevealed];
}
