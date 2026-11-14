import 'package:domain_models/domain_models.dart';

import 'reader_format_capabilities.dart';

/// Tabs of the reader's Contents sheet.
enum ReaderContentsTab { chapters, pages, bookmarks, highlights }

/// The Contents tabs a document has, in display order.
///
/// Comics list pages instead of chapters: their table of contents is the page
/// list. PDF and DjVu keep Chapters first, even without an outline, and add a page
/// grid once its page count is known. Other books list chapters.
List<ReaderContentsTab> readerContentsTabs({
  SourceType sourceType = SourceType.book,
  required BookFormat? format,
  required bool hasPageGrid,
}) => switch (readerFormatCapabilitiesFor(
  sourceType: sourceType,
  format: format,
).contentsMode) {
  ReaderContentsMode.pages => const [
    ReaderContentsTab.pages,
    ReaderContentsTab.bookmarks,
    ReaderContentsTab.highlights,
  ],
  ReaderContentsMode.chaptersAndPages when hasPageGrid => const [
    ReaderContentsTab.chapters,
    ReaderContentsTab.pages,
    ReaderContentsTab.bookmarks,
    ReaderContentsTab.highlights,
  ],
  _ => const [
    ReaderContentsTab.chapters,
    ReaderContentsTab.bookmarks,
    ReaderContentsTab.highlights,
  ],
};
