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

    test('shows article section page instead of global percent', () {
      expect(
        readerProgressLabel(
          sourceType: SourceType.article,
          format: BookFormat.epub,
          progress: 0.557,
          chapterCurrentPage: 2,
          chapterTotalPages: 3,
          isDragging: false,
        ),
        '2 / 3',
      );
    });

    test('previews article section page from drag progress', () {
      expect(
        readerProgressLabel(
          sourceType: SourceType.article,
          format: BookFormat.epub,
          progress: 0.8,
          chapterCurrentPage: 1,
          chapterTotalPages: 3,
          isDragging: true,
        ),
        '3 / 3',
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

    test('uses discrete slider divisions only for articles', () {
      expect(
        readerSliderDivisions(
          sourceType: SourceType.article,
          totalPages: 3,
        ),
        2,
      );
      expect(
        readerSliderDivisions(
          sourceType: SourceType.book,
          totalPages: 3,
        ),
        isNull,
      );
      expect(
        readerSliderDivisions(
          sourceType: SourceType.article,
          totalPages: 1,
        ),
        isNull,
      );
    });

    test('hides progress slider for single-page page-only readers', () {
      expect(
        shouldShowReaderProgressSlider(
          sourceType: SourceType.article,
          format: BookFormat.epub,
          totalPages: 1,
        ),
        isFalse,
      );
      expect(
        shouldShowReaderProgressSlider(
          sourceType: SourceType.book,
          format: BookFormat.cbz,
          totalPages: 1,
        ),
        isFalse,
      );
      expect(
        shouldShowReaderProgressSlider(
          sourceType: SourceType.article,
          format: BookFormat.epub,
          totalPages: 2,
        ),
        isTrue,
      );
      expect(
        shouldShowReaderProgressSlider(
          sourceType: SourceType.book,
          format: BookFormat.epub,
          totalPages: 1,
        ),
        isTrue,
      );
    });

    test('snaps seek progress only for articles', () {
      expect(
        snappedReaderSeekProgress(
          sourceType: SourceType.article,
          progress: 0.52,
          totalPages: 3,
        ),
        0.5,
      );
      expect(
        snappedReaderSeekProgress(
          sourceType: SourceType.book,
          progress: 0.52,
          totalPages: 3,
        ),
        0.52,
      );
      expect(
        snappedReaderSeekProgress(
          sourceType: SourceType.article,
          progress: 1.5,
          totalPages: 3,
        ),
        1,
      );
    });

    test(
      'maps article slider value from section page, not global progress',
      () {
        expect(
          readerSliderValue(
            sourceType: SourceType.article,
            progress: 0.557,
            currentPage: 1,
            totalPages: 3,
          ),
          0,
        );
        expect(
          readerSliderValue(
            sourceType: SourceType.article,
            progress: 0.557,
            currentPage: 2,
            totalPages: 3,
          ),
          0.5,
        );
        expect(
          readerSliderValue(
            sourceType: SourceType.article,
            progress: 0.557,
            currentPage: 3,
            totalPages: 3,
          ),
          1,
        );
      },
    );

    test('keeps non-article slider value continuous', () {
      expect(
        readerSliderValue(
          sourceType: SourceType.book,
          progress: 0.557,
          currentPage: 1,
          totalPages: 3,
        ),
        0.557,
      );
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
