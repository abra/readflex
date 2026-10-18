part of 'select_collection_scope_sheet.dart';

/// One item of the picker's flat lazy list: a section title or a row. Rows
/// carry their place among the rows, so screen readers count options rather
/// than titles, and the last row of a section keeps the gap below it.
sealed class _ScopeEntry {
  const _ScopeEntry();
}

final class _ScopeTitleEntry extends _ScopeEntry {
  const _ScopeTitleEntry(this.title);

  final String title;
}

/// The Library row: selected while no scope is.
final class _LibraryRowEntry extends _ScopeEntry {
  const _LibraryRowEntry({
    required this.count,
    required this.selected,
    required this.semanticIndex,
    required this.endsSection,
  });

  final int count;
  final bool selected;
  final int semanticIndex;
  final bool endsSection;
}

final class _CollectionScopeRowEntry extends _ScopeEntry {
  const _CollectionScopeRowEntry({
    required this.scope,
    required this.selected,
    required this.semanticIndex,
    required this.endsSection,
  });

  final LibraryCollectionScope scope;
  final bool selected;
  final int semanticIndex;
  final bool endsSection;
}
