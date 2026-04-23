import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/highlight_to_domain.dart';
import 'mappers/highlight_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for text highlights.
///
/// Wraps [HighlightsDao] from `local_storage` and turns low-level DB errors
/// into [StorageException]. Does not own FSRS review state — that lives in
/// `FsrsRepository` and is joined by `itemId`.
class HighlightRepository {
  HighlightRepository({required AppDatabase database})
    : _dao = database.highlightsDao;

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

  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    try {
      final rows = await _dao.highlightsBySource(sourceId);
      return rows.map((r) => r.toDomainModel()).toList();
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
    HighlightColor color = HighlightColor.yellow,
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

  Future<void> deleteHighlight(String id) async {
    try {
      await _dao.deleteHighlight(id);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }

  /// Bulk-deletes every highlight attached to [sourceId]. Called when the
  /// parent book or article is removed so the highlights table doesn't
  /// accumulate orphans.
  Future<void> deleteHighlightsBySource(String sourceId) async {
    try {
      await _dao.deleteHighlightsBySource(sourceId);
    } catch (e, st) {
      Error.throwWithStackTrace(StorageException(cause: e), st);
    }
  }
}
