import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

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
    progress: progress,
    chapterTitle: chapterTitle,
    color: HighlightColor.from(color),
    createdAt: DateTime.tryParse(createdAt) ?? _epoch,
  );
}
