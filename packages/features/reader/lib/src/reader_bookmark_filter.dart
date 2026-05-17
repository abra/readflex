import 'package:domain_models/domain_models.dart';

List<SourceBookmark> filterReaderBookmarks(
  List<SourceBookmark> bookmarks,
  String query,
) {
  final normalizedQuery = _normalizeBookmarkQuery(query);
  if (normalizedQuery.isEmpty) return bookmarks;

  return [
    for (final bookmark in bookmarks)
      if (_bookmarkSearchText(bookmark).contains(normalizedQuery)) bookmark,
  ];
}

String _bookmarkSearchText(SourceBookmark bookmark) {
  final percentage = (bookmark.progress * 100).clamp(0, 100).round();
  return [
    bookmark.content.isEmpty ? 'bookmarked page' : bookmark.content,
    bookmark.chapterTitle,
    '$percentage%',
    bookmark.cfi,
  ].whereType<String>().map(_normalizeBookmarkQuery).join(' ');
}

String _normalizeBookmarkQuery(String value) => value.trim().toLowerCase();
