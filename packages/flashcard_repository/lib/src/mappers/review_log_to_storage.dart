import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

extension ReviewLogToStorage on ReviewLog {
  ReviewLogsTableCompanion toStorageModel() => ReviewLogsTableCompanion(
    id: Value(id),
    flashcardId: Value(flashcardId),
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
