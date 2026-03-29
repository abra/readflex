import 'package:equatable/equatable.dart' show Equatable;

import 'fsrs_card_data.dart';
import 'rating.dart';
import 'reviewable_type.dart';

/// A record of a single FSRS review for any reviewable item.
final class ReviewLog extends Equatable {
  const ReviewLog({
    required this.id,
    required this.itemId,
    required this.itemType,
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
  final String itemId;
  final ReviewableType itemType;
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
    itemId,
    itemType,
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
