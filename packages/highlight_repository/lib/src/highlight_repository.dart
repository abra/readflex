import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:review_scheduler/review_scheduler.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/highlight_to_domain.dart';
import 'mappers/highlight_to_storage.dart';
import 'mappers/review_log_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for text highlights with FSRS v6 scheduling.
class HighlightRepository {
  HighlightRepository({
    required AppDatabase database,
    ReviewScheduler? reviewScheduler,
  }) : _dao = database.highlightsDao,
       _reviewScheduler = reviewScheduler ?? ReviewScheduler();

  final HighlightsDao _dao;
  final ReviewScheduler _reviewScheduler;

  // ─── CRUD ───

  Future<List<Highlight>> getHighlights() async {
    final rows = await _dao.allHighlights();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    final rows = await _dao.highlightsBySource(sourceId);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getDueHighlights() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueHighlights(now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getDueHighlightsBySource(String sourceId) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _dao.dueHighlightsBySource(sourceId, now);
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<Highlight?> getHighlightById(String id) async {
    final row = await _dao.highlightById(id);
    return row?.toDomainModel();
  }

  Future<Highlight> addHighlight({
    required String sourceId,
    required SourceType sourceType,
    required String text,
    String? note,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
    HighlightColor color = HighlightColor.yellow,
  }) async {
    final highlight = Highlight(
      id: _uuid.v4(),
      sourceId: sourceId,
      sourceType: sourceType,
      text: text,
      note: note,
      cfiRange: cfiRange,
      pageNumber: pageNumber,
      scrollOffset: scrollOffset,
      color: color,
      createdAt: DateTime.now(),
    );
    await _dao.insertHighlight(highlight.toStorageModel());
    return highlight;
  }

  Future<Highlight> updateHighlight(Highlight highlight) async {
    await _dao.updateHighlight(highlight.toStorageModel());
    return highlight;
  }

  Future<void> deleteHighlight(String id) async {
    await _dao.deleteHighlight(id);
  }

  Future<void> deleteHighlightsBySource(String sourceId) async {
    await _dao.deleteHighlightsBySource(sourceId);
  }

  // ─── Review (FSRS) ───

  Future<Highlight> recordReview(
    Highlight highlight,
    Rating rating, {
    int? reviewDurationMs,
  }) async {
    final result = _reviewScheduler.computeReview(
      itemId: highlight.id,
      itemType: ReviewableType.highlight,
      currentFsrs: highlight.fsrs,
      rating: rating,
      reviewDurationMs: reviewDurationMs,
    );

    final updated = highlight.copyWith(fsrs: result.fsrs);
    await _dao.updateHighlight(updated.toStorageModel());
    await _dao.insertReviewLog(result.log.toStorageModel());

    return updated;
  }
}
