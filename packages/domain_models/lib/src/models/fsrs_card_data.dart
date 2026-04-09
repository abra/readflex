import 'package:equatable/equatable.dart' show Equatable;

/// FSRS card state.
enum FsrsState {
  newCard('new'),
  learning('learning'),
  review('review'),
  relearning('relearning')
  ;

  const FsrsState(this.storageKey);

  /// The string used to persist this state in the database. Differs from
  /// [name] only for [newCard] (stored as `'new'`, not `'newCard'`).
  final String storageKey;

  static FsrsState from(String value) => values.firstWhere(
    (e) => e.storageKey == value,
    orElse: () => throw FormatException('Unknown FsrsState: $value'),
  );

  String toStorageString() => storageKey;
}

/// FSRS v6 scheduling data embedded in a flashcard.
class FsrsCardData extends Equatable {
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
