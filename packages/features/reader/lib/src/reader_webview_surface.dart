import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:reader_webview/reader_webview.dart';

import 'reader_surface.dart';

/// The WebView reader behind the [ReaderSurface] contract.
///
/// Forwards to the `BookReaderWebView` under [key] when it is mounted and
/// does nothing otherwise, which is what the screen did through the key.
class ReaderWebViewSurface implements ReaderSurface {
  const ReaderWebViewSurface(this.key);

  final GlobalKey<BookReaderWebViewState> key;

  BookReaderWebViewState? get _state => key.currentState;

  @override
  void goToCfi(String cfi) => _state?.goToCfi(cfi);

  @override
  void goToFraction(double fraction) => _state?.goToFraction(fraction);

  @override
  void goToHref(String href) => _state?.goToHref(href);

  @override
  void goToSectionIndex(int index) => _state?.goToSectionIndex(index);

  @override
  void goToSearchResult(String cfi) => _state?.goToSearchResult(cfi);

  @override
  void goToBookmark({
    required String cfi,
    required double progress,
    int? anchorSectionIndex,
    int? anchorSectionPage,
    int? anchorVersion,
  }) => _state?.goToBookmark(
    cfi: cfi,
    progress: progress,
    anchorSectionIndex: anchorSectionIndex,
    anchorSectionPage: anchorSectionPage,
    anchorVersion: anchorVersion,
  );

  @override
  void pageLeft() => _state?.pageLeft();

  @override
  void pageRight() => _state?.pageRight();

  @override
  void prevPage() => _state?.prevPage();

  @override
  void nextPage() => _state?.nextPage();

  @override
  void toggleBookmark() => _state?.toggleBookmark();

  @override
  Stream<ReaderSearchEvent>? searchBookStream(String query) =>
      _state?.searchBookStream(query);

  @override
  void clearSearch() => _state?.clearSearch();

  @override
  void clearSelection() => _state?.clearSelection();

  @override
  void clearSelectionAfterTextAction() =>
      _state?.clearSelectionAfterTextAction();

  @override
  Future<ReaderSelection?> currentTextSelection() =>
      _state?.currentTextSelection() ?? Future<ReaderSelection?>.value();

  @override
  void showSelectionHighlightPreview({
    required String cfiRange,
    required String color,
    double? opacity,
    String? mixBlendMode,
    double? verticalOffset,
  }) => _state?.showSelectionHighlightPreview(
    cfiRange: cfiRange,
    color: color,
    opacity: opacity,
    mixBlendMode: mixBlendMode,
    verticalOffset: verticalOffset,
  );

  @override
  void clearSelectionHighlightPreview() =>
      _state?.clearSelectionHighlightPreview();

  @override
  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required String color,
    double? opacity,
  }) => _state?.showImageAreaSelectionPreview(
    pageIndex: pageIndex,
    rect: rect,
    color: color,
    opacity: opacity,
  );

  @override
  void clearImageAreaSelectionPreview({bool allowNextTap = false}) =>
      _state?.clearImageAreaSelectionPreview(allowNextTap: allowNextTap);

  @override
  void setImageAreaSelectionPreviewRetained(bool retained) =>
      _state?.setImageAreaSelectionPreviewRetained(retained);

  @override
  void setImageAreaSelectionControlsBounds(ReaderSelectionPosition bounds) =>
      _state?.setImageAreaSelectionControlsBounds(bounds);

  @override
  void clearImageAreaSelectionControlsBounds() =>
      _state?.clearImageAreaSelectionControlsBounds();

  @override
  Future<ImageProvider?> pageThumbnail(int index) async =>
      readerThumbnailImageFor(await _state?.pageThumbnail(index));

  /// Encoded previews above this size are dropped: the page shows a retry
  /// instead of holding a large bitmap in the drawer.
  static const maxThumbnailBytes = 96 * 1024;
}

/// The provider for a WebView preview, or null for a missing or oversized
/// one. `MemoryImage` keys the image cache by the bytes' identity, so
/// several areas on one page share one decoded entry.
ImageProvider? readerThumbnailImageFor(Uint8List? bytes) {
  if (bytes == null || bytes.length > ReaderWebViewSurface.maxThumbnailBytes) {
    return null;
  }
  return MemoryImage(bytes);
}
