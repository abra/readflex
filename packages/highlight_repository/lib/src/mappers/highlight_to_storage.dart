import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

extension HighlightToStorage on Highlight {
  HighlightsTableCompanion toStorageModel() => HighlightsTableCompanion(
    id: Value(id),
    sourceId: Value(sourceId),
    sourceType: Value(sourceType.name),
    kind: Value(kind.name),
    highlightText: Value(text),
    note: Value(note),
    cfiRange: Value(cfiRange),
    imagePageIndex: Value(imageArea?.pageIndex),
    imageAreaX: Value(imageArea?.x),
    imageAreaY: Value(imageArea?.y),
    imageAreaWidth: Value(imageArea?.width),
    imageAreaHeight: Value(imageArea?.height),
    pageNumber: Value(pageNumber),
    scrollOffset: Value(scrollOffset),
    progress: Value(progress),
    chapterTitle: Value(chapterTitle),
    color: Value(color.name),
    createdAt: Value(createdAt.toIso8601String()),
  );
}
