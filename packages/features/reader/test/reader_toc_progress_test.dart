import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_toc_progress.dart';
import 'package:reader_webview/reader_webview.dart';

void main() {
  ReaderTocItem item(
    String label, {
    int level = 1,
    int? page,
    double? percentage,
  }) => ReaderTocItem(
    label: label,
    href: label,
    level: level,
    startPage: page,
    startPercentage: percentage,
  );

  group('readerTocReadingStates', () {
    const read = ReaderTocReadingState.read;
    const active = ReaderTocReadingState.active;
    const upcoming = ReaderTocReadingState.upcoming;

    test('chapters before the active one are read, later ones upcoming', () {
      final items = [item('1'), item('2'), item('3'), item('4')];
      expect(readerTocReadingStates(items, 2), [read, read, active, upcoming]);
      expect(readerTocReadingStates(items, 0), [
        active,
        upcoming,
        upcoming,
        upcoming,
      ]);
    });

    test('ancestors of the active chapter are not read', () {
      final items = [
        item('Part one'),
        item('1.1', level: 2),
        item('Part two'),
        item('2.1', level: 2),
        item('2.1.1', level: 3),
        item('2.2', level: 2),
        item('2.2.1', level: 3),
        item('Part three'),
      ];
      expect(readerTocReadingStates(items, 6), [
        read, // Part one
        read, // 1.1
        upcoming, // Part two contains the active chapter
        read, // 2.1
        read, // 2.1.1
        upcoming, // 2.2 is the active chapter's parent
        active,
        upcoming,
      ]);
    });

    test('without an active chapter every row is upcoming', () {
      final items = [item('1'), item('2')];
      for (final index in [null, -1, 2]) {
        expect(readerTocReadingStates(items, index), [upcoming, upcoming]);
      }
      expect(readerTocReadingStates(const [], null), isEmpty);
    });

    test('flat comic-style level 0 entries still mark earlier pages read', () {
      final items = [
        item('a', level: 0),
        item('b', level: 0),
        item('c', level: 0),
      ];
      expect(readerTocReadingStates(items, 2), [read, read, active]);
    });
  });

  group('start position', () {
    test('page wins over percent', () {
      final value = item('a', page: 12, percentage: .5);
      expect(readerTocStartPage(value), 12);
    });

    test('the opening chapter reports page 0 and shows page 1', () {
      expect(readerTocStartPage(item('a', page: 0)), 1);
      expect(readerTocStartPage(item('a', page: -3)), isNull);
      expect(readerTocStartPage(item('a')), isNull);
    });

    test('percent rounds to a whole number and clamps', () {
      expect(readerTocStartPercent(item('a', percentage: .456)), 46);
      expect(readerTocStartPercent(item('a', percentage: 0)), 0);
      expect(readerTocStartPercent(item('a', percentage: 1.4)), 100);
      expect(readerTocStartPercent(item('a', percentage: -.2)), 0);
      expect(readerTocStartPercent(item('a', percentage: double.nan)), isNull);
      expect(readerTocStartPercent(item('a')), isNull);
    });
  });
}
