import 'package:domain_models/domain_models.dart';
import 'package:local_storage/local_storage.dart';

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

HighlightImageArea? _imageAreaFromRow(HighlightsTableData row) {
  final pageIndex = row.imagePageIndex;
  final x = row.imageAreaX;
  final y = row.imageAreaY;
  final width = row.imageAreaWidth;
  final height = row.imageAreaHeight;
  if (pageIndex == null ||
      x == null ||
      y == null ||
      width == null ||
      height == null) {
    return null;
  }
  return HighlightImageArea(
    pageIndex: pageIndex,
    x: x,
    y: y,
    width: width,
    height: height,
  );
}

extension HighlightToDomain on HighlightsTableData {
  Highlight toDomainModel() => Highlight(
    id: id,
    sourceId: sourceId,
    sourceType: SourceType.from(sourceType),
    text: highlightText,
    kind: HighlightKind.from(kind),
    note: note,
    cfiRange: cfiRange,
    imageArea: _imageAreaFromRow(this),
    pageNumber: pageNumber,
    scrollOffset: scrollOffset,
    progress: progress,
    chapterTitle: chapterTitle,
    color: HighlightColor.from(color),
    createdAt: DateTime.tryParse(createdAt) ?? _epoch,
  );
}
