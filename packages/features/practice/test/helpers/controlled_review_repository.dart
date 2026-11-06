import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';

import 'practice_harness.dart';

/// Delays accepted mutations while keeping actual SQLite scheduling writes.
class ControlledReviewRepository extends FsrsRepository {
  ControlledReviewRepository(PracticeHarness harness)
    : super(database: harness.database, clock: () => harness.now);

  final gate = Completer<void>();
  final recordStarted = Completer<void>();
  final deleteStarted = Completer<void>();
  Completer<void>? recordGate;
  Completer<void>? deleteGate;
  final persistedRatings = <(String, Rating)>[];
  final deletedIds = <String>[];
  bool failRecord = false;
  bool failDelete = false;

  void release() {
    if (!gate.isCompleted) gate.complete();
  }

  @override
  Future<FsrsCardData> recordReview({
    required String itemId,
    required ReviewableType itemType,
    required Rating rating,
    String? sourceId,
    int? reviewDurationMs,
    double desiredRetention = 0.9,
  }) async {
    if (!recordStarted.isCompleted) recordStarted.complete();
    await recordGate?.future;
    if (failRecord) throw const StorageException(cause: 'record failed');
    final result = await super.recordReview(
      itemId: itemId,
      itemType: itemType,
      rating: rating,
      sourceId: sourceId,
      reviewDurationMs: reviewDurationMs,
      desiredRetention: desiredRetention,
    );
    persistedRatings.add((itemId, rating));
    return result;
  }

  @override
  Future<void> deleteReviewItem(String itemId) async {
    if (!deleteStarted.isCompleted) deleteStarted.complete();
    await deleteGate?.future;
    if (failDelete) throw const StorageException(cause: 'delete failed');
    await super.deleteReviewItem(itemId);
    deletedIds.add(itemId);
  }
}
