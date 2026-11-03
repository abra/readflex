import 'package:equatable/equatable.dart';

/// Current due count and the next future deadline from one queue snapshot.
class ReviewQueueStatus extends Equatable {
  const ReviewQueueStatus({required this.dueCount, this.nextReviewAt});

  /// Never-reviewed items and items whose scheduled time has arrived.
  final int dueCount;

  /// Earliest scheduled time strictly after the snapshot, or no future item.
  final DateTime? nextReviewAt;

  @override
  List<Object?> get props => [dueCount, nextReviewAt];
}
