import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_merge.dart';
import 'package:reader/src/reader_selection.dart';
import 'package:shared/shared.dart';

void main() {
  test('a selection without a merge plan maps to no target', () {
    expect(highlightMergeTargetFor(null), isNull);
  });

  test('maps a merge plan onto the text-action contract', () {
    final target = highlightMergeTargetFor(
      const ReaderHighlightMerge(
        cfiRange: 'union-cfi',
        text: 'power bank keeps devices',
        highlightIds: ['left', 'right'],
      ),
    );
    expect(
      target,
      const HighlightMergeTarget(
        cfiRange: 'union-cfi',
        text: 'power bank keeps devices',
        highlightIds: ['left', 'right'],
      ),
    );
  });
}
