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

/// Each page-turn edge takes this fraction of the page width.
const readerLeftTapZoneEnd = 0.30;
const readerRightTapZoneStart = 1 - readerLeftTapZoneEnd;

ReaderTapAction readerTapActionFor({
  required double x,
  required double y,
  required bool chromeVisible,
  bool isComic = false,
  ReaderTapAxis axis = ReaderTapAxis.horizontal,
}) {
  if (chromeVisible && !isComic) return ReaderTapAction.toggleChrome;
  if (x <= readerLeftTapZoneEnd) return ReaderTapAction.leftPage;
  if (x >= readerRightTapZoneStart) return ReaderTapAction.rightPage;
  return ReaderTapAction.toggleChrome;
}

ReaderTapCommand readerTapCommandFor({
  required double x,
  required double y,
  required bool chromeVisible,
  bool isComic = false,
  ReaderTapAxis axis = ReaderTapAxis.horizontal,
}) {
  final action = readerTapActionFor(
    x: x,
    y: y,
    chromeVisible: chromeVisible,
    isComic: isComic,
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
  bool isComic = false,
}) {
  return !isComic && chromeVisible && !overlayVisible && !hasSelection;
}
