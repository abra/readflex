import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:pagecraft/djvu.dart';

import 'reader_search_event.dart';
import 'reader_selection.dart';
import 'reader_surface.dart';

/// What the DjVu body hands the surface while a DjVu is open.
class ReaderDjvuSession {
  const ReaderDjvuSession({
    required this.controller,
    required this.book,
    required this.layers,
    required this.selection,
    required this.onToggleBookmark,
    required this.onSearchMark,
    required this.draft,
  });

  final FixedPagesController controller;
  final DjvuBook book;
  final DjvuTextLayerCache layers;
  final DjvuTextSelection selection;
  final ComicImageAreaDraft draft;

  /// Adds or removes the bookmark of the page on screen.
  final VoidCallback onToggleBookmark;

  /// The search hit to mark on a page, or null to clear the mark.
  final void Function(int page, DjvuTextRange? range) onSearchMark;
}

/// The native DjVu engine behind the [ReaderSurface] contract.
///
/// Navigation reaches the session's `FixedPagesController`; search runs
/// through `searchDjvuBook` over the session's text layers and reports
/// hits as pagecraft CFIs with excerpts around the match; selection
/// commands drive `DjvuTextSelection`. Pages without a hidden text layer
/// use image-area drafts. Without a session commands are dropped and queries
/// answer null.
class ReaderDjvuSurface implements ReaderSurface {
  ReaderDjvuSession? _session;

  bool get isAttached => _session != null;

  void attach(ReaderDjvuSession session) {
    _session = session;
  }

  /// Forgets [session]; a session attached later stays.
  void detach(ReaderDjvuSession session) {
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

  /// The document resolves outline targets to page indices; absent or external
  /// targets leave the current page unchanged.
  @override
  void goToHref(String href) {
    final session = _session;
    if (session == null || href.isEmpty) return;
    final page = session.book.resolveHref(href);
    if (page != null) session.controller.goToPage(page);
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
    final anchor = djvuTextAnchorFromCfi(cfi);
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
    ReaderDjvuSession session,
    String query,
  ) async* {
    try {
      await for (final hits in searchDjvuBook(session.book, query)) {
        if (!identical(_session, session)) return;
        yield ReaderSearchResults(
          requestId: 0,
          results: [
            for (final hit in hits)
              ReaderSearchResult(
                cfi: djvuTextCfi(hit.page, hit.range),
                excerpt: ReaderSearchExcerpt(
                  pre: hit.match.pre,
                  match: hit.match.match,
                  post: hit.match.post,
                ),
              ),
          ],
        );
      }
      if (identical(_session, session)) {
        yield const ReaderSearchDone(requestId: 0);
      }
    } catch (error) {
      if (identical(_session, session)) {
        yield ReaderSearchError(requestId: 0, message: '$error');
      }
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

  /// The selection, from the page's text layer when it is loaded.
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
    return Future.value(readerSelectionFromDjvuLayer(layer, range));
  }

  @override
  void showSelectionHighlightPreview({
    required String cfiRange,
    required Color color,
    required double opacity,
  }) {
    final selection = _session?.selection;
    if (selection == null) return;
    final anchor = djvuTextAnchorFromCfi(cfiRange);
    if (anchor != null && anchor.pageIndex != selection.page) return;
    selection.setColor(color.withValues(alpha: opacity));
  }

  @override
  void clearSelectionHighlightPreview() {
    final selection = _session?.selection;
    if (selection == null) return;
    selection.setColor(DjvuTextSelection.defaultColor);
  }

  @override
  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required Color color,
    required double opacity,
  }) {
    final draft = _session?.draft;
    if (draft == null || draft.page != pageIndex) return;
    draft.setStyle(color: color, opacity: opacity);
  }

  @override
  void clearImageAreaSelectionPreview() {
    _session?.draft.clear();
    _controller?.lockInput(false);
  }

  @override
  void setImageAreaSelectionPreviewRetained(bool retained) {
    _session?.draft.retain(retained);
  }

  @override
  Future<ImageProvider?> pageThumbnail(int index) {
    final session = _session;
    if (session == null || index < 0 || index >= session.book.pageCount) {
      return Future<ImageProvider?>.value();
    }
    return Future<ImageProvider?>.value(
      DjvuPages(session.book).pageThumbnail(index),
    );
  }

  void _clearSelection() {
    final session = _session;
    if (session == null) return;
    session.selection.clear();
    session.draft.clear();
    session.controller.lockInput(false);
  }
}

/// The selection payload the reader's text actions take, built from a
/// page's text layer: the exact text, the sentence around it, and pagecraft's
/// range CFI.
ReaderSelection readerSelectionFromDjvuLayer(
  DjvuTextLayer layer,
  DjvuTextRange range, {
  ReaderSelectionPosition? position,
}) {
  final text = layer.textOf(range);
  final context = layer.contextOf(range);
  final cfi = djvuTextCfi(layer.pageIndex, range);
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
