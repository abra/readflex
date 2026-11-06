part of 'review_session_bloc.dart';

enum ReviewSessionStatus { loading, reviewing, completed, empty, failure }

/// Identifies one presentation of a card, including after Retry or Review again.
class ReviewSessionCardIdentity extends Equatable {
  const ReviewSessionCardIdentity(this.itemId, this.revision);

  final String itemId;
  final int revision;

  @override
  List<Object?> get props => [itemId, revision];
}

class ReviewSessionState extends Equatable {
  const ReviewSessionState({
    this.status = ReviewSessionStatus.loading,
    this.items = const [],
    this.index = 0,
    this.revealed = false,
    this.intervals = const {},
    this.ratings = const {},
    this.again = const [],
    this.cardRevision = 0,
    this.isSaving = false,
  });

  final ReviewSessionStatus status;
  final List<PracticeItem> items;
  final int index;
  final int cardRevision;

  /// Keeps the displayed card mounted while its mutation commits.
  final bool isSaving;

  /// Whether the current word's answer is visible; highlights need no reveal.
  final bool revealed;

  /// How far each rating postpones the current card.
  final Map<Rating, Duration> intervals;

  /// Ratings given in this session, by item id.
  final Map<String, Rating> ratings;

  /// Items rated Again, in order, for a second pass.
  final List<PracticeItem> again;

  PracticeItem? get current => index < items.length ? items[index] : null;

  ReviewSessionCardIdentity? get cardIdentity {
    final item = current;
    return item == null
        ? null
        : ReviewSessionCardIdentity(item.itemId, cardRevision);
  }

  int get reviewed => ratings.length;

  /// Rated Good or better: words known, highlights kept.
  int get known =>
      ratings.values.where((r) => r == Rating.good || r == Rating.easy).length;

  ReviewSessionState copyWith({
    ReviewSessionStatus? status,
    List<PracticeItem>? items,
    int? index,
    bool? revealed,
    Map<Rating, Duration>? intervals,
    Map<String, Rating>? ratings,
    List<PracticeItem>? again,
    int? cardRevision,
    bool? isSaving,
  }) => ReviewSessionState(
    status: status ?? this.status,
    items: items ?? this.items,
    index: index ?? this.index,
    revealed: revealed ?? this.revealed,
    intervals: intervals ?? this.intervals,
    ratings: ratings ?? this.ratings,
    again: again ?? this.again,
    cardRevision: cardRevision ?? this.cardRevision,
    isSaving: isSaving ?? this.isSaving,
  );

  @override
  List<Object?> get props => [
    status,
    items,
    index,
    revealed,
    intervals,
    ratings,
    again,
    cardRevision,
    isSaving,
  ];
}
