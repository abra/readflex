import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_chrome_actions.dart';

void main() {
  group('readerChromeActionsForFormat', () {
    test('keeps text-reader controls for regular books', () {
      for (final format in BookFormat.values.where(
        (f) => f != BookFormat.cbz,
      )) {
        final actions = readerChromeActionsForFormat(format);

        expect(actions, contains(ReaderChromeAction.contents));
        expect(actions, contains(ReaderChromeAction.textAppearance));
        expect(actions, contains(ReaderChromeAction.bookmark));
        expect(actions, contains(ReaderChromeAction.textSearch));
      }
    });

    test('keeps only comic-relevant controls for cbz', () {
      final actions = readerChromeActionsForFormat(BookFormat.cbz);

      expect(actions, contains(ReaderChromeAction.contents));
      expect(actions, contains(ReaderChromeAction.bookmark));
      expect(actions, isNot(contains(ReaderChromeAction.textAppearance)));
      expect(actions, isNot(contains(ReaderChromeAction.textSearch)));
    });

    test('defaults to text-reader controls before format is known', () {
      final actions = readerChromeActionsForFormat(null);

      expect(actions, contains(ReaderChromeAction.textAppearance));
      expect(actions, contains(ReaderChromeAction.textSearch));
    });
  });
}
