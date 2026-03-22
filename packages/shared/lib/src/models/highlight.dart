import 'package:equatable/equatable.dart' show Equatable;

import 'highlight_color.dart';
import 'source_type.dart';

/// A text highlight from a book or article.
final class Highlight extends Equatable {
  const Highlight({
    required this.id,
    required this.sourceId,
    required this.sourceType,
    required this.text,
    required this.createdAt,
    this.note,
    this.cfiRange,
    this.pageNumber,
    this.scrollOffset,
    this.color = HighlightColor.yellow,
  });

  final String id;
  final String sourceId;
  final SourceType sourceType;
  final String text;
  final String? note;
  final String? cfiRange;
  final int? pageNumber;
  final double? scrollOffset;
  final HighlightColor color;
  final DateTime createdAt;

  static const _absent = Object();

  Highlight copyWith({
    String? text,
    Object? note = _absent,
    Object? cfiRange = _absent,
    Object? pageNumber = _absent,
    Object? scrollOffset = _absent,
    HighlightColor? color,
  }) => Highlight(
    id: id,
    sourceId: sourceId,
    sourceType: sourceType,
    text: text ?? this.text,
    note: note == _absent ? this.note : note as String?,
    cfiRange: cfiRange == _absent ? this.cfiRange : cfiRange as String?,
    pageNumber: pageNumber == _absent ? this.pageNumber : pageNumber as int?,
    scrollOffset: scrollOffset == _absent
        ? this.scrollOffset
        : scrollOffset as double?,
    color: color ?? this.color,
    createdAt: createdAt,
  );

  @override
  List<Object?> get props => [
    id,
    sourceId,
    sourceType,
    text,
    note,
    cfiRange,
    pageNumber,
    scrollOffset,
    color,
    createdAt,
  ];
}
