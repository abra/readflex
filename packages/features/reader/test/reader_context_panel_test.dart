import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('text actions clear reader selection after completion', () {
    final contextPanelSource = _readSource(
      packagePath: 'lib/src/reader_screen_context_panel.dart',
    );
    final contentSource = _readSource(
      packagePath: 'lib/src/reader_screen_content.dart',
    );

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
    expect(contextPanelSource, contains('ColorHighlightTextAction'));
    expect(contextPanelSource, contains('Highlight saved'));
    expect(contextPanelSource, contains('onDismiss: dismissSelection'));
    expect(contextPanelSource, contains('HitTestBehavior.translucent'));
    expect(contextPanelSource, contains('AppShadows.popover'));
  });
}

String _readSource({required String packagePath}) {
  final candidates = [
    File(packagePath),
    File('packages/features/reader/$packagePath'),
  ];
  for (final file in candidates) {
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError('Reader source file not found: $packagePath');
}
