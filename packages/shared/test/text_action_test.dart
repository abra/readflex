import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared/shared.dart';

void main() {
  test('TextSelectionContext stores selection metadata', () {
    const selection = TextSelectionContext(
      selectedText: 'hello',
      sourceId: 'article-1',
      sourceType: SourceType.article,
      scrollOffset: 42,
    );

    expect(selection.selectedText, 'hello');
    expect(selection.sourceId, 'article-1');
    expect(selection.sourceType, SourceType.article);
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
  void onExecute(BuildContext context, TextSelectionContext selection) {}
}
