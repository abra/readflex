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
    expect(contextPanelSource, contains('ReaderHighlightDeleteRequested'));
    expect(
      contextPanelSource,
      contains('ReaderHighlightColorChangeRequested'),
    );
    expect(contextPanelSource, contains('ReaderHighlightNoteChangeRequested'));
    expect(contextPanelSource, contains('_SavedHighlightPopup'));
    expect(contextPanelSource, isNot(contains('_HighlightDeletePopup')));
    expect(contextPanelSource, contains('Highlight removed'));
    expect(contextPanelSource, contains('Comment updated'));
    expect(contextPanelSource, contains('ColorHighlightTextAction'));
    expect(contextPanelSource, contains('Highlight saved'));
    expect(contextPanelSource, contains('_kHighlightPopupColorCount'));
    expect(
      contextPanelSource,
      contains('_kHighlightPopupHorizontalPadding * 2'),
    );
    expect(contextPanelSource, contains('onDismiss: dismissSelection'));
    expect(contextPanelSource, contains('HitTestBehavior.translucent'));
    expect(contextPanelSource, contains('AppShadows.popover'));
    expect(
      contextPanelSource,
      contains('readerHighlightColor(color, readerTheme)'),
    );
    expect(
      contentSource,
      contains('color: readerHighlightCssColor(h.color, theme)'),
    );
    expect(contentSource, contains('opacity: readerHighlightOpacity(theme)'));
    expect(
      contentSource,
      contains('mixBlendMode: readerHighlightBlendMode(theme)'),
    );
    expect(
      contentSource,
      contains('verticalOffset: readerHighlightVerticalOffset(theme)'),
    );
    expect(contentSource, contains('final currentState = bloc.state;'));
    expect(
      contentSource,
      contains('progress: currentState.document?.readingProgress'),
    );
    expect(contentSource, contains('chapterTitle: currentState.chapterTitle'));
    expect(contextPanelSource, contains('showSelectionHighlightPreview'));
    expect(
      contextPanelSource,
      contains('opacity: readerHighlightOpacity(readerTheme)'),
    );
    expect(
      contextPanelSource,
      contains('mixBlendMode: readerHighlightBlendMode(readerTheme)'),
    );
    expect(
      contextPanelSource,
      contains('verticalOffset: readerHighlightVerticalOffset(readerTheme)'),
    );
    expect(contextPanelSource, contains('clearSelectionHighlightPreview'));
    expect(contextPanelSource, contains('onPreviewColorChanged'));
    expect(contextPanelSource, contains('onPreviewCleared'));
    expect(contextPanelSource, contains('_ImageHighlightSelectionPopup'));
    expect(contextPanelSource, contains('_ImageHighlightNoteSheet'));
    expect(contextPanelSource, contains('showAppBottomSheet'));
    expect(contextPanelSource, contains('Highlight note'));
    expect(contextPanelSource, contains('Edit note'));
    expect(contextPanelSource, contains('Add a comment (optional)'));
    expect(contextPanelSource, contains('child: OutlinedButton('));
    expect(contextPanelSource, isNot(contains('FilledButton.icon(')));
    expect(contextPanelSource, contains('note: result.note'));
    expect(
      contextPanelSource,
      contains('can clear the draft selection while the modal sheet is open'),
    );
    expect(contextPanelSource, contains('_keepPreviewOnDispose'));
    expect(
      contextPanelSource,
      contains('if (!_keepPreviewOnDispose) widget.onPreviewCleared();'),
    );
    expect(contextPanelSource, contains('final sourceId = widget.sourceId;'));
    expect(contextPanelSource, contains('if (imageHighlightCubit.isClosed)'));
    expect(
      contextPanelSource,
      isNot(contains('onDismiss: dismissImageSelection')),
    );
    expect(contextPanelSource, contains('widget.onPreviewColorChanged(color)'));
    expect(contextPanelSource, contains('AppIcons.check'));
    expect(contextPanelSource, contains('AppIcons.edit'));
    expect(contextPanelSource, contains('computeLuminance()'));
    expect(
      contextPanelSource,
      contains(
        'onPopupInteractionStarted: imageSelectionCubit.protectNextClear',
      ),
    );
    expect(
      contextPanelSource,
      contains('onDraftRetentionChanged: setImageHighlightDraftRetained'),
    );
    expect(contextPanelSource, contains('holdClearProtection()'));
    expect(contextPanelSource, contains('releaseClearProtection()'));
    expect(
      contextPanelSource,
      contains('setImageAreaSelectionPreviewRetained(retained)'),
    );
    expect(contextPanelSource, contains('onControlsBoundsChanged'));
    expect(contextPanelSource, contains('_kImageHighlightPopupGap'));
    expect(
      contextPanelSource,
      contains('setImageAreaSelectionControlsBounds'),
    );
    expect(
      contextPanelSource,
      contains('clearImageAreaSelectionControlsBounds'),
    );
    expect(contextPanelSource, contains('allowNextTap: true'));
    expect(contentSource, contains('consumeProtectedClear()'));
    expect(contextPanelSource, contains('icon: AppIcons.delete'));
    expect(contextPanelSource, contains('icon: AppIcons.highlight'));
    expect(contextPanelSource, contains('tooltip: \'Edit comment\''));
    expect(contentSource, contains('onHighlightTapped: (tap)'));
    expect(contentSource, contains('highlightFocusCubit.focus(tap)'));
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
