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
      scrollOffset: 42,
    );

    expect(selection.selectedText, 'hello');
    expect(selection.sourceId, 'book-1');
    expect(selection.sourceType, SourceType.book);
    expect(selection.normalizedSelectedText, 'hello there');
    expect(selection.selectionKind, 'partial_span');
    expect(selection.contextText, 'Well, hello there.');
    expect(selection.markedContextText, 'Well, [[hello]] there.');
    expect(selection.normalizedMarkedContextText, 'Well, [[hello there]].');
    expect(selection.textForTranslation, 'hello there');
    expect(selection.markedContextTextForTranslation, 'Well, [[hello there]].');
    expect(selection.scrollOffset, 42);
  });

  test(
    'TextSelectionContext falls back to exact selection for translation',
    () {
      const selection = TextSelectionContext(
        selectedText: 'hello',
        sourceId: 'book-1',
        sourceType: SourceType.book,
        markedContextText: 'Well, [[hello]] there.',
      );

      expect(selection.textForTranslation, 'hello');
      expect(
        selection.markedContextTextForTranslation,
        'Well, [[hello]] there.',
      );
    },
  );

  test('TextAction contract can be implemented', () {
    final action = _FakeTextAction();

    expect(action.label, 'Fake');
    expect(action.icon, Icons.add);
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
