part of 'reader_screen.dart';

/// Reads selection from [ReaderSelectionCubit] and source info from
/// [ReaderBloc] to show/hide the text-action context panel.
class _ContextPanelDriver extends StatelessWidget {
  const _ContextPanelDriver({
    required this.textActions,
    required this.webViewKey,
  });

  final List<TextAction> textActions;
  final GlobalKey<BookReaderWebViewState> webViewKey;

  @override
  Widget build(BuildContext context) {
    final sel = context.select<ReaderSelectionCubit, ReaderSelectionState>(
      (c) => c.state,
    );
    final sourceId = context.select<ReaderBloc, String?>(
      (b) => b.state.sourceId,
    );
    final sourceType = context.select<ReaderBloc, SourceType>(
      (b) => b.state.sourceType,
    );

    if (!_selectionActionsVisible(sel.hasSelection) || sourceId == null) {
      return const SizedBox.shrink();
    }

    final bloc = context.read<ReaderBloc>();
    final selectionCubit = context.read<ReaderSelectionCubit>();
    final colors = context.colors;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _ContextPanel(
        selectedText: sel.selectedText,
        normalizedSelectedText: sel.normalizedSelectedText,
        selectionKind: sel.selectionKind,
        contextText: sel.contextText,
        markedContextText: sel.markedContextText,
        normalizedMarkedContextText: sel.normalizedMarkedContextText,
        sourceId: sourceId,
        sourceType: sourceType,
        selectionCfiRange: sel.cfiRange,
        selectionNormalizedCfiRange: sel.normalizedCfiRange,
        selectionPageNumber: sel.pageNumber,
        selectionScrollOffset: sel.scrollOffset,
        textActions: textActions,
        panelColor: colors.surface,
        iconColor: colors.onSurface,
        dividerColor: colors.outlineVariant,
        onActionCompleted: () {
          selectionCubit.deselect();
          webViewKey.currentState?.clearSelectionAfterTextAction();
          if (!bloc.isClosed) {
            bloc.add(const ReaderHighlightsRefreshed());
          }
        },
        onActionError: (e, st) {
          if (!bloc.isClosed) bloc.reportError(e, st);
        },
      ),
    );
  }
}

/// Bottom action strip shown for an active text selection.
///
/// It converts reader selection fields into [TextSelectionContext] and invokes
/// the injected [TextAction]s.
class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.selectedText,
    required this.sourceId,
    required this.sourceType,
    this.normalizedSelectedText,
    this.selectionKind,
    this.contextText,
    this.markedContextText,
    this.normalizedMarkedContextText,
    required this.textActions,
    required this.panelColor,
    required this.iconColor,
    required this.dividerColor,
    required this.onActionCompleted,
    required this.onActionError,
    this.selectionCfiRange,
    this.selectionNormalizedCfiRange,
    this.selectionPageNumber,
    this.selectionScrollOffset,
  });

  final String selectedText;
  final String sourceId;
  final SourceType sourceType;
  final String? normalizedSelectedText;
  final String? selectionKind;
  final String? contextText;
  final String? markedContextText;
  final String? normalizedMarkedContextText;
  final List<TextAction> textActions;
  final Color panelColor;
  final Color iconColor;
  final Color dividerColor;
  final VoidCallback onActionCompleted;
  final void Function(Object error, StackTrace stack) onActionError;
  final String? selectionCfiRange;
  final String? selectionNormalizedCfiRange;
  final int? selectionPageNumber;
  final double? selectionScrollOffset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: panelColor,
      elevation: 0,
      child: AppBottomSafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: dividerColor)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: textActions.map((action) {
                return IconButton(
                  icon: Icon(action.icon, color: iconColor),
                  tooltip: action.label,
                  onPressed: () async {
                    try {
                      await action.onExecute(
                        context,
                        TextSelectionContext(
                          selectedText: selectedText,
                          normalizedSelectedText: normalizedSelectedText,
                          selectionKind: selectionKind,
                          contextText: contextText,
                          markedContextText: markedContextText,
                          normalizedMarkedContextText:
                              normalizedMarkedContextText,
                          sourceId: sourceId,
                          sourceType: sourceType,
                          cfiRange: selectionCfiRange,
                          normalizedCfiRange: selectionNormalizedCfiRange,
                          pageNumber: selectionPageNumber,
                          scrollOffset: selectionScrollOffset,
                        ),
                      );
                      onActionCompleted();
                    } catch (e, st) {
                      onActionError(e, st);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
