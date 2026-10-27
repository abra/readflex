import 'package:flutter/painting.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:vellum/vellum.dart';

import 'reader_surface.dart';

/// What the comic body hands the surface while a comic is open.
class ReaderComicSession {
  const ReaderComicSession({
    required this.controller,
    required this.book,
    required this.draft,
    required this.onToggleBookmark,
  });

  final FixedPagesController controller;
  final ComicBook book;
  final ComicImageAreaDraft draft;

  /// Adds or removes the bookmark of the page on screen; the body knows
  /// the page's bookmark state and reports the change to the bloc.
  final VoidCallback onToggleBookmark;
}

/// The native comic engine behind the [ReaderSurface] contract.
///
/// Commands reach the session's `FixedPagesController` and image-area draft;
/// without a session (before the archive opens, after it closes) they are
/// dropped and queries answer null, as the WebView surface does before it
/// mounts. Comics have no text, so search and text-selection commands are
/// no-ops, and control bounds are not needed: Flutter hit-tests the app's
/// chrome before the page.
class ReaderComicSurface implements ReaderSurface {
  ReaderComicSession? _session;

  bool get isAttached => _session != null;

  void attach(ReaderComicSession session) {
    _session = session;
  }

  /// Forgets [session]; a session attached later stays.
  void detach(ReaderComicSession session) {
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

  @override
  void goToHref(String href) {
    final session = _session;
    if (session == null) return;
    final page = session.book.resolveHref(href);
    if (page != null) session.controller.goToPage(page.index);
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
    // Comics have nothing to search.
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
    // The page anchor is exact for a comic; the CFI names the same page;
    // the fraction is the fallback for rows saved without either.
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
  Stream<ReaderSearchEvent>? searchBookStream(String query) => null;

  @override
  void clearSearch() {}

  @override
  void clearSelection() {
    _clearDraft();
  }

  @override
  void clearSelectionAfterTextAction() {
    _clearDraft();
  }

  @override
  Future<ReaderSelection?> currentTextSelection() =>
      Future<ReaderSelection?>.value();

  @override
  void showSelectionHighlightPreview({
    required String cfiRange,
    required String color,
    double? opacity,
    String? mixBlendMode,
    double? verticalOffset,
  }) {}

  @override
  void clearSelectionHighlightPreview() {}

  @override
  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required String color,
    double? opacity,
  }) {
    final draft = _session?.draft;
    if (draft == null || draft.page != pageIndex) return;
    draft.setStyle(color: parseCssHexColor(color), opacity: opacity);
  }

  @override
  void clearImageAreaSelectionPreview({bool allowNextTap = false}) {
    _clearDraft();
  }

  @override
  void setImageAreaSelectionPreviewRetained(bool retained) {
    _session?.draft.retain(retained);
  }

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
      ComicPageImage(
        source: session.book,
        pageIndex: index,
        targetWidth: ComicPageImage.thumbnailWidth,
        maxBytes: ComicPageImage.thumbnailMaxBytes,
      ),
    );
  }

  void _clearDraft() {
    final session = _session;
    if (session == null) return;
    session.draft.clear();
    session.controller.lockInput(false);
  }
}

/// A CSS hex colour (`#rgb`, `#rrggbb`, `#rrggbbaa`) as a [Color], or null
/// for anything else. The reader hands the engine the same strings it
/// hands the WebView's CSS.
Color? parseCssHexColor(String value) {
  final hex = value.trim();
  if (!hex.startsWith('#')) return null;
  final digits = hex.substring(1);
  final expanded = switch (digits.length) {
    3 => digits.split('').map((d) => '$d$d').join(),
    6 || 8 => digits,
    _ => null,
  };
  if (expanded == null) return null;
  final parsed = int.tryParse(expanded, radix: 16);
  if (parsed == null) return null;
  if (expanded.length == 6) return Color(0xFF000000 | parsed);
  // #rrggbbaa: alpha is last in CSS, first in Flutter.
  return Color(((parsed & 0xFF) << 24) | (parsed >> 8));
}
