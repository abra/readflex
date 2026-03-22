import 'package:equatable/equatable.dart' show Equatable;

import 'fsrs_card_data.dart';
import 'rating.dart';

/// A record of a single flashcard review.
final class ReviewLog extends Equatable {
  const ReviewLog({
    required this.id,
    required this.flashcardId,
    required this.rating,
    required this.stateBefore,
    required this.stabilityBefore,
    required this.difficultyBefore,
    required this.retrievabilityAtReview,
    required this.scheduledDays,
    required this.elapsedDays,
    required this.reviewedAt,
    this.reviewDurationMs,
  });

  final String id;
  final String flashcardId;
  final Rating rating;
  final FsrsState stateBefore;
  final double stabilityBefore;
  final double difficultyBefore;
  final double retrievabilityAtReview;
  final int scheduledDays;
  final int elapsedDays;
  final int? reviewDurationMs;
  final DateTime reviewedAt;

  @override
  List<Object?> get props => [
    id,
    flashcardId,
    rating,
    stateBefore,
    stabilityBefore,
    difficultyBefore,
    retrievabilityAtReview,
    scheduledDays,
    elapsedDays,
    reviewDurationMs,
    reviewedAt,
  ];
}
