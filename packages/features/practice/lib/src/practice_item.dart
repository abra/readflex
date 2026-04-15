part of 'practice_bloc.dart';

sealed class PracticeItem extends Equatable {
  const PracticeItem();

  const factory PracticeItem.flashcard(Flashcard card) = FlashcardItem;

  const factory PracticeItem.highlight(Highlight highlight) = HighlightItem;

  const factory PracticeItem.dictionary(DictionaryEntry entry) = DictionaryItem;

  String get itemId;

  ReviewableType get itemType;
}

final class FlashcardItem extends PracticeItem {
  const FlashcardItem(this.flashcard);

  final Flashcard flashcard;

  @override
  String get itemId => flashcard.id;

  @override
  ReviewableType get itemType => ReviewableType.flashcard;

  @override
  List<Object?> get props => [flashcard];
}

final class HighlightItem extends PracticeItem {
  const HighlightItem(this.highlight);

  final Highlight highlight;

  @override
  String get itemId => highlight.id;

  @override
  ReviewableType get itemType => ReviewableType.highlight;

  @override
  List<Object?> get props => [highlight];
}

final class DictionaryItem extends PracticeItem {
  const DictionaryItem(this.entry);

  final DictionaryEntry entry;

  @override
  String get itemId => entry.id;

  @override
  ReviewableType get itemType => ReviewableType.dictionary;

  @override
  List<Object?> get props => [entry];
}
