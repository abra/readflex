import 'package:domain_models/domain_models.dart';

List<Highlight> filterReaderHighlights(
  List<Highlight> highlights,
  String query,
) {
  final normalizedQuery = _normalizeHighlightQuery(query);
  if (normalizedQuery.isEmpty) return highlights;

  return [
    for (final highlight in highlights)
      if (_highlightSearchText(highlight).contains(normalizedQuery)) highlight,
  ];
}

String _highlightSearchText(Highlight highlight) {
  return [
    highlight.text,
    highlight.note,
    highlight.cfiRange,
    highlight.pageNumber == null ? null : 'page ${highlight.pageNumber}',
    highlight.color.name,
  ].whereType<String>().map(_normalizeHighlightQuery).join(' ');
}

String _normalizeHighlightQuery(String value) => value.trim().toLowerCase();
