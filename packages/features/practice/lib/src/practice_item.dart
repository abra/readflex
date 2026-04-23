import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

/// One thing the user is asked to review in a practice session.
///
/// Sealed hierarchy with three concrete variants — [FlashcardItem],
/// [HighlightItem], [DictionaryItem] — one per [ReviewableType]. The bloc
/// keeps them in FSRS "due" order; the UI picks a card view based on the
/// runtime type.
sealed class PracticeItem extends Equatable {
  const PracticeItem();

  const factory PracticeItem.flashcard(Flashcard card) = FlashcardItem;
  const factory PracticeItem.highlight(Highlight highlight) = HighlightItem;
  const factory PracticeItem.dictionary(DictionaryEntry entry) = DictionaryItem;

  /// Domain id of the underlying entity. Used to round-trip the item
  /// through `fsrs_repository` on rate.
  String get itemId;

  /// FSRS type the underlying entity belongs to. Keeps the bloc from
  /// pattern-matching on the sealed type every time it wants to record a
  /// review.
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
