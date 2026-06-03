import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_toc_active_index.dart';
import 'package:reader_webview/reader_webview.dart';

ReaderTocItem tocItem(
  String label, {
  double? startPercentage,
  int level = 1,
}) {
  return ReaderTocItem(
    label: label,
    href: '$label.xhtml',
    level: level,
    startPercentage: startPercentage,
  );
}

void main() {
  group('readerActiveTocIndex', () {
    test('selects the last item whose start is before current progress', () {
      final items = [
        tocItem('Intro', startPercentage: 0),
        tocItem('Chapter 1', startPercentage: 0.2),
        tocItem('Chapter 2', startPercentage: 0.5),
      ];

      expect(
        readerActiveTocIndex(
          items: items,
          readingProgress: 0.49,
          chapterTitle: null,
        ),
        1,
      );
    });

    test('prefers the deepest flattened item when starts are identical', () {
      final items = [
        tocItem('Part One', startPercentage: 0.2, level: 1),
        tocItem('Chapter One', startPercentage: 0.2, level: 2),
        tocItem('Chapter Two', startPercentage: 0.4, level: 2),
      ];

      expect(
        readerActiveTocIndex(
          items: items,
          readingProgress: 0.25,
          chapterTitle: null,
        ),
        1,
      );
    });

    test('falls back to the first positioned item before chapter starts', () {
      final items = [
        tocItem('Chapter 1', startPercentage: 0.1),
        tocItem('Chapter 2', startPercentage: 0.5),
      ];

      expect(
        readerActiveTocIndex(
          items: items,
          readingProgress: 0,
          chapterTitle: null,
        ),
        0,
      );
    });

    test('ignores null starts and falls back to chapter title', () {
      final items = [
        tocItem('Intro'),
        tocItem('Current chapter'),
      ];

      expect(
        readerActiveTocIndex(
          items: items,
          readingProgress: 0.4,
          chapterTitle: 'Current chapter',
        ),
        1,
      );
    });

    test('prefers current chapter title over coarse progress metadata', () {
      final items = [
        tocItem('Intro', startPercentage: 0),
        tocItem('Current chapter'),
        tocItem('Next chapter'),
      ];

      expect(
        readerActiveTocIndex(
          items: items,
          readingProgress: 0.4,
          chapterTitle: 'Current chapter',
        ),
        1,
      );
    });

    test('matches chapter title case-insensitively as a final fallback', () {
      final items = [
        tocItem('Chapter One'),
        tocItem('Chapter Two'),
      ];

      expect(
        readerActiveTocIndex(
          items: items,
          readingProgress: null,
          chapterTitle: 'chapter two',
        ),
        1,
      );
    });

    test(
      'returns null when neither progress nor title can identify an item',
      () {
        expect(
          readerActiveTocIndex(
            items: [tocItem('Chapter One')],
            readingProgress: null,
            chapterTitle: null,
          ),
          isNull,
        );
      },
    );
  });
}
