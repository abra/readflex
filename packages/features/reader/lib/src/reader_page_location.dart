import 'dart:math' as math;

import 'package:domain_models/domain_models.dart';
import 'package:flutter/painting.dart';
import 'package:pagecraft/pagecraft.dart';

import 'reader_document.dart';
import 'reader_selection.dart';

/// The saved page of a native fixed-layout book: the CFI either reader
/// wrote, or the fraction for rows saved without one.
int initialReaderPage(ReaderDocument document, int pageCount) {
  final cfi = document.currentCfi;
  if (cfi != null) {
    final page = fakeCfiToIndex(cfi);
    if (page != null && page < pageCount) return page;
  }
  final fraction = document.readingProgress;
  if (fraction <= 0) return 0;
  if (fraction >= 1) return pageCount - 1;
  return math.min(pageCount - 1, (fraction * pageCount).floor());
}

SourceBookmark? readerBookmarkOnPage(
  List<SourceBookmark> bookmarks,
  int page,
) {
  for (final bookmark in bookmarks) {
    if (bookmark.anchorSectionIndex == page ||
        fakeCfiToIndex(bookmark.cfi) == page) {
      return bookmark;
    }
  }
  return null;
}

/// Longer titles are not chapter names; the chrome drops them.
const _nativeChapterTitleMaxLength = 512;

String? readerChapterTitle(String label) {
  final title = label.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (title.isEmpty || title.length > _nativeChapterTitleMaxLength) return null;
  return title;
}

ReaderSelectionPosition? readerSelectionPositionForViewport(Rect? viewport) =>
    viewport == null
    ? null
    : ReaderSelectionPosition(
        left: viewport.left,
        top: viewport.top,
        right: viewport.right,
        bottom: viewport.bottom,
      );
