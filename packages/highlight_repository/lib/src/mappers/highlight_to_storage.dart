import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';
import 'package:domain_models/domain_models.dart';

extension HighlightToStorage on Highlight {
  HighlightsTableCompanion toStorageModel() => HighlightsTableCompanion(
    id: Value(id),
    sourceId: Value(sourceId),
    sourceType: Value(sourceType.name),
    highlightText: Value(text),
    note: Value(note),
    cfiRange: Value(cfiRange),
    pageNumber: Value(pageNumber),
    scrollOffset: Value(scrollOffset),
    color: Value(color.name),
    createdAt: Value(createdAt.toIso8601String()),
  );
}
