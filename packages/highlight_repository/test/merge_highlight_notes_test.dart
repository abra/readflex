import 'package:flutter_test/flutter_test.dart';
import 'package:highlight_repository/src/merge_highlight_notes.dart';

void main() {
  test('joins notes in the given order with a blank line', () {
    expect(mergeHighlightNotes(['First', 'Second']), 'First\n\nSecond');
  });

  test('drops null, blank and repeated notes after trimming', () {
    expect(
      mergeHighlightNotes([null, '  A  ', '', '\n', 'A', 'B', ' B ']),
      'A\n\nB',
    );
  });

  test('returns null when no note remains', () {
    expect(mergeHighlightNotes(const []), isNull);
    expect(mergeHighlightNotes([null, '   ']), isNull);
  });

  test('keeps multi-line notes intact', () {
    expect(
      mergeHighlightNotes(['Line 1\nLine 2', 'Other']),
      'Line 1\nLine 2\n\nOther',
    );
  });
}
