enum ReaderTapAction {
  leftPage,
  rightPage,
  toggleChrome,
}

enum ReaderTapAxis {
  horizontal,
  vertical,
}

const readerLeftTapZoneEnd = 0.28;
const readerRightTapZoneStart = 0.62;
const readerTopTapZoneEnd = 0.28;
const readerBottomTapZoneStart = 0.62;

ReaderTapAction readerTapActionFor({
  required double x,
  required double y,
  required bool chromeVisible,
  ReaderTapAxis axis = ReaderTapAxis.horizontal,
}) {
  if (chromeVisible) return ReaderTapAction.toggleChrome;
  if (axis == ReaderTapAxis.vertical) {
    if (x <= readerLeftTapZoneEnd || x >= readerRightTapZoneStart) {
      return ReaderTapAction.toggleChrome;
    }
    if (y <= readerTopTapZoneEnd) return ReaderTapAction.leftPage;
    if (y >= readerBottomTapZoneStart) return ReaderTapAction.rightPage;
    return ReaderTapAction.toggleChrome;
  }
  if (x <= readerLeftTapZoneEnd) return ReaderTapAction.leftPage;
  if (x >= readerRightTapZoneStart) return ReaderTapAction.rightPage;
  return ReaderTapAction.toggleChrome;
}

bool shouldBlockReaderPageInput({
  required bool chromeVisible,
  required bool overlayVisible,
  required bool hasSelection,
}) {
  return chromeVisible && !overlayVisible && !hasSelection;
}
