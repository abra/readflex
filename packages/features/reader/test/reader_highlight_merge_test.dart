import 'package:flutter_test/flutter_test.dart';
import 'package:reader/src/reader_highlight_merge.dart';
import 'package:reader_webview/reader_webview.dart';
import 'package:shared/shared.dart';

void main() {
  test('a selection without a merge plan maps to no target', () {
    expect(highlightMergeTargetFor(null), isNull);
  });

  test('maps the WebView plan onto the text-action contract', () {
    final target = highlightMergeTargetFor(
      ReaderHighlightMerge.fromValue({
        'cfi': 'union-cfi',
        'text': 'power bank keeps devices',
        'highlightIds': ['left', 'right'],
      }),
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
