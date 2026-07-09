import 'package:domain_models/domain_models.dart';

String librarySourceSemanticsLabel(LibrarySource source) {
  final title = source.title.trim();
  return title.isEmpty ? 'Untitled source' : title;
}

String librarySourceSemanticsValue(LibrarySource source) {
  final attribution = _sourceAttribution(source);
  final format = _sourceFormatLabel(source);
  final parts = <String>[
    _sourceKindLabel(source),
    ?attribution,
    ?format,
    _readingStateLabel(source),
  ];

  return parts.join(', ');
}

String librarySourceTapHint({
  required bool isSelectionMode,
  required bool isSelected,
}) {
  if (!isSelectionMode) return 'Open reader';
  return isSelected ? 'Deselect source' : 'Select source';
}

String? librarySourceLongPressHint({required bool isSelectionMode}) {
  return isSelectionMode ? null : 'Select source';
}

String _sourceKindLabel(LibrarySource source) {
  if (source.sourceType == SourceType.article) return 'Article';
  return source.isComic ? 'Comic' : 'Book';
}

String? _sourceAttribution(LibrarySource source) {
  if (source.sourceType == SourceType.book) {
    return _trimmedOrNull(source.author);
  }

  return _trimmedOrNull(source.sourceName) ?? _trimmedOrNull(source.author);
}

String? _sourceFormatLabel(LibrarySource source) {
  if (source.sourceType == SourceType.article) return null;
  return _trimmedOrNull(source.typeLabel);
}

String _readingStateLabel(LibrarySource source) {
  if (source.isFinished) return 'Finished';
  if (source.isNew) return 'New';

  final progress = (source.readingProgress.clamp(0.0, 1.0) * 100).round();
  return '$progress percent read';
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
