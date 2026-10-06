import 'reader_ui_cubit.dart';

/// What system Back (or an edge swipe) dismisses next, topmost first.
///
/// Modal sheets (appearance, note) are routes of their own and are popped by
/// the navigator before the reader is consulted, so they are not listed.
enum ReaderBackTarget {
  searchPanel,
  tocDrawer,
  highlightPopup,
  searchNavigation,

  /// Nothing is layered over the page; Back leaves the reader.
  route,
}

ReaderBackTarget readerBackTargetFor({
  required ReaderOverlay overlay,
  required bool highlightPopupVisible,
  required bool searchNavigating,
}) {
  if (overlay == ReaderOverlay.search) return ReaderBackTarget.searchPanel;
  if (overlay == ReaderOverlay.toc) return ReaderBackTarget.tocDrawer;
  if (highlightPopupVisible) return ReaderBackTarget.highlightPopup;
  if (searchNavigating) return ReaderBackTarget.searchNavigation;
  return ReaderBackTarget.route;
}
