import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:vellum/vellum.dart';

import 'reader_comic_surface.dart' show parseCssHexColor;
import 'reader_surface.dart';

/// What the PDF body hands the surface while a PDF is open.
class ReaderPdfSession {
  const ReaderPdfSession({
    required this.controller,
    required this.book,
    required this.layers,
    required this.selection,
    required this.onToggleBookmark,
    required this.onSearchMark,
  });

  final FixedPagesController controller;
  final PdfBook book;
  final PdfTextLayerCache layers;
  final PdfTextSelection selection;

  /// Adds or removes the bookmark of the page on screen.
  final VoidCallback onToggleBookmark;

  /// The search hit to mark on a page, or null to clear the mark.
  final void Function(int page, PdfTextRange? range) onSearchMark;
}

/// The native PDF engine behind the [ReaderSurface] contract.
///
/// Navigation reaches the session's `FixedPagesController`; search runs
/// through `searchPdfBook` over the session's text layers and reports
/// hits as vellum CFIs with the WebView's excerpt shape; selection
/// commands drive the `PdfTextSelection`. Image-area commands are
/// no-ops: PDF pages carry text highlights. Without a session commands
/// are dropped and queries answer null.
class ReaderPdfSurface implements ReaderSurface {
  ReaderPdfSession? _session;

  bool get isAttached => _session != null;

  void attach(ReaderPdfSession session) {
    _session = session;
  }

  /// Forgets [session]; a session attached later stays.
  void detach(ReaderPdfSession session) {
    if (identical(_session, session)) _session = null;
  }

  FixedPagesController? get _controller => _session?.controller;

  @override
  void goToCfi(String cfi) {
    _controller?.goToCfi(cfi);
  }

  @override
  void goToFraction(double fraction) {
    _controller?.goToFraction(fraction);
  }

  /// Table-of-contents entries carry page CFIs; an entry without a page
  /// has an empty href and goes nowhere.
  @override
  void goToHref(String href) {
    if (href.isEmpty) return;
    _controller?.goToCfi(href);
  }

  @override
  void goToSectionIndex(int index) {
    final controller = _controller;
    if (controller == null || index < 0 || index >= controller.pageCount) {
      return;
    }
    controller.goToPage(index);
  }

  @override
  void goToSearchResult(String cfi) {
    final session = _session;
    if (session == null) return;
    final anchor = pdfTextAnchorFromCfi(cfi);
    if (anchor == null || anchor.pageIndex >= session.book.pageCount) return;
    session.controller.goToPage(anchor.pageIndex);
    session.onSearchMark(anchor.pageIndex, anchor.range);
  }

  @override
  void goToBookmark({
    required String cfi,
    required double progress,
    int? anchorSectionIndex,
    int? anchorSectionPage,
    int? anchorVersion,
  }) {
    final controller = _controller;
    if (controller == null) return;
    if (anchorSectionIndex != null &&
        anchorSectionIndex >= 0 &&
        anchorSectionIndex < controller.pageCount) {
      controller.goToPage(anchorSectionIndex);
      return;
    }
    if (controller.goToCfi(cfi)) return;
    controller.goToFraction(progress);
  }

  @override
  void pageLeft() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.rtl) {
      controller.next();
    } else {
      controller.previous();
    }
  }

  @override
  void pageRight() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.rtl) {
      controller.previous();
    } else {
      controller.next();
    }
  }

  @override
  void prevPage() {
    _controller?.previous();
  }

  @override
  void nextPage() {
    _controller?.next();
  }

  @override
  void toggleBookmark() {
    _session?.onToggleBookmark();
  }

  @override
  Stream<ReaderSearchEvent>? searchBookStream(String query) {
    final session = _session;
    if (session == null) return null;
    return _search(session, query);
  }

  Stream<ReaderSearchEvent> _search(
    ReaderPdfSession session,
    String query,
  ) async* {
    try {
      await for (final hits in searchPdfBook(
        session.book,
        query,
        cache: session.layers,
      )) {
        yield ReaderSearchResults(
          requestId: 0,
          results: [
            for (final hit in hits)
              ReaderSearchResult(
                cfi: pdfTextCfi(hit.page, hit.range),
                excerpt: ReaderSearchExcerpt(
                  pre: hit.match.pre,
                  match: hit.match.match,
                  post: hit.match.post,
                ),
              ),
          ],
        );
      }
      yield const ReaderSearchDone(requestId: 0);
    } catch (error) {
      yield ReaderSearchError(requestId: 0, message: '$error');
    }
  }

  @override
  void clearSearch() {
    final session = _session;
    if (session == null) return;
    session.onSearchMark(session.controller.page, null);
  }

  @override
  void clearSelection() {
    _clearSelection();
  }

  @override
  void clearSelectionAfterTextAction() {
    _clearSelection();
  }

  /// The selection as the WebView reported one, from the page's text layer
  /// when it is loaded.
  @override
  Future<ReaderSelection?> currentTextSelection() {
    final session = _session;
    final page = session?.selection.page;
    final range = session?.selection.range;
    if (session == null || page == null || range == null) {
      return Future<ReaderSelection?>.value();
    }
    final layer = session.layers.peek(page);
    if (layer == null) return Future<ReaderSelection?>.value();
    return Future.value(readerSelectionFromLayer(layer, range));
  }

  @override
  void showSelectionHighlightPreview({
    required String cfiRange,
    required String color,
    double? opacity,
    String? mixBlendMode,
    double? verticalOffset,
  }) {
    final selection = _session?.selection;
    if (selection == null) return;
    final anchor = pdfTextAnchorFromCfi(cfiRange);
    if (anchor != null && anchor.pageIndex != selection.page) return;
    final parsed = parseCssHexColor(color);
    if (parsed != null) {
      selection.setColor(parsed.withValues(alpha: opacity ?? parsed.a));
    }
  }

  @override
  void clearSelectionHighlightPreview() {
    final selection = _session?.selection;
    if (selection == null) return;
    selection.setColor(PdfTextSelection.defaultColor);
  }

  @override
  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required String color,
    double? opacity,
  }) {}

  @override
  void clearImageAreaSelectionPreview({bool allowNextTap = false}) {}

  @override
  void setImageAreaSelectionPreviewRetained(bool retained) {}

  @override
  void setImageAreaSelectionControlsBounds(ReaderSelectionPosition bounds) {}

  @override
  void clearImageAreaSelectionControlsBounds() {}

  @override
  Future<ImageProvider?> pageThumbnail(int index) {
    final session = _session;
    if (session == null || index < 0 || index >= session.book.pageCount) {
      return Future<ImageProvider?>.value();
    }
    return Future<ImageProvider?>.value(
      PdfPages(session.book).pageThumbnail(index),
    );
  }

  void _clearSelection() {
    final session = _session;
    if (session == null) return;
    session.selection.clear();
    session.controller.lockInput(false);
  }
}

/// The selection payload the reader's text actions take, built from a
/// page's text layer the way the WebView's selection bridge built it:
/// the exact text, the sentence around it, and vellum's range CFI.
ReaderSelection readerSelectionFromLayer(
  PdfTextLayer layer,
  PdfTextRange range, {
  ReaderSelectionPosition? position,
}) {
  final text = layer.textOf(range);
  final context = layer.contextOf(range);
  final cfi = pdfTextCfi(layer.pageIndex, range);
  return ReaderSelection(
    text: text,
    normalizedText: text,
    selectionKind: 'exact',
    contextText: context.contextText,
    markedContextText: context.markedContextText,
    normalizedMarkedContextText: context.markedContextText,
    cfiRange: cfi,
    normalizedCfiRange: cfi,
    position: position,
  );
}
