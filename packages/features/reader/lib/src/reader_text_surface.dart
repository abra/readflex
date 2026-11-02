import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:pagecraft/article.dart';

import 'reader_search_event.dart';
import 'reader_selection.dart';
import 'reader_surface.dart';

/// What the text body hands the surface while a reflowable book is open.
class ReaderTextSession {
  const ReaderTextSession({
    required this.controller,
    required this.source,
    required this.onToggleBookmark,
    required this.onSearchMark,
    required this.onSelectionPreview,
    required this.currentSelection,
    required this.chapterTitleOf,
    this.locale = 'en',
  });

  final TextPagesController controller;
  final TextBookSource source;

  /// Adds or removes the bookmark of the page on screen.
  final void Function() onToggleBookmark;

  /// The search hit to mark, or null to clear the mark.
  final void Function(String? cfi) onSearchMark;

  /// Tints the selection with a highlight colour while the reader picks
  /// one; null clears the tint.
  final void Function(String? cfiRange, Color? color) onSelectionPreview;

  /// The selection as text actions take it, or null.
  final ReaderSelection? Function() currentSelection;

  /// The chapter title search results of a section show.
  final String? Function(int section) chapterTitleOf;

  /// The book's language, for search case folding.
  final String locale;
}

/// The text engine (`package:pagecraft`) behind the [ReaderSurface] contract,
/// for EPUB, FB2 and MOBI books.
///
/// Navigation reaches the session's `TextPagesController`; search runs
/// `searchTextBook` and reports hits with excerpts and chapter titles; selection commands go to the page view through the
/// controller. Image-area commands are no-ops and pages have no
/// thumbnails. Without a session commands are dropped and queries answer
/// null.
class ReaderTextSurface implements ReaderSurface {
  ReaderTextSession? _session;

  bool get isAttached => _session != null;

  void attach(ReaderTextSession session) {
    _session = session;
  }

  /// Forgets [session]; a session attached later stays.
  void detach(ReaderTextSession session) {
    if (identical(_session, session)) _session = null;
  }

  TextPagesController? get _controller => _session?.controller;

  @override
  void goToCfi(String cfi) {
    unawaited(_controller?.goToCfi(cfi));
  }

  @override
  void goToFraction(double fraction) {
    unawaited(_controller?.goToFraction(fraction));
  }

  @override
  void goToHref(String href) {
    if (href.isEmpty) return;
    unawaited(_controller?.goToHref(href));
  }

  @override
  void goToSectionIndex(int index) {
    final session = _session;
    if (session == null || index < 0 || index >= session.source.sectionCount) {
      return;
    }
    unawaited(session.controller.goToSection(index));
  }

  @override
  void goToSearchResult(String cfi) {
    final session = _session;
    if (session == null) return;
    unawaited(session.controller.goToCfi(cfi));
    session.onSearchMark(cfi);
  }

  /// A bookmark with a precise anchor (version 2 and later) finds its own
  /// word in any layout; older ones open at their CFI, or their progress
  /// when it no longer resolves.
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
    unawaited(() async {
      if (await controller.goToCfi(cfi)) return;
      await controller.goToFraction(progress);
    }());
  }

  @override
  void pageLeft() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.rtl ? controller.next() : controller.previous());
  }

  @override
  void pageRight() {
    final controller = _controller;
    if (controller == null) return;
    unawaited(controller.rtl ? controller.previous() : controller.next());
  }

  @override
  void prevPage() {
    unawaited(_controller?.previous());
  }

  @override
  void nextPage() {
    unawaited(_controller?.next());
  }

  @override
  void toggleBookmark() {
    _session?.onToggleBookmark();
  }

  @override
  Stream<ReaderSearchEvent>? searchBookStream(String query) {
    final session = _session;
    if (session == null) return null;
    return readerSearchEvents(
      searchTextBook(session.source, query, locale: session.locale),
      chapterTitleOf: session.chapterTitleOf,
    );
  }

  @override
  void clearSearch() {
    _session?.onSearchMark(null);
  }

  @override
  void clearSelection() {
    _controller?.clearSelection();
  }

  @override
  void clearSelectionAfterTextAction() {
    _controller?.clearSelection();
  }

  @override
  Future<ReaderSelection?> currentTextSelection() =>
      Future<ReaderSelection?>.value(_session?.currentSelection());

  @override
  void showSelectionHighlightPreview({
    required String cfiRange,
    required Color color,
    required double opacity,
  }) {
    _session?.onSelectionPreview(cfiRange, color.withValues(alpha: opacity));
  }

  @override
  void clearSelectionHighlightPreview() {
    _session?.onSelectionPreview(null, null);
  }

  @override
  void showImageAreaSelectionPreview({
    required int pageIndex,
    required ReaderImageAreaRect rect,
    required Color color,
    required double opacity,
  }) {}

  @override
  void clearImageAreaSelectionPreview() {}

  @override
  void setImageAreaSelectionPreviewRetained(bool retained) {}

  @override
  Future<ImageProvider?> pageThumbnail(int index) =>
      Future<ImageProvider?>.value();
}

/// pagecraft's search events as the reader's: results in batches with the
/// chapter title of their section, progress, done, or an error.
Stream<ReaderSearchEvent> readerSearchEvents(
  Stream<TextSearchEvent> events, {
  required String? Function(int section) chapterTitleOf,
}) async* {
  try {
    await for (final event in events) {
      switch (event) {
        case TextSearchResults(:final section, :final hits):
          final title = chapterTitleOf(section);
          yield ReaderSearchResults(
            requestId: 0,
            results: [
              for (final hit in hits)
                ReaderSearchResult(
                  cfi: hit.cfi,
                  excerpt: ReaderSearchExcerpt(
                    pre: hit.pre,
                    match: hit.match,
                    post: hit.post,
                  ),
                  // An article's hit names the heading it is under.
                  chapterTitle: hit is ArticleSearchHit
                      ? hit.chapterTitle
                      : title,
                ),
            ],
          );
        case TextSearchProgress(:final fraction):
          yield ReaderSearchProgress(requestId: 0, progress: fraction);
        case TextSearchDone():
          yield const ReaderSearchDone(requestId: 0);
      }
    }
  } catch (error) {
    yield ReaderSearchError(requestId: 0, message: '$error');
  }
}

/// The selection payload the reader's text actions take, from pagecraft's
/// [details].
ReaderSelection readerSelectionFromDetails(
  TextSelectionDetails details, {
  ReaderSelectionPosition? position,
}) => ReaderSelection(
  text: details.text,
  normalizedText: details.normalizedText,
  selectionKind: details.kind.wireName,
  contextText: details.contextText,
  markedContextText: details.markedContextText,
  normalizedMarkedContextText: details.normalizedMarkedContextText,
  cfiRange: details.cfi,
  normalizedCfiRange: details.normalizedCfi,
  position: position,
  highlightMerge: switch (details.highlightMerge) {
    null => null,
    final merge => ReaderHighlightMerge(
      cfiRange: merge.cfi,
      text: merge.text,
      highlightIds: merge.highlightIds,
    ),
  },
);
