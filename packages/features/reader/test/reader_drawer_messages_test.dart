import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readflex_localizations/readflex_localizations.dart';
import 'package:reader/src/reader_drawer_messages.dart';

final _l10n = lookupReadflexLocalizations(
  ReadflexSupportedLocales.locales.first,
);

void main() {
  group('readerTocEmptyMessage', () {
    test('keeps generic empty and filtered states for regular books', () {
      expect(
        readerTocEmptyMessage(
          l10n: _l10n,
          format: BookFormat.epub,
          hasSourceItems: false,
        ),
        'No chapters found',
      );
      expect(
        readerTocEmptyMessage(
          l10n: _l10n,
          format: BookFormat.epub,
          hasSourceItems: true,
        ),
        'No matching chapters',
      );
    });
  });

  group('readerSearchPromptMessage', () {
    test('keeps default prompt for text formats', () {
      expect(
        readerSearchPromptMessage(_l10n, BookFormat.epub),
        'Type at least 2 characters to search',
      );
    });
  });

  group('readerSearchActionEnabled', () {
    test('keeps regular text formats searchable without feature probing', () {
      expect(
        readerSearchActionEnabled(
          format: BookFormat.epub,
          documentFeatures: null,
        ),
        isTrue,
      );
      expect(
        readerSearchActionTooltip(
          l10n: _l10n,
          format: BookFormat.epub,
          documentFeatures: null,
        ),
        'Search',
      );
    });
  });
}
