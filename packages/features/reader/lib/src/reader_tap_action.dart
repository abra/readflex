enum ReaderTapAction {
  leftPage,
  rightPage,
  toggleChrome,
}

const readerLeftTapZoneEnd = 0.28;
const readerRightTapZoneStart = 0.62;

ReaderTapAction readerTapActionFor({
  required double x,
  required bool chromeVisible,
}) {
  if (chromeVisible) return ReaderTapAction.toggleChrome;
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
