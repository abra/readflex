import 'package:flutter_test/flutter_test.dart';
import 'package:reader_webview/src/reader_common_handlers.dart';

void main() {
  group('parseReaderSelectionPayload', () {
    test('parses map payload', () {
      final selection = parseReaderSelectionPayload({
        'text': 'Selected text',
        'cfi': 'epubcfi(/6/4)',
      });

      expect(selection, isNotNull);
      expect(selection!.text, 'Selected text');
      expect(selection.cfiRange, 'epubcfi(/6/4)');
    });

    test('parses JSON string payload', () {
      final selection = parseReaderSelectionPayload(
        '{"text":"Selected text","scrollOffset":0.5}',
      );

      expect(selection, isNotNull);
      expect(selection!.text, 'Selected text');
      expect(selection.scrollOffset, 0.5);
    });

    test('returns null for non-map payload', () {
      expect(parseReaderSelectionPayload(42), isNull);
      expect(parseReaderSelectionPayload('not-json'), isNull);
    });
  });

  group('parseReaderTapPayload', () {
    test('parses numeric coordinates', () {
      final tap = parseReaderTapPayload({'x': 0.25, 'y': 1});

      expect(tap, isNotNull);
      expect(tap!.x, 0.25);
      expect(tap.y, 1.0);
    });

    test('parses JSON string payload', () {
      final tap = parseReaderTapPayload('{"x":0.75,"y":0.4}');

      expect(tap, isNotNull);
      expect(tap!.x, 0.75);
      expect(tap.y, 0.4);
    });

    test('returns null for malformed coordinates', () {
      expect(parseReaderTapPayload({'x': 'left', 'y': 0.5}), isNull);
      expect(parseReaderTapPayload({'x': 0.5}), isNull);
      expect(parseReaderTapPayload('not-json'), isNull);
    });
  });
}
