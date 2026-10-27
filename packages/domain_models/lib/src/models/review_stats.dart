import 'package:equatable/equatable.dart';

import 'reviewable_type.dart';

/// Counts behind the Practice hub and the Home practice card.
class ReviewStats extends Equatable {
  const ReviewStats({
    this.dueByType = const {},
    this.totalByType = const {},
    this.masteredByType = const {},
    this.reviewedToday = 0,
    this.newReviewedToday = 0,
    this.reviewedLast7Days = 0,
    this.streakDays = 0,
    this.totalReviews = 0,
  });

  final Map<ReviewableType, int> dueByType;
  final Map<ReviewableType, int> totalByType;
  final Map<ReviewableType, int> masteredByType;

  /// Reviews recorded since local midnight.
  final int reviewedToday;

  /// Of those, first reviews of never-reviewed cards; the daily new-card
  /// limit counts against this.
  final int newReviewedToday;

  /// Reviews recorded in the last seven local days, today included.
  final int reviewedLast7Days;

  /// Consecutive local days with at least one review, ending today or
  /// yesterday.
  final int streakDays;

  /// Every review ever recorded.
  final int totalReviews;

  int get due => dueByType.values.fold(0, (sum, count) => sum + count);
  int get total => totalByType.values.fold(0, (sum, count) => sum + count);

  int dueOf(ReviewableType type) => dueByType[type] ?? 0;
  int totalOf(ReviewableType type) => totalByType[type] ?? 0;
  int masteredOf(ReviewableType type) => masteredByType[type] ?? 0;

  @override
  List<Object?> get props => [
    dueByType,
    totalByType,
    masteredByType,
    reviewedToday,
    newReviewedToday,
    reviewedLast7Days,
    streakDays,
    totalReviews,
  ];
}
