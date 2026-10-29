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

    expect(contentSource, contains('surface: _surface'));
    expect(contextPanelSource, contains('selectionCubit.deselect();'));
    expect(
      contextPanelSource,
      contains('surface.clearSelectionAfterTextAction();'),
    );
    expect(
      contextPanelSource,
      contains('final highlightAction = _highlightActionFor(textActions);'),
    );
    expect(contextPanelSource, isNot(contains('canCreateTextHighlight')));
    expect(
      contextPanelSource,
      contains('ReaderHighlightsRefreshed'),
    );
    expect(contextPanelSource, contains('ReaderHighlightDeleteRequested'));
    // Closing Contents purges both bookmark and highlight Undo rows.
    expect(
      contentSource,
      contains('''
      listener: (context, _) => context.read<ReaderBloc>()
        ..add(const ReaderBookmarkUndoDismissed())
        ..add(const ReaderHighlightUndoDismissed()),'''),
    );
    expect(
      contextPanelSource,
      contains('ReaderHighlightColorChangeRequested'),
    );
    expect(contextPanelSource, contains('ReaderHighlightNoteChangeRequested'));
    expect(contextPanelSource, contains('ReaderSavedHighlightPopup'));
    expect(contextPanelSource, isNot(contains('_HighlightDeletePopup')));
    expect(contextPanelSource, contains('ColorHighlightTextAction'));
    expect(contextPanelSource, contains('readerHighlightSaved'));
    expect(contextPanelSource, contains('_kHighlightPopupColorCount'));
    expect(
      contextPanelSource,
      contains('_kHighlightPopupHorizontalPadding * 2'),
    );
    // The saved-highlight barrier consumes its dismissing tap; no popup
    // lets a page tap fall through to the page.
    expect(contextPanelSource, isNot(contains('HitTestBehavior.translucent')));
    expect(contextPanelSource, contains('AppShadows.popover'));
    expect(
      contextPanelSource,
      contains('ReaderHighlightControls('),
    );
    // Saving merges overlapping highlights; the colour preview shows that
    // merged range.
    expect(
      contextPanelSource,
      contains(
        'final cfiRange = sel.highlightMerge?.cfiRange ?? sel.cfiRange;',
      ),
    );
    expect(
      contextPanelSource,
      contains('highlightMerge: highlightMergeTargetFor(live.highlightMerge)'),
    );
    expect(contextPanelSource, contains('showSelectionHighlightPreview'));
    expect(
      contextPanelSource,
      contains('opacity: readerHighlightOpacity(readerTheme)'),
    );
    expect(contextPanelSource, contains('clearSelectionHighlightPreview'));
    expect(contextPanelSource, contains('onPreviewColorChanged'));
    expect(contextPanelSource, contains('onPreviewCleared'));
    expect(
      contextPanelSource,
      contains('await surface.currentTextSelection()'),
    );
    expect(
      contextPanelSource,
      contains('final selection = await _resolveSelectionForAction();'),
    );
    expect(
      contextPanelSource,
      contains('_selectionAtInteractionStart = widget.resolveSelection();'),
    );
    expect(
      contextPanelSource,
      contains('onPointerDown: (_) => onInteractionStarted?.call()'),
    );
    expect(
      contextPanelSource,
      contains('await action.onExecute(context, resolvedSelection);'),
    );
    expect(
      contextPanelSource,
      contains('await widget.onExecuteExtraAction(action, selection);'),
    );
    expect(
      contextPanelSource,
      contains('await onExecuteAction(action, currentSelection);'),
    );
    final executeTextActionStart = contextPanelSource.indexOf(
      'Future<void> executeTextAction(',
    );
    final executeTextActionEnd = contextPanelSource.indexOf(
      'void handleActionError',
      executeTextActionStart,
    );
    expect(executeTextActionStart, greaterThanOrEqualTo(0));
    expect(executeTextActionEnd, greaterThan(executeTextActionStart));
    final executeTextActionSource = contextPanelSource.substring(
      executeTextActionStart,
      executeTextActionEnd,
    );
    expect(
      executeTextActionSource.indexOf('dismissSelection();'),
      lessThan(
        executeTextActionSource.indexOf(
          'await WidgetsBinding.instance.endOfFrame;',
        ),
      ),
    );
    expect(
      executeTextActionSource.indexOf(
        'await WidgetsBinding.instance.endOfFrame;',
      ),
      lessThan(
        executeTextActionSource.indexOf(
          'await action.onExecute(context, resolvedSelection);',
        ),
      ),
    );
    expect(
      contextPanelSource,
      isNot(contains('widget.onExtraActionCompleted();')),
    );
    expect(contextPanelSource, contains("'save-start '"));
    expect(contextPanelSource, contains("'save-action-success op="));
    expect(contextPanelSource, contains("'save-failed '"));
    final activeSelectionPopupStart = contextPanelSource.indexOf(
      'class _HighlightSelectionPopupState',
    );
    final activeSelectionPopupEnd = contextPanelSource.indexOf(
      'class _TextSelectionPopupAction',
      activeSelectionPopupStart,
    );
    expect(activeSelectionPopupStart, greaterThanOrEqualTo(0));
    expect(activeSelectionPopupEnd, greaterThan(activeSelectionPopupStart));
    expect(
      contextPanelSource.substring(
        activeSelectionPopupStart,
        activeSelectionPopupEnd,
      ),
      isNot(contains('GestureDetector(')),
    );
    expect(contextPanelSource, contains('_ImageHighlightSelectionPopup'));
    expect(contextPanelSource, contains('showReaderHighlightNoteSheet'));
    // The editor's UI/lifecycle is exercised by reader_highlight_note_sheet_test.
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
    expect(contextPanelSource, contains('AppIcons.edit'));
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
    expect(contextPanelSource, contains('_kImageHighlightPopupGap'));
    expect(contextPanelSource, contains('icon: AppIcons.delete'));
    expect(contextPanelSource, contains('icon: AppIcons.highlight'));
    expect(contextPanelSource, contains('bool get _busy =>'));
    expect(contextPanelSource, contains('loading: _saving'));
    expect(contextPanelSource, contains('_executingExtraAction = true'));
    expect(contextPanelSource, contains('_TextSelectionPopupSurface'));
    expect(contextPanelSource, contains('_kTextSelectionPopupHeight'));
    expect(contextPanelSource, contains('_TextSelectionActionButton'));
    final actionButtonStart = contextPanelSource.indexOf(
      'class _TextSelectionActionButton',
    );
    final actionButtonEnd = contextPanelSource.indexOf(
      'class _HighlightPopupSurface',
      actionButtonStart,
    );
    expect(actionButtonStart, greaterThanOrEqualTo(0));
    final actionButtonSource = contextPanelSource.substring(
      actionButtonStart,
      actionButtonEnd,
    );
    expect(actionButtonSource, contains('Semantics('));
    expect(actionButtonSource, contains('button: true'));
    expect(actionButtonSource, contains('enabled: enabled'));
    expect(actionButtonSource, contains('InkWell('));
    expect(actionButtonSource, contains('minHeight: AppSizes.buttonHeight'));
    expect(actionButtonSource, isNot(contains('GestureDetector(')));
    expect(contextPanelSource, isNot(contains('if (action.loading)')));
    expect(
      contextPanelSource,
      isNot(
        contains(
          'setState(() => _saving = true);\n    try {\n      await action.onExecute',
        ),
      ),
    );
    expect(
      contextPanelSource,
      contains('hasNote: focusedHighlightNote != null'),
    );
    expect(
      contextPanelSource,
      contains(
        'tooltip: hasNote\n'
        '                          ? context.l10n.readerEditComment\n'
        '                          : context.l10n.readerAddComment',
      ),
    );
    expect(contextPanelSource, isNot(contains('return IconButton(')));
    expect(contextPanelSource, contains('return AppPlainIconButton('));
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
