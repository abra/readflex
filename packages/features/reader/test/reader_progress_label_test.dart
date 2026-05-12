import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_progress_label.dart';

void main() {
  group('readerProgressLabel', () {
    test('shows global percent and visual section page for text books', () {
      expect(
        readerProgressLabel(
          format: BookFormat.epub,
          progress: 0.557,
          chapterCurrentPage: 1,
          chapterTotalPages: 16,
          isDragging: false,
        ),
        '56% · 1 / 16',
      );
    });

    test('does not expose stale section page while dragging text books', () {
      expect(
        readerProgressLabel(
          format: BookFormat.fb2,
          progress: 0.557,
          chapterCurrentPage: 1,
          chapterTotalPages: 16,
          isDragging: true,
        ),
        '56%',
      );
    });

    test('keeps comic page counters as page over total', () {
      expect(
        readerProgressLabel(
          format: BookFormat.cbz,
          progress: 0.2,
          chapterCurrentPage: 11,
          chapterTotalPages: 50,
          isDragging: false,
        ),
        '12 / 50',
      );
    });

    test('previews comic page from drag progress', () {
      expect(
        readerProgressLabel(
          format: BookFormat.cbz,
          progress: 1,
          chapterCurrentPage: 11,
          chapterTotalPages: 50,
          isDragging: true,
        ),
        '50 / 50',
      );
    });

    test('clamps non-finite and out-of-range progress', () {
      expect(readingPercentLabel(double.nan), '0%');
      expect(readingPercentLabel(-0.5), '0%');
      expect(readingPercentLabel(1.5), '100%');
    });

    test('normalizes visual section page buffer values', () {
      expect(
        visualSectionPageLabel(currentPage: 0, totalPages: 16),
        '1 / 16',
      );
      expect(
        visualSectionPageLabel(currentPage: 17, totalPages: 16),
        '16 / 16',
      );
    });
  });
}
