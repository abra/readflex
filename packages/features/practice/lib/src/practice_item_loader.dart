import 'package:dictionary_repository/dictionary_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:fsrs_repository/fsrs_repository.dart';
import 'package:highlight_repository/highlight_repository.dart';

import 'practice_item.dart';
import 'practice_source_index.dart';

/// Turns review rows into display-ready [PracticeItem]s: one batch query per
/// type, due order kept, items whose content was deleted dropped.
class PracticeItemLoader {
  const PracticeItemLoader({
    required DictionaryRepository dictionaryRepository,
    required HighlightRepository highlightRepository,
    required FsrsRepository fsrsRepository,
  }) : _dictionaryRepository = dictionaryRepository,
       _highlightRepository = highlightRepository,
       _fsrsRepository = fsrsRepository;

  final DictionaryRepository _dictionaryRepository;
  final HighlightRepository _highlightRepository;
  final FsrsRepository _fsrsRepository;

  Future<List<PracticeItem>> resolve(
    List<ReviewItem> rows,
    PracticeSourceIndex sources,
  ) async {
    final wordIds = <String>[];
    final highlightIds = <String>[];
    for (final row in rows) {
      switch (row.itemType) {
        case ReviewableType.dictionary:
          wordIds.add(row.itemId);
        case ReviewableType.highlight:
          highlightIds.add(row.itemId);
        case ReviewableType.flashcard:
          break;
      }
    }
    final (entries, highlights) = await (
      _dictionaryRepository.getEntriesByIds(wordIds),
      _highlightRepository.getHighlightsByIds(highlightIds),
    ).wait;
    final anchors = <String, String>{};
    for (final entry in entries) {
      final entryAnchors = await _dictionaryRepository.getAnchorsByEntry(
        entry.id,
      );
      if (entryAnchors.isNotEmpty) {
        anchors[entry.id] = entryAnchors.first.cfiRange;
      }
    }
    final entryById = {for (final e in entries) e.id: e};
    final highlightById = {for (final h in highlights) h.id: h};
    return [
      for (final row in rows)
        switch (row.itemType) {
          ReviewableType.dictionary when entryById[row.itemId] != null =>
            PracticeWordItem(
              entry: entryById[row.itemId]!,
              fsrs: row.fsrs,
              sourceTitle: sources.titleOf(entryById[row.itemId]!.sourceId),
              anchorCfiRange: anchors[row.itemId],
            ),
          ReviewableType.highlight
              when highlightById[row.itemId]?.kind == HighlightKind.text =>
            PracticeHighlightItem(
              highlight: highlightById[row.itemId]!,
              fsrs: row.fsrs,
              sourceTitle: sources.titleOf(highlightById[row.itemId]!.sourceId),
            ),
          _ => null,
        },
    ].nonNulls.toList();
  }

  /// Registers review rows for text highlights saved before review tracking
  /// existed, so they can come up for review.
  Future<void> backfillHighlights() async {
    final highlights = await _highlightRepository.getHighlights();
    await _fsrsRepository.ensureReviewItems([
      for (final h in highlights)
        if (h.kind == HighlightKind.text)
          ReviewItem(
            itemId: h.id,
            itemType: ReviewableType.highlight,
            sourceId: h.sourceId,
            fsrs: const FsrsCardData(),
          ),
    ]);
  }
}
