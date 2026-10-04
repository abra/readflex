import 'package:domain_models/domain_models.dart';

import 'reader_highlight_location_label.dart';

List<Highlight> filterReaderHighlights(
  List<Highlight> highlights,
  String query, {
  HighlightColor? color,
  String Function(int)? formatPage,
}) {
  final normalizedQuery = _normalizeHighlightQuery(query);
  if (normalizedQuery.isEmpty && color == null) return highlights;

  return [
    for (final highlight in highlights)
      if ((color == null || highlight.color == color) &&
          (normalizedQuery.isEmpty ||
              _highlightSearchText(
                highlight,
                formatPage,
              ).contains(normalizedQuery)))
        highlight,
  ];
}

String _highlightSearchText(
  Highlight highlight,
  String Function(int)? formatPage,
) {
  return [
    highlight.text,
    highlight.note,
    highlight.cfiRange,
    readerHighlightLocationLabel(highlight, formatPage: formatPage),
    // Retain the legacy search term while displaying the localized label.
    if (highlight.pageNumber != null) 'Page ${highlight.pageNumber}',
    highlight.color.name,
  ].whereType<String>().map(_normalizeHighlightQuery).join(' ');
}

String _normalizeHighlightQuery(String value) => value.trim().toLowerCase();
