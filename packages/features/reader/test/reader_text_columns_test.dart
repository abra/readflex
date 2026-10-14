import 'package:flutter_test/flutter_test.dart';
import 'package:preferences_service/preferences_service.dart';
import 'package:reader/src/reader_text_columns.dart';

void main() {
  group('readerTextColumns', () {
    test('a narrow window keeps one column across the page', () {
      for (final columns in [null, ...ReaderColumns.values]) {
        expect(
          readerTextColumns(
            wideWindow: false,
            fixedLayout: false,
            columns: columns,
          ),
          kReaderFullWidthColumn,
          reason: '$columns',
        );
      }
    });

    test('a wide window sends the choice with the measure', () {
      expect(
        readerTextColumns(
          wideWindow: true,
          fixedLayout: false,
          columns: ReaderColumns.auto,
        ),
        (maxColumnCount: 0, maxLineWidthEm: kReaderMaxLineWidthEm),
      );
      expect(
        readerTextColumns(
          wideWindow: true,
          fixedLayout: false,
          columns: ReaderColumns.one,
        ),
        (maxColumnCount: 1, maxLineWidthEm: kReaderMaxLineWidthEm),
      );
      expect(
        readerTextColumns(
          wideWindow: true,
          fixedLayout: false,
          columns: ReaderColumns.two,
        ),
        (maxColumnCount: 2, maxLineWidthEm: kReaderMaxLineWidthEm),
      );
    });

    test('a wide article keeps one column at the measure', () {
      expect(
        readerTextColumns(wideWindow: true, fixedLayout: false, columns: null),
        (maxColumnCount: 1, maxLineWidthEm: kReaderMaxLineWidthEm),
      );
    });

    test('image pages keep their own layout in any window', () {
      for (final wideWindow in [false, true]) {
        for (final columns in ReaderColumns.values) {
          expect(
            readerTextColumns(
              wideWindow: wideWindow,
              fixedLayout: true,
              columns: columns,
            ),
            kReaderFullWidthColumn,
          );
        }
      }
    });

    test('the measure sits in the readable range', () {
      // Body text averages about half an em per character.
      final characters = kReaderMaxLineWidthEm / 0.47;
      expect(characters, inInclusiveRange(45, 75));
    });
  });
}
