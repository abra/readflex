part of 'select_collection_scope_sheet.dart';

typedef _LabelledScope = ({LibraryCollectionScope scope, String label});

/// The picker's entries for one query and how many of them are rows.
typedef _ScopeList = ({List<_ScopeEntry> entries, int rowCount});

/// The picker's rows for one [LibraryState] in one locale. Labels are
/// lowercased once here, so a keystroke only compares strings.
class _CollectionScopeCatalog {
  _CollectionScopeCatalog(this.state, this.l10n)
    : _libraryLabel = l10n.libraryTitle.toLowerCase(),
      _favourites = _labelled(state.favouriteCollectionScopes, l10n),
      _builtIns = _labelled(state.pickerBuiltInCollectionScopes, l10n),
      _sections = [
        (
          title: l10n.libraryManualCollections,
          scopes: _labelled(state.manualCollectionScopes, l10n),
        ),
        (
          title: l10n.librarySites,
          scopes: _labelled(state.siteCollectionScopes, l10n),
        ),
        (
          title: l10n.libraryAuthors,
          scopes: _labelled(state.authorCollectionScopes, l10n),
        ),
      ];

  final LibraryState state;
  final ReadflexLocalizations l10n;
  final String _libraryLabel;
  final List<_LabelledScope> _favourites;
  final List<_LabelledScope> _builtIns;
  final List<({String title, List<_LabelledScope> scopes})> _sections;

  bool isFor(LibraryState state, ReadflexLocalizations l10n) =>
      identical(this.state, state) && identical(this.l10n, l10n);

  /// The list for [query]; no entries when nothing matches. The first group
  /// has no title: Favourites directly under the search field, then Library
  /// and the built-in scopes. Manual collections, sites and authors follow
  /// under their titles.
  _ScopeList listFor(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    final selected = state.selectedCollectionScope;
    final entries = <_ScopeEntry>[];
    var rowCount = 0;

    List<LibraryCollectionScope> matching(List<_LabelledScope> scopes) => [
      for (final (:scope, :label) in scopes)
        if (label.contains(normalizedQuery)) scope,
    ];

    // A null row is the Library row.
    void addGroup(String? title, List<LibraryCollectionScope?> rows) {
      if (rows.isEmpty) return;
      if (title != null) entries.add(_ScopeTitleEntry(title));
      for (final (index, scope) in rows.indexed) {
        final endsSection = index == rows.length - 1;
        entries.add(
          scope == null
              ? _LibraryRowEntry(
                  count: state.totalCount,
                  selected: selected == null,
                  semanticIndex: rowCount++,
                  endsSection: endsSection,
                )
              : _CollectionScopeRowEntry(
                  scope: scope,
                  selected:
                      selected?.type == scope.type && selected?.id == scope.id,
                  semanticIndex: rowCount++,
                  endsSection: endsSection,
                ),
        );
      }
    }

    addGroup(null, [
      // Favourites stays first, under the search field, however many
      // built-in scopes the library lists.
      ...matching(_favourites),
      if (_libraryLabel.contains(normalizedQuery)) null,
      // Books, Articles, Comics and New sit with Library: they narrow by
      // what a source is.
      ...matching(_builtIns),
    ]);
    for (final (:title, :scopes) in _sections) {
      addGroup(title, matching(scopes));
    }
    return (entries: entries, rowCount: rowCount);
  }

  static List<_LabelledScope> _labelled(
    List<LibraryCollectionScope> scopes,
    ReadflexLocalizations l10n,
  ) => [
    for (final scope in scopes)
      (
        scope: scope,
        label: libraryCollectionScopeLabel(l10n, scope).toLowerCase(),
      ),
  ];
}
