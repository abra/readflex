part of 'practice_bloc.dart';

sealed class PracticeItem extends Equatable {
  const PracticeItem();

  factory PracticeItem.flashcard(Flashcard card) = FlashcardItem;

  factory PracticeItem.highlight(Highlight highlight) = HighlightItem;
}

final class FlashcardItem extends PracticeItem {
  const FlashcardItem(this.flashcard);

  final Flashcard flashcard;

  @override
  List<Object?> get props => [flashcard];
}

final class HighlightItem extends PracticeItem {
  const HighlightItem(this.highlight);

  final Highlight highlight;

  @override
  List<Object?> get props => [highlight];
}
