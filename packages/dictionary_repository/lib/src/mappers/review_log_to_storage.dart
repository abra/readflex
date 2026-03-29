import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension DictionaryReviewLogToStorage on ReviewLog {
  ReviewLogsTableCompanion toStorageModel() => ReviewLogsTableCompanion(
    id: Value(id),
    itemId: Value(itemId),
    itemType: Value(itemType.toStorageString()),
    rating: Value(rating.name),
    stateBefore: Value(stateBefore.toStorageString()),
    stabilityBefore: Value(stabilityBefore),
    difficultyBefore: Value(difficultyBefore),
    retrievabilityAtReview: Value(retrievabilityAtReview),
    scheduledDays: Value(scheduledDays),
    elapsedDays: Value(elapsedDays),
    reviewDurationMs: Value(reviewDurationMs),
    reviewedAt: Value(reviewedAt.toIso8601String()),
  );
}
