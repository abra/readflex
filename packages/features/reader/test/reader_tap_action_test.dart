import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_tap_action.dart';

void main() {
  group('readerTapActionFor', () {
    test('uses physical left and right tap zones when chrome is hidden', () {
      expect(
        readerTapActionFor(x: 0.10, y: 0.50, chromeVisible: false),
        ReaderTapAction.leftPage,
      );
      expect(
        readerTapActionFor(x: 0.50, y: 0.50, chromeVisible: false),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(x: 0.90, y: 0.50, chromeVisible: false),
        ReaderTapAction.rightPage,
      );
    });

    test('hides chrome instead of turning pages when chrome is visible', () {
      expect(
        readerTapActionFor(x: 0.10, y: 0.50, chromeVisible: true),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(x: 0.90, y: 0.50, chromeVisible: true),
        ReaderTapAction.toggleChrome,
      );
    });

    test('keeps zone boundaries inclusive', () {
      expect(
        readerTapActionFor(
          x: readerLeftTapZoneEnd,
          y: 0.50,
          chromeVisible: false,
        ),
        ReaderTapAction.leftPage,
      );
      expect(
        readerTapActionFor(
          x: readerRightTapZoneStart,
          y: 0.50,
          chromeVisible: false,
        ),
        ReaderTapAction.rightPage,
      );
    });

    test('uses physical top and bottom tap zones for vertical page turns', () {
      expect(
        readerTapActionFor(
          x: 0.10,
          y: 0.50,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(
          x: 0.90,
          y: 0.50,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(
          x: 0.10,
          y: 0.10,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(
          x: 0.90,
          y: 0.90,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(
          x: 0.50,
          y: 0.10,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapAction.leftPage,
      );
      expect(
        readerTapActionFor(
          x: 0.50,
          y: 0.90,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapAction.rightPage,
      );
    });

    test('maps vertical taps to logical previous and next commands', () {
      expect(
        readerTapCommandFor(x: 0.50, y: 0.10, chromeVisible: false),
        ReaderTapCommand.toggleChrome,
      );
      expect(
        readerTapCommandFor(
          x: 0.10,
          y: 0.50,
          chromeVisible: false,
        ),
        ReaderTapCommand.physicalLeftPage,
      );
      expect(
        readerTapCommandFor(
          x: 0.90,
          y: 0.50,
          chromeVisible: false,
        ),
        ReaderTapCommand.physicalRightPage,
      );
      expect(
        readerTapCommandFor(
          x: 0.50,
          y: 0.10,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapCommand.previousPage,
      );
      expect(
        readerTapCommandFor(
          x: 0.50,
          y: 0.90,
          chromeVisible: false,
          axis: ReaderTapAxis.vertical,
        ),
        ReaderTapCommand.nextPage,
      );
    });

    test('blocks page input only while reader chrome is visible', () {
      expect(
        shouldBlockReaderPageInput(
          chromeVisible: true,
          overlayVisible: false,
          hasSelection: false,
        ),
        isTrue,
      );
      expect(
        shouldBlockReaderPageInput(
          chromeVisible: false,
          overlayVisible: false,
          hasSelection: false,
        ),
        isFalse,
      );
      expect(
        shouldBlockReaderPageInput(
          chromeVisible: true,
          overlayVisible: true,
          hasSelection: false,
        ),
        isFalse,
      );
      expect(
        shouldBlockReaderPageInput(
          chromeVisible: true,
          overlayVisible: false,
          hasSelection: true,
        ),
        isFalse,
      );
    });
  });
}
