import 'reader_ui_cubit.dart';

/// What system Back (or an edge swipe) dismisses next, topmost first.
///
/// Modal sheets (appearance, note) are routes of their own and are popped by
/// the navigator before the reader is consulted, so they are not listed.
enum ReaderBackTarget {
  searchPanel,
  tocDrawer,
  imageSelection,
  highlightPopup,
  searchNavigation,

  /// Nothing is layered over the page; Back leaves the reader.
  route,
}

ReaderBackTarget readerBackTargetFor({
  required ReaderOverlay overlay,
  required bool highlightPopupVisible,
  required bool searchNavigating,
  bool imageSelectionVisible = false,
}) {
  if (overlay == ReaderOverlay.search) return ReaderBackTarget.searchPanel;
  if (overlay == ReaderOverlay.toc) return ReaderBackTarget.tocDrawer;
  if (imageSelectionVisible) return ReaderBackTarget.imageSelection;
  if (highlightPopupVisible) return ReaderBackTarget.highlightPopup;
  if (searchNavigating) return ReaderBackTarget.searchNavigation;
  return ReaderBackTarget.route;
}
