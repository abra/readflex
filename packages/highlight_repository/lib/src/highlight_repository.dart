import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';
import 'package:uuid/uuid.dart' show Uuid;

import 'mappers/highlight_to_domain.dart';
import 'mappers/highlight_to_storage.dart';

const _uuid = Uuid();

/// Domain repository for text highlights.
class HighlightRepository {
  HighlightRepository({@visibleForTesting HighlightsDao? highlightsDao})
    : _dao = highlightsDao;

  HighlightsDao? _dao;

  void init(HighlightsDao dao) => _dao = dao;

  HighlightsDao get _highlights {
    final dao = _dao;
    if (dao == null) {
      throw StateError(
        'HighlightRepository not initialized. Call init() first.',
      );
    }
    return dao;
  }

  Future<List<Highlight>> getHighlights() async {
    try {
      final rows = await _highlights.allHighlights();
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<List<Highlight>> getHighlightsBySource(String sourceId) async {
    try {
      final rows = await _highlights.highlightsBySource(sourceId);
      return rows.map((r) => r.toDomainModel()).toList();
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<Highlight?> getHighlightById(String id) async {
    try {
      final row = await _highlights.highlightById(id);
      return row?.toDomainModel();
    } catch (e) {
      throw StorageException(cause: e);
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
    try {
      await _highlights.insertHighlight(highlight.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return highlight;
  }

  Future<Highlight> updateHighlight(Highlight highlight) async {
    try {
      await _highlights.updateHighlight(highlight.toStorageModel());
    } catch (e) {
      throw StorageException(cause: e);
    }
    return highlight;
  }

  Future<void> deleteHighlight(String id) async {
    try {
      await _highlights.deleteHighlight(id);
    } catch (e) {
      throw StorageException(cause: e);
    }
  }

  Future<void> deleteHighlightsBySource(String sourceId) async {
    try {
      await _highlights.deleteHighlightsBySource(sourceId);
    } catch (e) {
      throw StorageException(cause: e);
    }
  }
}
