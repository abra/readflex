import 'package:domain_models/domain_models.dart';
import 'package:drift/drift.dart';
import 'package:local_storage/local_storage.dart';

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
    fsrsState: Value(fsrs.state.toStorageString()),
    stability: Value(fsrs.stability),
    difficulty: Value(fsrs.difficulty),
    retrievability: Value(fsrs.retrievability),
    reps: Value(fsrs.reps),
    lapses: Value(fsrs.lapses),
    lastReviewAt: Value(fsrs.lastReviewAt?.toIso8601String()),
    nextReviewAt: Value(fsrs.nextReviewAt?.toIso8601String()),
    scheduledDays: Value(fsrs.scheduledDays),
    elapsedDays: Value(fsrs.elapsedDays),
  );
}
