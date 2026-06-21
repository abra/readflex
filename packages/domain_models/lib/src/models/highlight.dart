import 'package:equatable/equatable.dart' show Equatable;

import 'highlight_color.dart';
import 'source_type.dart';

enum HighlightKind {
  text,
  imageArea
  ;

  static HighlightKind from(String? value) => switch (value) {
    'imageArea' || 'image_area' => HighlightKind.imageArea,
    _ => HighlightKind.text,
  };
}

/// Normalized rectangle for an image-page highlight.
///
/// Coordinates are fractions of the visible page image, not physical pixels,
/// so the same highlight can be rendered after rotation or viewport changes.
class HighlightImageArea extends Equatable {
  const HighlightImageArea({
    required this.pageIndex,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final int pageIndex;
  final double x;
  final double y;
  final double width;
  final double height;

  @override
  List<Object?> get props => [pageIndex, x, y, width, height];
}

/// A saved highlight from a reading source.
///
/// [pageNumber] and [scrollOffset] are legacy positional fields kept for old
/// rows and tests. Text selections are anchored by [cfiRange]. Comic/image
/// page highlights are anchored by [imageArea].
class Highlight extends Equatable {
  const Highlight({
    required this.id,
    required this.sourceId,
    required this.sourceType,
    required this.text,
    required this.createdAt,
    this.kind = HighlightKind.text,
    this.note,
    this.cfiRange,
    this.imageArea,
    this.pageNumber,
    this.scrollOffset,
    this.progress,
    this.chapterTitle,
    this.color = HighlightColor.yellow,
  });

  final String id;
  final String sourceId;
  final SourceType sourceType;
  final String text;
  final HighlightKind kind;
  final String? note;
  final String? cfiRange;
  final HighlightImageArea? imageArea;
  final int? pageNumber;
  final double? scrollOffset;
  final double? progress;
  final String? chapterTitle;
  final HighlightColor color;
  final DateTime createdAt;

  bool get isImageArea => kind == HighlightKind.imageArea && imageArea != null;

  static const _absent = Object();

  Highlight copyWith({
    String? text,
    HighlightKind? kind,
    Object? note = _absent,
    Object? cfiRange = _absent,
    Object? imageArea = _absent,
    Object? pageNumber = _absent,
    Object? scrollOffset = _absent,
    Object? progress = _absent,
    Object? chapterTitle = _absent,
    HighlightColor? color,
  }) => Highlight(
    id: id,
    sourceId: sourceId,
    sourceType: sourceType,
    text: text ?? this.text,
    kind: kind ?? this.kind,
    note: note == _absent ? this.note : note as String?,
    cfiRange: cfiRange == _absent ? this.cfiRange : cfiRange as String?,
    imageArea: imageArea == _absent
        ? this.imageArea
        : imageArea as HighlightImageArea?,
    pageNumber: pageNumber == _absent ? this.pageNumber : pageNumber as int?,
    scrollOffset: scrollOffset == _absent
        ? this.scrollOffset
        : scrollOffset as double?,
    progress: progress == _absent ? this.progress : progress as double?,
    chapterTitle: chapterTitle == _absent
        ? this.chapterTitle
        : chapterTitle as String?,
    color: color ?? this.color,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    sourceId,
    sourceType,
    text,
    kind,
    note,
    cfiRange,
    imageArea,
    pageNumber,
    scrollOffset,
    progress,
    chapterTitle,
    color,
    createdAt,
  ];
}
