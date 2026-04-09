import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

extension ReviewItemToDomain on ReviewItemsTableData {
  ReviewItem toDomainModel() => ReviewItem(
    itemId: itemId,
    itemType: ReviewableType.from(itemType),
    sourceId: sourceId,
    fsrs: FsrsCardData(
      state: FsrsState.from(fsrsState),
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      reps: reps,
      lapses: lapses,
      lastReviewAt: lastReviewAt != null
          ? DateTime.tryParse(lastReviewAt!)
          : null,
      nextReviewAt: nextReviewAt != null
          ? DateTime.tryParse(nextReviewAt!)
          : null,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
    ),
  );
}
