import 'package:flutter/painting.dart';

import 'reader_search_event.dart';
import 'reader_selection.dart';

/// Commands the reader screen sends to whatever draws a book or an article.
///
/// One implementation per kind of page: `ReaderTextSurface` (EPUB, FB2,
/// MOBI), `ReaderComicSurface`, `ReaderPdfSurface` and
/// `ReaderArticleSurface`, which scrolls. Every command is safe before the
/// surface is mounted: navigation and previews are dropped, queries answer
/// null. The screen's events (positions, selections, taps, annotations)
/// travel the other way as widget callbacks of the body that draws the
/// page.
abstract interface class ReaderSurface {
  // Navigation.

  void goToCfi(String cfi);

  void goToFraction(double fraction);

  void goToHref(String href);

  void goToSectionIndex(int index);

  void goToSearchResult(String cfi);

  void goToBookmark({
    required String cfi,
    required double progress,
    int? anchorSectionIndex,
    int? anchorSectionPage,
    int? anchorVersion,
  });

  void pageLeft();

  void pageRight();

  void prevPage();

  void nextPage();

  void toggleBookmark();

  // Search.

  /// Null while the document is not ready to be searched.
  Stream<ReaderSearchEvent>? searchBookStream(String query);

  void clearSearch();

  // Text selection.

  void clearSelection();

  void clearSelectionAfterTextAction();

  Future<ReaderSelection?> currentTextSelection();

  /// Paints the selection at [cfiRange] as a highlight of [color] at
  /// [opacity] would look, while the user picks a color.
  void showSelectionHighlightPreview({
    required String cfiRange,
    required Color color,
    required double opacity,
  });

  void clearSelectionHighlightPreview();

  // Image areas (comics, PDF).

  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required Color color,
    required double opacity,
  });

  void clearImageAreaSelectionPreview();

  void setImageAreaSelectionPreviewRetained(bool retained);

  // Previews.

  /// A small preview of a page for Contents lists, or null when none can
  /// be made. The framework's image cache holds the pixels.
  Future<ImageProvider?> pageThumbnail(int index);
}
