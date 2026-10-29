/// One entry of a book's table of contents, flattened for the drawer.
///
/// [href] is the navigation target accepted by `ReaderSurface.goToHref`;
/// [level] preserves nesting depth so the drawer can show the chapter
/// hierarchy without walking a recursive tree.
class ReaderTocItem {
  const ReaderTocItem({
    required this.label,
    required this.href,
    required this.level,
    this.id,
    this.startPercentage,
    this.startPage,
  });

  final String label;
  final String href;
  final String? id;
  final int level;
  final double? startPercentage;

  /// The page the entry opens, counted from 1, for books of fixed pages.
  final int? startPage;
}
