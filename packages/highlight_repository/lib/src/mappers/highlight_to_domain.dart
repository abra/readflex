import 'package:local_storage/local_storage.dart';
import 'package:shared/shared.dart';

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
  );
}
