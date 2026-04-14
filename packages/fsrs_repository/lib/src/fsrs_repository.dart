import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:review_scheduler/review_scheduler.dart';

import 'mappers/review_item_to_domain.dart';
import 'mappers/review_item_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

/// Centralized repository for FSRS review state across all reviewable items
/// (flashcards, highlights, dictionary entries).
class FsrsRepository {
  FsrsRepository({
    required AppDatabase database,
    ReviewScheduler? reviewScheduler,
  }) : _dao = database.reviewItemsDao,
       _reviewScheduler = reviewScheduler ?? ReviewScheduler();

  final ReviewItemsDao _dao;
  final ReviewScheduler _reviewScheduler;

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

  /// Removes review tracking for an item (e.g. when item is deleted).
  Future<void> deleteReviewItem(String itemId) async {
    try {
      await _dao.deleteItem(itemId);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  // ─── Query ───

  /// Gets the FSRS state for a single item. Returns null if not tracked.
  Future<FsrsCardData?> getReviewState(String itemId) async {
    try {
      final row = await _dao.byItemId(itemId);
      return row?.toDomainModel().fsrs;
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
      return {for (final r in rows) r.itemId: r.toDomainModel().fsrs};
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Returns IDs of all mastered items (fsrsState == review).
  Future<Set<String>> getMasteredItemIds({ReviewableType? type}) async {
    try {
      final rows = await _dao.masteredItems(type: type?.toStorageString());
      return {for (final r in rows) r.itemId};
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Returns all due review items, optionally filtered by type.
  Future<List<ReviewItem>> getDueItems({ReviewableType? type}) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _dao.dueItems(now, type: type?.toStorageString());
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Returns due review items for a specific source.
  Future<List<ReviewItem>> getDueItemsBySource(
    String sourceId, {
    ReviewableType? type,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final rows = await _dao.dueItemsBySource(
        sourceId,
        now,
        type: type?.toStorageString(),
      );
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  // ─── Review ───

  /// Records a review for an item. Returns the updated FSRS state.
  ///
  /// Implicitly creates a review tracking row on the first review — callers
  /// don't need to call [createReviewItem] first. This keeps the review flow
  /// decoupled from entity creation: a highlight or dictionary word only
  /// enters FSRS tracking the moment the user actually reviews it, not the
  /// moment it's saved. As a side effect, items that are never reviewed
  /// don't take up space in review_items_table.
  Future<FsrsCardData> recordReview({
    required String itemId,
    required ReviewableType itemType,
    required Rating rating,
    int? reviewDurationMs,
  }) async {
    try {
      // Default to a blank FsrsCardData when the item has never been reviewed —
      // this is the "implicit creation" path (see doc above).
      final row = await _dao.byItemId(itemId);
      final currentFsrs = row?.toDomainModel().fsrs ?? const FsrsCardData();

      final result = _reviewScheduler.computeReview(
        itemId: itemId,
        itemType: itemType,
        currentFsrs: currentFsrs,
        rating: rating,
        reviewDurationMs: reviewDurationMs,
      );

      // Update review item state.
      final sourceId = row?.sourceId;
      final updated = ReviewItem(
        itemId: itemId,
        itemType: itemType,
        sourceId: sourceId,
        fsrs: result.fsrs,
      );
      await _dao.upsertItem(updated.toStorageModel());

      // Persist review log.
      await _dao.insertReviewLog(result.log.toStorageModel());

      return result.fsrs;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}
