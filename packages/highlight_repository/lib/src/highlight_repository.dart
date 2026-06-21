import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/highlight_to_domain.dart';
import 'mappers/highlight_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for text highlights.
///
/// Wraps [HighlightsDao] from `local_storage` and turns low-level DB errors
/// into [StorageException]. Matching FSRS review rows are co-deleted here in
/// the same transaction so a deleted highlight never leaves orphan review
/// state behind.
class HighlightRepository {
  HighlightRepository({required AppDatabase database})
    : _db = database,
      _dao = database.highlightsDao;

  final AppDatabase _db;
  final HighlightsDao _dao;

  // ─── CRUD ───

  Future<List<Highlight>> getHighlights() async {
    try {
      final rows = await _dao.allHighlights();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<int> getHighlightCount() async {
    try {
      return await _dao.highlightCount();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    try {
      final rows = await _dao.highlightsBySource(sourceId);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<int> getHighlightCountBySource(String sourceId) async {
    try {
      return await _dao.highlightCountBySource(sourceId);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Highlight?> getHighlightById(String id) async {
    try {
      final row = await _dao.highlightById(id);
      return row?.toDomainModel();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<List<Highlight>> getHighlightsByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    try {
      final rows = await _dao.highlightsByIds(ids);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Highlight> addHighlight({
    required String sourceId,
    required SourceType sourceType,
    required String text,
    String? note,
    String? cfiRange,
    int? pageNumber,
    double? scrollOffset,
    double? progress,
    String? chapterTitle,
    HighlightColor color = HighlightColor.yellow,
    List<String> replaceHighlightIds = const [],
  }) async {
    try {
      final highlight = Highlight(
        id: _uuid.v4(),
        sourceId: sourceId,
        sourceType: sourceType,
        text: text,
        note: note,
        cfiRange: cfiRange,
        pageNumber: pageNumber,
        scrollOffset: scrollOffset,
        progress: progress,
        chapterTitle: chapterTitle,
        color: color,
        createdAt: DateTime.now(),
      );
      await _db.transaction(() async {
        if (replaceHighlightIds.isNotEmpty) {
          final replaceIds = replaceHighlightIds.toSet().toList();
          final sourceScopedIds = [
            for (final row in await _dao.highlightsByIds(replaceIds))
              if (row.sourceId == sourceId) row.id,
          ];
          await _db.reviewItemsDao.deleteItemsByIds(sourceScopedIds);
          await _dao.deleteHighlightsByIds(sourceScopedIds);
        }
        await _dao.insertHighlight(highlight.toStorageModel());
      });
      return highlight;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Highlight> addImageAreaHighlight({
    required String sourceId,
    required SourceType sourceType,
    required int pageIndex,
    required double x,
    required double y,
    required double width,
    required double height,
    String? note,
    double? progress,
    String? chapterTitle,
    HighlightColor color = HighlightColor.yellow,
  }) async {
    try {
      final imageArea = HighlightImageArea(
        pageIndex: pageIndex,
        x: x,
        y: y,
        width: width,
        height: height,
      );
      final highlight = Highlight(
        id: _uuid.v4(),
        sourceId: sourceId,
        sourceType: sourceType,
        text: 'Page highlight',
        kind: HighlightKind.imageArea,
        note: note,
        imageArea: imageArea,
        pageNumber: pageIndex + 1,
        progress: progress,
        chapterTitle: chapterTitle,
        color: color,
        createdAt: DateTime.now(),
      );
      await _dao.insertHighlight(highlight.toStorageModel());
      return highlight;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  Future<Highlight> updateHighlight(Highlight highlight) async {
    try {
      await _dao.updateHighlight(highlight.toStorageModel());
      return highlight;
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Deletes the highlight and its FSRS review row in one transaction.
  /// Without the FSRS purge a deleted highlight stays in the review queue
  /// forever (DAO returns a row for any `next_review_at` already due,
  /// regardless of whether the underlying entity still exists).
  Future<void> deleteHighlight(String id) async {
    try {
      await _db.transaction(() async {
        await _db.reviewItemsDao.deleteItemsByIds([id]);
        await _dao.deleteHighlight(id);
      });
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Bulk-deletes every highlight attached to [sourceId] together with
  /// their FSRS review rows. Called when the parent source is removed so
  /// neither the highlights table nor `review_items_table` accumulates
  /// orphans.
  Future<void> deleteHighlightsBySource(String sourceId) async {
    try {
      await _db.transaction(() async {
        await _db.reviewItemsDao.deleteItemsBySourceAndType(
          sourceId,
          ReviewableType.highlight.name,
        );
        await _dao.deleteHighlightsBySource(sourceId);
      });
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}
