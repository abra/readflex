import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_tap_action.dart';

void main() {
  group('readerTapActionFor', () {
    test('uses left and right tap zones when chrome is hidden', () {
      expect(
        readerTapActionFor(x: 0.10, chromeVisible: false),
        ReaderTapAction.previousPage,
      );
      expect(
        readerTapActionFor(x: 0.50, chromeVisible: false),
        ReaderTapAction.toggleChrome,
      );
      expect(
        readerTapActionFor(x: 0.90, chromeVisible: false),
        ReaderTapAction.nextPage,
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
        readerTapActionFor(x: readerPreviousTapZoneEnd, chromeVisible: false),
        ReaderTapAction.previousPage,
      );
      expect(
        readerTapActionFor(x: readerNextTapZoneStart, chromeVisible: false),
        ReaderTapAction.nextPage,
      );
    });

    test('mirrors side zones for rtl page progression', () {
      expect(
        readerTapActionFor(x: 0.10, chromeVisible: false, rtl: true),
        ReaderTapAction.nextPage,
      );
      expect(
        readerTapActionFor(x: 0.90, chromeVisible: false, rtl: true),
        ReaderTapAction.previousPage,
      );
    });
  });
}
