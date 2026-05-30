import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_drawer_messages.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  group('readerTocEmptyMessage', () {
    test('describes DjVu files without embedded contents', () {
      expect(
        readerTocEmptyMessage(
          format: BookFormat.djvu,
          hasSourceItems: false,
        ),
        'This DjVu file does not include a table of contents.',
      );
    });

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
    test('mentions DjVu text layer requirement', () {
      expect(
        readerSearchPromptMessage(BookFormat.djvu),
        'DjVu search uses the file OCR text layer. Type at least 2 characters to search.',
      );
    });

    test('keeps default prompt for text formats', () {
      expect(
        readerSearchPromptMessage(BookFormat.epub),
        'Type at least 2 characters to search',
      );
    });
  });

  group('readerSearchActionEnabled', () {
    test('disables DjVu search until the text layer is confirmed', () {
      expect(
        readerSearchActionEnabled(
          format: BookFormat.djvu,
          documentFeatures: null,
        ),
        isFalse,
      );
      expect(
        readerSearchActionTooltip(
          format: BookFormat.djvu,
          documentFeatures: null,
        ),
        'Checking DjVu text layer',
      );
    });

    test('disables DjVu search when no text layer is available', () {
      const features = ReaderDocumentFeatures(
        format: 'djvu',
        hasSearchableText: false,
      );

      expect(
        readerSearchActionEnabled(
          format: BookFormat.djvu,
          documentFeatures: features,
        ),
        isFalse,
      );
      expect(
        readerSearchActionTooltip(
          format: BookFormat.djvu,
          documentFeatures: features,
        ),
        'Search unavailable: no text layer',
      );
    });

    test('enables DjVu search once the text layer is available', () {
      const features = ReaderDocumentFeatures(
        format: 'djvu',
        hasSearchableText: true,
      );

      expect(
        readerSearchActionEnabled(
          format: BookFormat.djvu,
          documentFeatures: features,
        ),
        isTrue,
      );
      expect(
        readerSearchActionTooltip(
          format: BookFormat.djvu,
          documentFeatures: features,
        ),
        'Search',
      );
    });

    test('keeps regular text formats searchable without feature probing', () {
      expect(
        readerSearchActionEnabled(
          format: BookFormat.epub,
          documentFeatures: null,
        ),
        isTrue,
      );
    });
  });
}
