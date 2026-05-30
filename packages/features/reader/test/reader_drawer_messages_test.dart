import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_drawer_messages.dart';

void main() {
  group('readerTocEmptyMessage', () {
    test('keeps generic empty and filtered states for regular books', () {
      expect(
        readerTocEmptyMessage(format: BookFormat.epub, hasSourceItems: false),
        'No chapters found',
      );
      expect(
        readerTocEmptyMessage(format: BookFormat.epub, hasSourceItems: true),
        'No matching chapters',
      );
    });
  });

  group('readerSearchPromptMessage', () {
    test('keeps default prompt for text formats', () {
      expect(
        readerSearchPromptMessage(BookFormat.epub),
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
          format: BookFormat.epub,
          documentFeatures: null,
        ),
        'Search',
      );
    });
  });
}
