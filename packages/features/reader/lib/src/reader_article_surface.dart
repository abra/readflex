import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:pagecraft/article.dart';

import 'reader_search_event.dart';
import 'reader_selection.dart';
import 'reader_surface.dart';
import 'reader_text_surface.dart' show readerSearchEvents;

/// What the article body hands the surface while an article is open.
class ReaderArticleSession {
  const ReaderArticleSession({
    required this.controller,
    required this.index,
    required this.onToggleBookmark,
    required this.onSearchHits,
    required this.onSearchMark,
    required this.onSelectionPreview,
    required this.currentSelection,
  });

  final TextScrollController controller;

  /// The article as laid out now (its document, sentences and
  /// headings), or null before it is.
  final ArticleIndex? Function() index;

  /// Adds or removes the bookmark of the sentence read.
  final void Function() onToggleBookmark;

  /// Hits of the search running, to tint, or null when it is cleared.
  final void Function(List<ArticleSearchHit>? hits) onSearchHits;

  /// The search hit to mark as the active one, or null for none.
  final void Function(String? cfi) onSearchMark;

  /// Tints the selection with a highlight colour while the reader picks
  /// one; null clears the tint.
  final void Function(String? cfiRange, Color? color) onSelectionPreview;

  /// The selection as text actions take it, or null.
  final ReaderSelection? Function() currentSelection;
}

/// An article drawn by the native text engine (`package:pagecraft`) behind
/// the [ReaderSurface] contract, as one scrolling column.
///
/// Positions, bookmarks and highlights are article anchors
/// (`readflex-html-position:`): a sentence's opens at the middle of the
/// view, a highlight's text in the middle, an `#id` at the top. Search
/// runs over the article's sentences and tints every hit, the active one
/// apart. Articles have no pages to turn, image areas or thumbnails.
/// Without a session commands are dropped and queries answer null.
class ReaderArticleSurface implements ReaderSurface {
  ReaderArticleSession? _session;

  bool get isAttached => _session != null;

  void attach(ReaderArticleSession session) {
    _session = session;
  }

  /// Forgets [session]; a session attached later stays.
  void detach(ReaderArticleSession session) {
    if (identical(_session, session)) _session = null;
  }

  /// Opens anchor [cfi]; false when it names nothing in the article.
  bool _goToAnchor(String cfi) {
    final session = _session;
    final anchor = ArticleAnchor.decode(cfi);
    final doc = session?.index()?.document;
    if (session == null || anchor == null || doc == null) return false;
    final controller = session.controller;
    if (anchor.isRange) {
      final range = anchor.rangeIn(doc);
      if (range != null) {
        unawaited(controller.goToRange(range));
        return true;
      }
    }
    final element = anchor.elementIn(doc);
    if (element == null) return false;
    unawaited(controller.goToPoint(TextPoint(element, 0)));
    return true;
  }

  @override
  void goToCfi(String cfi) {
    if (_goToAnchor(cfi)) _session?.onSearchMark(null);
  }

  @override
  void goToFraction(double fraction) {
    unawaited(_session?.controller.goToFraction(fraction));
  }

  /// `#id`: the element at the top of the view.
  @override
  void goToHref(String href) {
    final session = _session;
    final doc = session?.index()?.document;
    final hash = href.indexOf('#');
    if (session == null || doc == null || hash < 0) return;
    if (hash == href.length - 1) return;
    final element = doc.elementIndexById(
      Uri.decodeComponent(href.substring(hash + 1)),
    );
    if (element == ContentDocument.none) return;
    unawaited(
      session.controller.goToPoint(TextPoint(element, 0), center: false),
    );
  }

  /// One section: its start.
  @override
  void goToSectionIndex(int index) {
    if (index == 0) unawaited(_session?.controller.goToFraction(0));
  }

  @override
  void goToSearchResult(String cfi) {
    if (_goToAnchor(cfi)) _session?.onSearchMark(cfi);
  }

  /// A bookmark opens at its sentence, or at its progress when the
  /// sentence is gone.
  @override
  void goToBookmark({
    required String cfi,
    required double progress,
    int? anchorSectionIndex,
    int? anchorSectionPage,
    int? anchorVersion,
  }) {
    if (cfi.isNotEmpty && _goToAnchor(cfi)) return;
    unawaited(_session?.controller.goToFraction(progress));
  }

  // Articles scroll: there are no pages to turn.

  @override
  void pageLeft() {}

  @override
  void pageRight() {}

  @override
  void prevPage() {}

  @override
  void nextPage() {}

  @override
  void toggleBookmark() {
    _session?.onToggleBookmark();
  }

  /// Hits keep their headings as chapter titles.
  @override
  Stream<ReaderSearchEvent>? searchBookStream(String query) {
    final session = _session;
    final index = session?.index();
    if (session == null || index == null) return null;
    session
      ..onSearchHits(const [])
      ..onSearchMark(null);
    final hits = <ArticleSearchHit>[];
    return readerSearchEvents(
      searchArticle(index, query).map((event) {
        if (event is TextSearchResults) {
          hits.addAll(event.hits.cast<ArticleSearchHit>());
          session.onSearchHits(List.unmodifiable(hits));
        }
        return event;
      }),
      chapterTitleOf: (_) => null,
    );
  }

  @override
  void clearSearch() {
    _session
      ?..onSearchHits(null)
      ..onSearchMark(null);
  }

  @override
  void clearSelection() {
    _session?.controller.clearSelection();
  }

  @override
  void clearSelectionAfterTextAction() {
    _session?.controller.clearSelection();
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
