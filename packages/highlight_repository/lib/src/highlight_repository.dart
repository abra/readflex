import 'package:local_storage/local_storage.dart';
import 'package:domain_models/domain_models.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/highlight_to_domain.dart';
import 'mappers/highlight_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for text highlights.
class HighlightRepository {
  HighlightRepository({required HighlightsDao highlightsDao})
    : _dao = highlightsDao;

  final HighlightsDao _dao;

  Future<List<Highlight>> getHighlights() async {
    final rows = await _dao.allHighlights();
    return rows.map((r) => r.toDomainModel()).toList();
  }

  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    final rows = await _dao.highlightsBySource(sourceId);
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
}
