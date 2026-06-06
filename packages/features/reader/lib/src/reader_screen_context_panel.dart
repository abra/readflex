part of 'reader_screen.dart';

/// Reads selection from [ReaderSelectionCubit] and source info from
/// [ReaderBloc] to show/hide the text-action context panel.
class _ContextPanelDriver extends StatelessWidget {
  const _ContextPanelDriver({required this.textActions});

  final List<TextAction> textActions;

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
        selectionPageNumber: sel.pageNumber,
        selectionScrollOffset: sel.scrollOffset,
        textActions: textActions,
        panelColor: colors.surface,
        iconColor: colors.onSurface,
        dividerColor: colors.outlineVariant,
        onActionCompleted: () {
          if (!bloc.isClosed) bloc.add(const ReaderHighlightsRefreshed());
        },
        onActionError: (e, st) {
          if (!bloc.isClosed) bloc.reportError(e, st);
        },
      ),
    );
  }
}

/// Renders the review reminder banner when [ReaderReviewReminderCubit] reports
/// due items. Positions itself above the context panel when text is selected.
class _ReviewReminderDriver extends StatelessWidget {
  const _ReviewReminderDriver();

  @override
  Widget build(BuildContext context) {
    final show = context.select<ReaderReviewReminderCubit, bool>(
      (c) => c.state.showReminder,
    );

    if (!show) return const SizedBox.shrink();

    final hasSelection = context.select<ReaderSelectionCubit, bool>(
      (c) => c.state.hasSelection,
    );
    final sourceId = context.select<ReaderBloc, String?>(
      (b) => b.state.sourceId,
    );
    final reminderCubit = context.read<ReaderReviewReminderCubit>();
    final onStartMiniReview = _ReaderCallbacksScope.of(
      context,
    )?.onStartMiniReview;

    return Positioned(
      left: AppSpacing.md,
      right: AppSpacing.md,
      bottom: _selectionActionsVisible(hasSelection)
          ? _kContextPanelHeight
          : AppSpacing.md,
      child: _ReviewReminderBanner(
        onReview: () {
          reminderCubit.dismiss();
          if (sourceId != null) {
            onStartMiniReview?.call(context, sourceId);
          }
        },
        onDismiss: reminderCubit.dismiss,
      ),
    );
  }
}

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

class _ReviewReminderBanner extends StatelessWidget {
  const _ReviewReminderBanner({
    required this.onReview,
    required this.onDismiss,
  });

  final VoidCallback onReview;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(AppIcons.practice, size: AppIconSize.sm),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('You have items to review')),
            TextButton(onPressed: onReview, child: const Text('Review')),
            IconButton(
              icon: const Icon(AppIcons.close, size: AppIconSize.sm),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
