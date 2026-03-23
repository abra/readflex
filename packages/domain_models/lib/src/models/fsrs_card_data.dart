import 'package:equatable/equatable.dart' show Equatable;

/// FSRS card state.
enum FsrsState {
  newCard,
  learning,
  review,
  relearning
  ;

  static FsrsState from(String value) => switch (value) {
    'new' => FsrsState.newCard,
    'learning' => FsrsState.learning,
    'review' => FsrsState.review,
    'relearning' => FsrsState.relearning,
    _ => FsrsState.newCard,
  };

  String toStorageString() => switch (this) {
    FsrsState.newCard => 'new',
    FsrsState.learning => 'learning',
    FsrsState.review => 'review',
    FsrsState.relearning => 'relearning',
  };
}

/// FSRS v6 scheduling data embedded in a flashcard.
final class FsrsCardData extends Equatable {
  const FsrsCardData({
    this.state = FsrsState.newCard,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.retrievability = 0.0,
    this.reps = 0,
    this.lapses = 0,
    this.lastReviewAt,
    this.nextReviewAt,
    this.scheduledDays = 0,
    this.elapsedDays = 0,
  });

  final FsrsState state;
  final double stability;
  final double difficulty;
  final double retrievability;
  final int reps;
  final int lapses;
  final DateTime? lastReviewAt;
  final DateTime? nextReviewAt;
  final int scheduledDays;
  final int elapsedDays;

  static const _absent = Object();

  FsrsCardData copyWith({
    FsrsState? state,
    double? stability,
    double? difficulty,
    double? retrievability,
    int? reps,
    int? lapses,
    Object? lastReviewAt = _absent,
    Object? nextReviewAt = _absent,
    int? scheduledDays,
    int? elapsedDays,
  }) => FsrsCardData(
    state: state ?? this.state,
    stability: stability ?? this.stability,
    difficulty: difficulty ?? this.difficulty,
    retrievability: retrievability ?? this.retrievability,
    reps: reps ?? this.reps,
    lapses: lapses ?? this.lapses,
    lastReviewAt: lastReviewAt == _absent
        ? this.lastReviewAt
        : lastReviewAt as DateTime?,
    nextReviewAt: nextReviewAt == _absent
        ? this.nextReviewAt
        : nextReviewAt as DateTime?,
    scheduledDays: scheduledDays ?? this.scheduledDays,
    elapsedDays: elapsedDays ?? this.elapsedDays,
  );

  @override
  List<Object?> get props => [
    state,
    stability,
    difficulty,
    retrievability,
    reps,
    lapses,
    lastReviewAt,
    nextReviewAt,
    scheduledDays,
    elapsedDays,
  ];
}
