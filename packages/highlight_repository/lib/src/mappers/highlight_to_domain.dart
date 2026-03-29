import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

extension HighlightToDomain on HighlightsTableData {
  Highlight toDomainModel() => Highlight(
    id: id,
    sourceId: sourceId,
    sourceType: SourceType.from(sourceType),
    text: highlightText,
    note: note,
    cfiRange: cfiRange,
    pageNumber: pageNumber,
    scrollOffset: scrollOffset,
    color: HighlightColor.from(color),
    createdAt: DateTime.parse(createdAt),
    fsrs: FsrsCardData(
      state: FsrsState.from(fsrsState),
      stability: stability,
      difficulty: difficulty,
      retrievability: retrievability,
      reps: reps,
      lapses: lapses,
      lastReviewAt: lastReviewAt != null ? DateTime.parse(lastReviewAt!) : null,
      nextReviewAt: nextReviewAt != null ? DateTime.parse(nextReviewAt!) : null,
      scheduledDays: scheduledDays,
      elapsedDays: elapsedDays,
    ),
  );
}
