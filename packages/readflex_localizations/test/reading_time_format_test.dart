import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

void main() {
  final en = lookupReadflexLocalizations(const Locale('en'));
  final ru = lookupReadflexLocalizations(const Locale('ru'));

  group('readingTimeLeft', () {
    test('omits unknown, finished and invalid estimates', () {
      for (final minutes in [null, 0.0, -3.0, double.nan, double.infinity]) {
        expect(en.readingTimeLeft(minutes), isNull, reason: '$minutes');
      }
    });

    test('rounds up so a nearly finished text never reads as zero', () {
      expect(en.readingTimeLeft(0.2), '1 min left');
      expect(en.readingTimeLeft(11.01), '12 min left');
    });

    test('switches to hours at one hour and keeps remaining minutes', () {
      expect(en.readingTimeLeft(59.0), '59 min left');
      expect(en.readingTimeLeft(60.0), '1 h 0 min left');
      expect(en.readingTimeLeft(200.5), '3 h 21 min left');
    });

    test('uses the locale word order', () {
      expect(ru.readingTimeLeft(12), 'осталось 12 мин');
      expect(ru.readingTimeLeft(125), 'осталось 2 ч 5 мин');
    });

    test('every supported locale formats the estimate', () {
      for (final locale in ReadflexSupportedLocales.locales) {
        final l10n = lookupReadflexLocalizations(locale);
        expect(l10n.readingTimeLeft(5), contains('5'), reason: '$locale');
        expect(l10n.readingTimeLeft(90), allOf(contains('1'), contains('30')));
      }
    });
  });
}
