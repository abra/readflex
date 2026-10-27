import 'package:flutter/painting.dart';
import 'package:reader_webview/reader_webview.dart';

/// Commands the reader screen sends to whatever draws a book.
///
/// Extracted from what the screen asks of `BookReaderWebViewState`, so a
/// native engine can take the WebView's place behind the same calls. Every
/// command is safe before the surface is mounted: navigation and previews
/// are dropped, queries answer null. The screen's events (positions,
/// selections, taps, annotations) travel the other way as widget callbacks
/// of the surface widget, which stay where the surface is built.
///
/// Articles keep their own WebView and are not behind this contract yet.
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

  void showSelectionHighlightPreview({
    required String cfiRange,
    required String color,
    double? opacity,
    String? mixBlendMode,
    double? verticalOffset,
  });

  void clearSelectionHighlightPreview();

  // Image areas (comics, PDF).

  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required String color,
    double? opacity,
  });

  void clearImageAreaSelectionPreview({bool allowNextTap = false});

  void setImageAreaSelectionPreviewRetained(bool retained);

  void setImageAreaSelectionControlsBounds(ReaderSelectionPosition bounds);

  void clearImageAreaSelectionControlsBounds();

  // Previews.

  /// A small preview of a page for Contents lists, or null when none can
  /// be made. The framework's image cache holds the pixels.
  Future<ImageProvider?> pageThumbnail(int index);
}
