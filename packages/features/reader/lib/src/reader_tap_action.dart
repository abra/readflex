enum ReaderTapAction {
  leftPage,
  rightPage,
  toggleChrome,
}

enum ReaderTapCommand {
  physicalLeftPage,
  physicalRightPage,
  previousPage,
  nextPage,
  toggleChrome,
}

enum ReaderTapAxis {
  horizontal,
  vertical,
}

const readerLeftTapZoneEnd = 0.30;
const readerRightTapZoneStart = 0.70;
const readerTopTapZoneEnd = 0.20;
const readerBottomTapZoneStart = 0.50;

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

ReaderTapCommand readerTapCommandFor({
  required double x,
  required double y,
  required bool chromeVisible,
  ReaderTapAxis axis = ReaderTapAxis.horizontal,
}) {
  final action = readerTapActionFor(
    x: x,
    y: y,
    chromeVisible: chromeVisible,
    axis: axis,
  );
  return switch ((axis, action)) {
    (_, ReaderTapAction.toggleChrome) => ReaderTapCommand.toggleChrome,
    (ReaderTapAxis.vertical, ReaderTapAction.leftPage) =>
      ReaderTapCommand.previousPage,
    (ReaderTapAxis.vertical, ReaderTapAction.rightPage) =>
      ReaderTapCommand.nextPage,
    (ReaderTapAxis.horizontal, ReaderTapAction.leftPage) =>
      ReaderTapCommand.physicalLeftPage,
    (ReaderTapAxis.horizontal, ReaderTapAction.rightPage) =>
      ReaderTapCommand.physicalRightPage,
  };
}

bool shouldBlockReaderPageInput({
  required bool chromeVisible,
  required bool overlayVisible,
  required bool hasSelection,
}) {
  return chromeVisible && !overlayVisible && !hasSelection;
}
