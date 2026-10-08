import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_chrome_labels.dart';

void main() {
  group('readerTopChromeLine', () {
    test('joins a known chapter with the title', () {
      expect(
        readerTopChromeLine(title: 'Dune', chapterTitle: 'Book One'),
        'Book One · Dune',
      );
    });

    test('shows the title alone without a chapter', () {
      expect(readerTopChromeLine(title: 'Dune'), 'Dune');
      expect(readerTopChromeLine(title: 'Dune', chapterTitle: ''), 'Dune');
      expect(readerTopChromeLine(title: 'Dune', chapterTitle: '   '), 'Dune');
    });

    test('does not repeat a chapter equal to the title', () {
      expect(
        readerTopChromeLine(
          title: 'Saved Article',
          chapterTitle: 'Saved Article',
        ),
        'Saved Article',
      );
    });

    test('trims both parts', () {
      expect(
        readerTopChromeLine(title: ' Dune ', chapterTitle: ' One '),
        'One · Dune',
      );
    });

    test('falls back to the chapter when the title is empty', () {
      expect(readerTopChromeLine(title: '', chapterTitle: 'One'), 'One');
    });
  });

  group('readerChromeArticleTimeLeftLabel', () {
    late ReadflexLocalizations l10n;

    setUpAll(() async {
      l10n = await ReadflexLocalizations.delegate.load(const Locale('en'));
    });

    test('shows minutes left in the whole article, rounded up', () {
      expect(
        readerChromeArticleTimeLeftLabel(l10n, minutes: 4.2),
        l10n.readingTimeLeftMinutes(5),
      );
      expect(
        readerChromeArticleTimeLeftLabel(l10n, minutes: 75),
        l10n.readingTimeLeftHours(1, 15),
      );
    });

    for (final minutes in [null, 0.0, -1.0, double.nan, double.infinity]) {
      test('is omitted for $minutes', () {
        expect(
          readerChromeArticleTimeLeftLabel(l10n, minutes: minutes),
          isNull,
        );
      });
    }
  });
}
