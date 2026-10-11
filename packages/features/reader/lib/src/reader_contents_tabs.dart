import 'package:domain_models/domain_models.dart';

/// Tabs of the reader's Contents sheet.
enum ReaderContentsTab { chapters, pages, bookmarks, highlights }

/// The Contents tabs a document has, in display order.
///
/// Comics list pages instead of chapters: their table of contents is the page
/// list. PDF keeps Chapters first, even without an outline, and adds a page
/// grid once its page count is known. Other books list chapters.
List<ReaderContentsTab> readerContentsTabs({
  required BookFormat? format,
  required bool hasPageGrid,
}) => [
  if (format == BookFormat.cbz)
    ReaderContentsTab.pages
  else ...[
    ReaderContentsTab.chapters,
    if (format == BookFormat.pdf && hasPageGrid) ReaderContentsTab.pages,
  ],
  ReaderContentsTab.bookmarks,
  ReaderContentsTab.highlights,
];
