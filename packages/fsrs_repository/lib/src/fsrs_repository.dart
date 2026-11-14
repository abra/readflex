import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:review_scheduler/review_scheduler.dart';

import 'mappers/review_item_to_domain.dart';
import 'mappers/review_item_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

/// Centralized repository for FSRS review state across all reviewable items
/// (saved words, highlights).
///
/// Wraps [ReviewItemsDao] and the pure-Dart [ReviewScheduler]: queries the
/// due queue, records reviews (compute next state + append to review logs),
/// and surfaces counts for the Practice hub. Entity repositories store the
/// items themselves and register them here when they are saved; FSRS state
/// is joined by `itemId`. Wraps low-level DB errors in [StorageException].
class FsrsRepository {
  FsrsRepository({
    required AppDatabase database,
    ReviewScheduler? reviewScheduler,
    DateTime Function()? clock,
  }) : _db = database,
       _dao = database.reviewItemsDao,
       _clock = clock ?? DateTime.now,
       _reviewScheduler =
           reviewScheduler ?? ReviewScheduler(clock: clock ?? DateTime.now);

  final AppDatabase _db;
  final ReviewItemsDao _dao;
  final ReviewScheduler _reviewScheduler;
  final DateTime Function() _clock;

  String get _nowIso => _clock().toUtc().toIso8601String();

  // ─── Create / Delete ───

  /// Creates a review tracking entry for a new item.
  Future<void> createReviewItem({
    required String itemId,
    required ReviewableType itemType,
    String? sourceId,
  }) async {
    try {
      final item = ReviewItem(
        itemId: itemId,
        itemType: itemType,
        sourceId: sourceId,
        fsrs: const FsrsCardData(),
      );
      await _dao.upsertItem(item.toStorageModel());
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Registers [items] that have no review row yet, keeping the scheduling
  /// state of the ones already tracked. Used to backfill content saved
  /// before review tracking existed.
  Future<void> ensureReviewItems(List<ReviewItem> items) async {
    if (items.isEmpty) return;
    try {
      await _dao.ensureItems([for (final i in items) i.toStorageModel()]);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Repairs missing legacy text-highlight tracking during app initialization.
  /// Performs one missing-only SQL insert, without loading highlight content.
  Future<void> backfillTextHighlights() async {
    try {
      await _dao.backfillTextHighlights();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Excludes a tracked item from review, preserving its schedule and history.
  /// Missing tracking is left absent; excluding a stale card cannot recreate it.
  Future<void> excludeReviewItem(String itemId) async {
    try {
      await _dao.excludeItem(itemId);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Physically removes tracking. User exclusion uses [excludeReviewItem].
  Future<void> deleteReviewItem(String itemId) async {
    try {
      await _dao.deleteItem(itemId);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  // ─── Query ───

  /// Gets the active FSRS state; absent or excluded tracking returns null.
  Future<FsrsCardData?> getReviewState(String itemId) async {
    try {
      final row = await _dao.byItemId(itemId);
      return row == null || row.isExcluded ? null : row.toDomainModel().fsrs;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Batch lookup: returns a map of itemId → FsrsCardData.
  Future<Map<String, FsrsCardData>> getReviewStates(
    List<String> itemIds,
  ) async {
    if (itemIds.isEmpty) return {};
    try {
      final rows = await _dao.byItemIds(itemIds);
      return {
        for (final row in rows)
          if (!row.isExcluded) row.itemId: row.toDomainModel().fsrs,
      };
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Every active tracked item of [type], in storage order.
  Future<List<ReviewItem>> getReviewItems(ReviewableType type) async {
    try {
      final rows = await _dao.byType(type.toStorageString());
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Returns IDs of all mastered items (fsrsState == review).
  Future<Set<String>> getMasteredItemIds({
    ReviewableType? type,
    int? limit,
    int? offset,
  }) async {
    try {
      final rows = await _dao.masteredItems(
        type: type?.toStorageString(),
        limit: limit,
        offset: offset,
      );
      return {for (final r in rows) r.itemId};
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Returns due items, filtering [type] or [types] and [states] before pagination.
  /// Null sets include all values; empty sets include none. [type] and [types]
  /// are mutually exclusive.
  Future<List<ReviewItem>> getDueItems({
    ReviewableType? type,
    Set<ReviewableType>? types,
    Set<FsrsState>? states,
    int? limit,
    int? offset,
  }) async {
    if (type != null && types != null) {
      throw ArgumentError('Provide either type or types, not both.');
    }
    try {
      final rows = await _dao.dueItems(
        _nowIso,
        type: type?.toStorageString(),
        types: types?.map((type) => type.toStorageString()).toSet(),
        states: states?.map((state) => state.toStorageString()).toSet(),
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<int> getDueItemCount({ReviewableType? type}) async {
    try {
      return await _dao.dueItemCount(_nowIso, type: type?.toStorageString());
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// A lightweight due count and deadline, without loading review history.
  /// Null [types] includes all tracked types; an empty set includes none.
  Future<ReviewQueueStatus> getReviewQueueStatus({
    Set<ReviewableType>? types,
  }) async {
    try {
      final now = _clock().toUtc().toIso8601String();
      final status = await _dao.reviewQueueStatus(
        now,
        types: types?.map((type) => type.toStorageString()).toSet(),
      );
      return ReviewQueueStatus(
        dueCount: status.dueCount,
        nextReviewAt: status.nextReviewAt == null
            ? null
            : DateTime.parse(status.nextReviewAt!).toUtc(),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Due items for a source, with the same type filters as [getDueItems].
  Future<List<ReviewItem>> getDueItemsBySource(
    String sourceId, {
    ReviewableType? type,
    Set<ReviewableType>? types,
    Set<FsrsState>? states,
    int? limit,
    int? offset,
  }) async {
    if (type != null && types != null) {
      throw ArgumentError('Provide either type or types, not both.');
    }
    try {
      final rows = await _dao.dueItemsBySource(
        sourceId,
        _nowIso,
        type: type?.toStorageString(),
        types: types?.map((type) => type.toStorageString()).toSet(),
        states: states?.map((state) => state.toStorageString()).toSet(),
        limit: limit,
        offset: offset,
      );
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Counts for the Practice hub: due, total and mastered per type, plus
  /// activity derived from the review log (today, last seven days, streak).
  Future<ReviewStats> getStats() async {
    try {
      final now = _clock();
      // Activity is counted in study days, like the schedule itself.
      final studyDay = _reviewScheduler.studyDay;
      final today = studyDay.dateOf(now);
      final dueByType = <ReviewableType, int>{};
      final totalByType = <ReviewableType, int>{};
      final masteredByType = <ReviewableType, int>{};
      for (final type in ReviewableType.values) {
        final key = type.toStorageString();
        dueByType[type] = await _dao.dueItemCount(_nowIso, type: key);
        totalByType[type] = await _dao.itemCount(type: key);
        masteredByType[type] = await _dao.masteredItemCount(type: key);
      }

      final logs = await _dao.reviewLogsSince(
        today.subtract(_streakWindow).toUtc().toIso8601String(),
      );
      final days = <DateTime>{};
      var reviewedToday = 0;
      var newReviewedToday = 0;
      var reviewedLast7Days = 0;
      final weekStart = today.subtract(const Duration(days: 6));
      for (final log in logs) {
        final at = DateTime.tryParse(log.reviewedAt);
        if (at == null) continue;
        final day = studyDay.dateOf(at);
        days.add(day);
        if (!day.isBefore(today)) {
          reviewedToday++;
          if (log.stateBefore == FsrsState.newCard.storageKey) {
            newReviewedToday++;
          }
        }
        if (!day.isBefore(weekStart)) reviewedLast7Days++;
      }

      var streak = 0;
      var cursor = days.contains(today)
          ? today
          : today.subtract(const Duration(days: 1));
      while (days.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }

      return ReviewStats(
        dueByType: dueByType,
        totalByType: totalByType,
        masteredByType: masteredByType,
        reviewedToday: reviewedToday,
        newReviewedToday: newReviewedToday,
        reviewedLast7Days: reviewedLast7Days,
        streakDays: streak,
        totalReviews: await _dao.reviewLogCount(),
      );
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// How far each rating would postpone [current] at [desiredRetention];
  /// see [ReviewScheduler.previewIntervals].
  Map<Rating, Duration> previewIntervals(
    FsrsCardData current, {
    double desiredRetention = defaultDesiredRetention,
  }) => _reviewScheduler.previewIntervals(
    current,
    desiredRetention: desiredRetention,
  );

  /// The day boundary the schedule and the activity counts follow.
  StudyDay get studyDay => _reviewScheduler.studyDay;

  // ─── Review ───

  /// Records a review for an item. Returns the updated FSRS state.
  ///
  /// Creates missing tracking only while the saved word or text highlight
  /// still exists. Throws [NotFoundException] for unavailable or excluded content
  /// so a late rating cannot undo deletion or exclusion. Legacy flashcard
  /// rows retain their compatibility behavior outside active Practice flows.
  Future<FsrsCardData> recordReview({
    required String itemId,
    required ReviewableType itemType,
    required Rating rating,
    String? sourceId,
    int? reviewDurationMs,
    double desiredRetention = defaultDesiredRetention,
  }) async {
    try {
      // Read → compute → upsert + log all live inside one transaction so two
      // concurrent calls on the same itemId cannot overwrite each other.
      return await _db.transaction(() async {
        final exists = switch (itemType) {
          ReviewableType.dictionary => await _db.dictionaryDao.entryExists(
            itemId,
          ),
          ReviewableType.highlight =>
            await _db.highlightsDao.textHighlightExists(
              itemId,
            ),
          ReviewableType.flashcard => true,
        };
        if (!exists) throw NotFoundException(itemId, itemType.name);

        final row = await _dao.byItemId(itemId);
        if (row?.isExcluded ?? false) {
          throw NotFoundException(itemId, itemType.name);
        }
        final currentFsrs = row?.toDomainModel().fsrs ?? const FsrsCardData();

        final result = _reviewScheduler.computeReview(
          itemId: itemId,
          itemType: itemType,
          currentFsrs: currentFsrs,
          rating: rating,
          reviewDurationMs: reviewDurationMs,
          desiredRetention: desiredRetention,
        );

        // Keep the stored sourceId on later reviews so passing null never
        // wipes it.
        final updated = ReviewItem(
          itemId: itemId,
          itemType: itemType,
          sourceId: row?.sourceId ?? sourceId,
          fsrs: result.fsrs,
        );
        await _dao.upsertItem(updated.toStorageModel());
        await _dao.insertReviewLog(result.log.toStorageModel());
        return result.fsrs;
      });
    } on NotFoundException {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}

const _streakWindow = Duration(days: 366);
