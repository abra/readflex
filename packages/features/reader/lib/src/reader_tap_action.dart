enum ReaderTapAction {
  previousPage,
  nextPage,
  toggleChrome,
}

const readerPreviousTapZoneEnd = 0.28;
const readerNextTapZoneStart = 0.62;

ReaderTapAction readerTapActionFor({
  required double x,
  required bool chromeVisible,
  bool rtl = false,
}) {
  if (chromeVisible) return ReaderTapAction.toggleChrome;
  if (x <= readerPreviousTapZoneEnd) {
    return rtl ? ReaderTapAction.nextPage : ReaderTapAction.previousPage;
  }
  if (x >= readerNextTapZoneStart) {
    return rtl ? ReaderTapAction.previousPage : ReaderTapAction.nextPage;
  }
  return ReaderTapAction.toggleChrome;
}
