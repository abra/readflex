import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text actions clear reader selection after completion', () {
    final contextPanelSource = File(
      'lib/src/reader_screen_context_panel.dart',
    ).readAsStringSync();
    final contentSource = File(
      'lib/src/reader_screen_content.dart',
    ).readAsStringSync();

    expect(contentSource, contains('webViewKey: _webViewKey'));
    expect(contextPanelSource, contains('selectionCubit.deselect();'));
    expect(
      contextPanelSource,
      contains('webViewKey.currentState?.clearSelectionAfterTextAction();'),
    );
    expect(
      contextPanelSource,
      contains('ReaderHighlightsRefreshed'),
    );
  });
}
