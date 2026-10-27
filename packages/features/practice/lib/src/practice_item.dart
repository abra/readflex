import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

/// A reviewable thing with its scheduling state and the title of its source:
/// a saved word or a text highlight.
sealed class PracticeItem extends Equatable {
  const PracticeItem({required this.fsrs, required this.sourceTitle});

  final FsrsCardData fsrs;

  /// Title of the book or article the item came from, or `null` when the
  /// source is gone.
  final String? sourceTitle;

  String get itemId;
  ReviewableType get itemType;
  String? get sourceId;
  String? get cfiRange;

  /// Never reviewed yet.
  bool get isNew => fsrs.state == FsrsState.newCard;

  /// Reached the review phase: known well enough to come back rarely.
  bool get isMastered => fsrs.state == FsrsState.review;
}

final class PracticeWordItem extends PracticeItem {
  const PracticeWordItem({
    required this.entry,
    required super.fsrs,
    super.sourceTitle,
    this.anchorCfiRange,
  });

  final DictionaryEntry entry;

  /// Where the word was selected, from the entry's anchor.
  final String? anchorCfiRange;

  @override
  String get itemId => entry.id;

  @override
  ReviewableType get itemType => ReviewableType.dictionary;

  @override
  String? get sourceId => entry.sourceId;

  @override
  String? get cfiRange => anchorCfiRange;

  @override
  List<Object?> get props => [entry, fsrs, sourceTitle, anchorCfiRange];
}

final class PracticeHighlightItem extends PracticeItem {
  const PracticeHighlightItem({
    required this.highlight,
    required super.fsrs,
    super.sourceTitle,
  });

  final Highlight highlight;

  @override
  String get itemId => highlight.id;

  @override
  ReviewableType get itemType => ReviewableType.highlight;

  @override
  String? get sourceId => highlight.sourceId;

  @override
  String? get cfiRange => highlight.cfiRange;

  @override
  List<Object?> get props => [highlight, fsrs, sourceTitle];
}
