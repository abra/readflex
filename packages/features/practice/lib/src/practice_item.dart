part of 'practice_bloc.dart';

sealed class PracticeItem extends Equatable {
  const PracticeItem();

  factory PracticeItem.flashcard(Flashcard card) = FlashcardItem;

  factory PracticeItem.highlight(Highlight highlight) = HighlightItem;

  factory PracticeItem.dictionary(DictionaryEntry entry) = DictionaryItem;
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

final class DictionaryItem extends PracticeItem {
  const DictionaryItem(this.entry);

  final DictionaryEntry entry;

  @override
  List<Object?> get props => [entry];
}
