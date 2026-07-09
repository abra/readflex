import 'package:domain_models/domain_models.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

String librarySourceSemanticsLabel(
  LibrarySource source,
  ReadflexLocalizations l10n,
) {
  final title = source.title.trim();
  return title.isEmpty ? l10n.librarySourceUntitled : title;
}

String librarySourceSemanticsValue(
  LibrarySource source,
  ReadflexLocalizations l10n,
) {
  final attribution = _sourceAttribution(source);
  final format = _sourceFormatLabel(source);
  final parts = <String>[
    librarySourceKindLabel(source, l10n),
    ?attribution,
    ?format,
    _readingStateLabel(source, l10n),
  ];

  return parts.join(', ');
}

String librarySourceTapHint({
  required bool isSelectionMode,
  required bool isSelected,
  required ReadflexLocalizations l10n,
}) {
  if (!isSelectionMode) return l10n.librarySourceOpenReader;
  return isSelected ? l10n.librarySourceDeselect : l10n.librarySourceSelect;
}

String? librarySourceLongPressHint({
  required bool isSelectionMode,
  required ReadflexLocalizations l10n,
}) {
  return isSelectionMode ? null : l10n.librarySourceSelect;
}

String librarySourceKindLabel(
  LibrarySource source,
  ReadflexLocalizations l10n,
) {
  if (source.sourceType == SourceType.article) return l10n.librarySourceArticle;
  return source.isComic ? l10n.librarySourceComic : l10n.librarySourceBook;
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

String _readingStateLabel(LibrarySource source, ReadflexLocalizations l10n) {
  if (source.isFinished) return l10n.librarySourceFinished;
  if (source.isNew) return l10n.librarySourceNew;

  final progress = (source.readingProgress.clamp(0.0, 1.0) * 100).round();
  return l10n.librarySourcePercentRead(progress);
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}
