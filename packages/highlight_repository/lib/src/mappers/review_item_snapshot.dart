import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension ReviewItemSnapshot on ReviewItemsTableData {
  ReviewItem toReviewItem() => ReviewItem(
    itemId: itemId,
    itemType: ReviewableType.from(itemType),
    sourceId: sourceId,
    isExcluded: isExcluded,
    fsrs: FsrsCardData(
      state: FsrsState.from(fsrsState),
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      reps: reps,
      lapses: lapses,
      lastReviewAt: lastReviewAt == null
          ? null
          : DateTime.tryParse(lastReviewAt!),
      nextReviewAt: nextReviewAt == null
          ? null
          : DateTime.tryParse(nextReviewAt!),
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
    ),
  );
}

extension ReviewItemRestore on ReviewItem {
  ReviewItemsTableCompanion toReviewRow() => ReviewItemsTableCompanion(
    itemId: Value(itemId),
    itemType: Value(itemType.toStorageString()),
    sourceId: Value(sourceId),
    isExcluded: Value(isExcluded),
    fsrsState: Value(fsrs.state.toStorageString()),
    stability: Value(fsrs.stability),
    difficulty: Value(fsrs.difficulty),
    retrievability: Value(fsrs.retrievability),
    reps: Value(fsrs.reps),
    lapses: Value(fsrs.lapses),
    lastReviewAt: Value(fsrs.lastReviewAt?.toIso8601String()),
    nextReviewAt: Value(fsrs.nextReviewAt?.toIso8601String()),
    scheduledDays: Value(fsrs.scheduledDays),
    elapsedDays: Value(fsrs.elapsedDays),
  );
}
