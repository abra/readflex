import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_tap_action.dart';

void main() {
  group('readerTapActionFor', () {
    test('uses physical left and right tap zones when chrome is hidden', () {
      expect(
        readerTapActionFor(x: 0.10, chromeVisible: false),
        ReaderTapAction.leftPage,
      );
      expect(
        readerTapActionFor(x: 0.50, chromeVisible: false),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(x: 0.90, chromeVisible: false),
        ReaderTapAction.rightPage,
      );
    });

    test('hides chrome instead of turning pages when chrome is visible', () {
      expect(
        readerTapActionFor(x: 0.10, chromeVisible: true),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(x: 0.90, chromeVisible: true),
        ReaderTapAction.toggleChrome,
      );
    });

    test('keeps zone boundaries inclusive', () {
      expect(
        readerTapActionFor(x: readerLeftTapZoneEnd, chromeVisible: false),
        ReaderTapAction.leftPage,
      );
      expect(
        readerTapActionFor(x: readerRightTapZoneStart, chromeVisible: false),
        ReaderTapAction.rightPage,
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
