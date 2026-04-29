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
      scrollOffset: 42,
    );

    expect(selection.selectedText, 'hello');
    expect(selection.sourceId, 'book-1');
    expect(selection.sourceType, SourceType.book);
    expect(selection.scrollOffset, 42);
  });

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
