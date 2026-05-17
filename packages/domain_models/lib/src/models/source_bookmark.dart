import 'package:equatable/equatable.dart' show Equatable;

import 'source_type.dart';

/// A saved reading position inside a source.
class SourceBookmark extends Equatable {
  const SourceBookmark({
    required this.id,
    required this.sourceId,
    required this.sourceType,
    required this.cfi,
    required this.content,
    required this.progress,
    required this.createdAt,
    this.chapterTitle,
    this.anchorExact,
    this.anchorPrefix,
    this.anchorSuffix,
    this.anchorSectionIndex,
    this.anchorSectionPage,
  });

  final String id;
  final String sourceId;
  final SourceType sourceType;
  final String cfi;
  final String content;
  final double progress;
  final DateTime createdAt;
  final String? chapterTitle;
  final String? anchorExact;
  final String? anchorPrefix;
  final String? anchorSuffix;
  final int? anchorSectionIndex;
  final int? anchorSectionPage;

  @override
  List<Object?> get props => [
    id,
    sourceId,
    sourceType,
    cfi,
    content,
    progress,
    createdAt,
    chapterTitle,
    anchorExact,
    anchorPrefix,
    anchorSuffix,
    anchorSectionIndex,
    anchorSectionPage,
  ];
}
