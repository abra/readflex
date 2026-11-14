import 'package:equatable/equatable.dart' show Equatable;

import 'fsrs_card_data.dart';
import 'reviewable_type.dart';

/// A reviewable item's FSRS state, stored in the centralized review system.
class ReviewItem extends Equatable {
  const ReviewItem({
    required this.itemId,
    required this.itemType,
    required this.fsrs,
    this.sourceId,
    this.isExcluded = false,
  });

  final String itemId;
  final ReviewableType itemType;
  final String? sourceId;
  final FsrsCardData fsrs;

  /// Explicit user exclusion, retained with the schedule and deletion snapshots.
  final bool isExcluded;

  ReviewItem copyWith({FsrsCardData? fsrs}) => ReviewItem(
    itemId: itemId,
    itemType: itemType,
    sourceId: sourceId,
    fsrs: fsrs ?? this.fsrs,
    isExcluded: isExcluded,
  );

  @override
  List<Object?> get props => [itemId, itemType, sourceId, fsrs, isExcluded];
}
