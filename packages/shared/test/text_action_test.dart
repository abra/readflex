import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('TextSelectionContext stores selection metadata', () {
    const selection = TextSelectionContext(
      selectedText: 'hello',
      sourceId: 'book-1',
      sourceType: SourceType.book,
      normalizedSelectedText: 'hello there',
      selectionKind: 'partial_span',
      contextText: 'Well, hello there.',
      markedContextText: 'Well, [[hello]] there.',
      normalizedMarkedContextText: 'Well, [[hello there]].',
      cfiRange: 'exact-cfi',
      normalizedCfiRange: 'normalized-cfi',
      scrollOffset: 42,
      progress: 0.42,
      chapterTitle: 'Chapter 4',
      containedHighlightIds: ['h-1'],
    );

    expect(selection.selectedText, 'hello');
    expect(selection.sourceId, 'book-1');
    expect(selection.sourceType, SourceType.book);
    expect(selection.normalizedSelectedText, 'hello there');
    expect(selection.selectionKind, 'partial_span');
    expect(selection.contextText, 'Well, hello there.');
    expect(selection.markedContextText, 'Well, [[hello]] there.');
    expect(selection.normalizedMarkedContextText, 'Well, [[hello there]].');
    expect(selection.cfiRange, 'exact-cfi');
    expect(selection.normalizedCfiRange, 'normalized-cfi');
    expect(selection.effectiveSelectedText, 'hello there');
    expect(selection.effectiveMarkedContextText, 'Well, [[hello there]].');
    expect(selection.scrollOffset, 42);
    expect(selection.progress, 0.42);
    expect(selection.chapterTitle, 'Chapter 4');
    expect(selection.containedHighlightIds, ['h-1']);
  });

  test(
    'TextSelectionContext falls back to exact selection for actions',
    () {
      const selection = TextSelectionContext(
        selectedText: 'hello',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        markedContextText: 'Well, [[hello]] there.',
      );

      expect(selection.effectiveSelectedText, 'hello');
      expect(
        selection.effectiveMarkedContextText,
        'Well, [[hello]] there.',
      );
    },
  );

  test('TextAction contract can be implemented', () {
    final action = _FakeTextAction();

    expect(action.label, 'Fake');
    expect(action.icon, Icons.add);
  });

  test('ColorHighlightTextAction contract can be implemented', () {
    final action = _FakeColorHighlightTextAction();

    expect(action.label, 'Highlight');
    expect(action.icon, Icons.edit);
  });
}

class _FakeTextAction extends TextAction {
  @override
  IconData get icon => Icons.add;

  @override
  String get label => 'Fake';

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {}
}

class _FakeColorHighlightTextAction extends ColorHighlightTextAction {
  @override
  IconData get icon => Icons.edit;

  @override
  String get label => 'Highlight';

  @override
  Future<void> onExecute(
    BuildContext context,
    TextSelectionContext selection,
  ) async {}

  @override
  Future<void> onExecuteWithColor(
    BuildContext context,
    TextSelectionContext selection,
    HighlightColor color,
  ) async {}
}
