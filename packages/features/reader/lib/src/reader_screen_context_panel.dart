part of 'reader_screen.dart';

const _kHighlightPopupWidth = 292.0;
const _kHighlightPopupHeight = 52.0;
const _kHighlightPopupGap = AppSpacing.sm;
const _kHighlightPopupHorizontalInset = AppSpacing.lg;
const _kHighlightSwatchSize = 24.0;
const _kHighlightSwatchTapSize = 40.0;

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
    final selection = TextSelectionContext(
      selectedText: sel.selectedText,
      normalizedSelectedText: sel.normalizedSelectedText,
      selectionKind: sel.selectionKind,
      contextText: sel.contextText,
      markedContextText: sel.markedContextText,
      normalizedMarkedContextText: sel.normalizedMarkedContextText,
      sourceId: sourceId,
      sourceType: sourceType,
      cfiRange: sel.cfiRange,
      normalizedCfiRange: sel.normalizedCfiRange,
      pageNumber: sel.pageNumber,
      scrollOffset: sel.scrollOffset,
    );
    final highlightAction = _highlightActionFor(textActions);

    void dismissSelection() {
      selectionCubit.deselect();
      webViewKey.currentState?.clearSelectionAfterTextAction();
    }

    void completeHighlightAction() {
      dismissSelection();
      if (!bloc.isClosed) {
        bloc.add(const ReaderHighlightsRefreshed());
      }
      showToast(
        context,
        type: NotificationType.success,
        message: 'Highlight saved',
      );
    }

    void handleActionError(Object error, StackTrace stack) {
      if (!bloc.isClosed) bloc.reportError(error, stack);
      showToast(
        context,
        type: NotificationType.error,
        message: 'Failed to save highlight',
      );
    }

    if (highlightAction != null) {
      return Positioned.fill(
        child: _HighlightSelectionPopup(
          action: highlightAction,
          selection: selection,
          selectionPosition: sel.position,
          panelColor: colors.surface,
          foregroundColor: colors.onSurface,
          dividerColor: colors.outlineVariant,
          onDismiss: dismissSelection,
          onActionCompleted: completeHighlightAction,
          onActionError: handleActionError,
        ),
      );
    }

    final fallbackActions = textActions
        .where((action) => action is! ColorHighlightTextAction)
        .toList(growable: false);
    if (fallbackActions.isEmpty) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: _ContextPanel(
        selection: selection,
        textActions: fallbackActions,
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

ColorHighlightTextAction? _highlightActionFor(List<TextAction> actions) {
  for (final action in actions) {
    if (action is ColorHighlightTextAction) return action;
  }
  return null;
}

/// Compact floating highlight menu anchored to the active WebView selection.
class _HighlightSelectionPopup extends StatefulWidget {
  const _HighlightSelectionPopup({
    required this.action,
    required this.selection,
    required this.panelColor,
    required this.foregroundColor,
    required this.dividerColor,
    required this.onDismiss,
    required this.onActionCompleted,
    required this.onActionError,
    this.selectionPosition,
  });

  final ColorHighlightTextAction action;
  final TextSelectionContext selection;
  final ReaderSelectionPosition? selectionPosition;
  final Color panelColor;
  final Color foregroundColor;
  final Color dividerColor;
  final VoidCallback onDismiss;
  final VoidCallback onActionCompleted;
  final void Function(Object error, StackTrace stack) onActionError;

  @override
  State<_HighlightSelectionPopup> createState() =>
      _HighlightSelectionPopupState();
}

class _HighlightSelectionPopupState extends State<_HighlightSelectionPopup> {
  HighlightColor _selectedColor = HighlightColor.yellow;
  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.action.onExecuteWithColor(
        context,
        widget.selection,
        _selectedColor,
      );
      if (!mounted) return;
      widget.onActionCompleted();
    } catch (error, stack) {
      if (!mounted) return;
      widget.onActionError(error, stack);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaPadding = MediaQuery.paddingOf(context);
        final horizontalInset = _highlightPopupHorizontalInset(
          constraints.maxWidth,
        );
        final width = _highlightPopupWidth(
          constraints.maxWidth,
          horizontalInset,
        );
        final left = _popupLeft(
          constraints: constraints,
          horizontalInset: horizontalInset,
          width: width,
          position: widget.selectionPosition,
        );
        final top = _popupTop(
          constraints: constraints,
          mediaPadding: mediaPadding,
          position: widget.selectionPosition,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _saving ? () {} : widget.onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              height: _kHighlightPopupHeight,
              child: _HighlightPopupSurface(
                selectedColor: _selectedColor,
                saving: _saving,
                panelColor: widget.panelColor,
                foregroundColor: widget.foregroundColor,
                dividerColor: widget.dividerColor,
                onColorChanged: (color) {
                  if (_saving || _selectedColor == color) return;
                  setState(() => _selectedColor = color);
                },
                onSave: _save,
              ),
            ),
          ],
        );
      },
    );
  }

  double _popupLeft({
    required BoxConstraints constraints,
    required double horizontalInset,
    required double width,
    required ReaderSelectionPosition? position,
  }) {
    final centerX = position == null
        ? constraints.maxWidth / 2
        : ((position.left + position.right) / 2) * constraints.maxWidth;
    final minLeft = horizontalInset;
    final maxLeft = (constraints.maxWidth - width - horizontalInset).clamp(
      minLeft,
      constraints.maxWidth,
    );
    return (centerX - width / 2).clamp(minLeft, maxLeft).toDouble();
  }

  double _popupTop({
    required BoxConstraints constraints,
    required EdgeInsets mediaPadding,
    required ReaderSelectionPosition? position,
  }) {
    final minTop = mediaPadding.top + AppSpacing.sm;
    final availableMaxTop =
        constraints.maxHeight -
        mediaPadding.bottom -
        _kHighlightPopupHeight -
        AppSpacing.sm;
    final maxTop = availableMaxTop <= minTop ? minTop : availableMaxTop;
    if (position == null) return maxTop;

    final selectionTop = position.top * constraints.maxHeight;
    final selectionBottom = position.bottom * constraints.maxHeight;
    final aboveTop =
        selectionTop - _kHighlightPopupHeight - _kHighlightPopupGap;
    final belowTop = selectionBottom + _kHighlightPopupGap;
    final preferredTop = aboveTop >= minTop ? aboveTop : belowTop;
    return preferredTop.clamp(minTop, maxTop).toDouble();
  }

  double _highlightPopupHorizontalInset(double maxWidth) {
    if (maxWidth <= _kHighlightPopupHorizontalInset * 2) return 0;
    return _kHighlightPopupHorizontalInset;
  }

  double _highlightPopupWidth(double maxWidth, double horizontalInset) {
    final availableWidth = maxWidth - horizontalInset * 2;
    if (availableWidth <= 0) return 0;
    return availableWidth < _kHighlightPopupWidth
        ? availableWidth
        : _kHighlightPopupWidth;
  }
}

class _HighlightPopupSurface extends StatelessWidget {
  const _HighlightPopupSurface({
    required this.selectedColor,
    required this.saving,
    required this.panelColor,
    required this.foregroundColor,
    required this.dividerColor,
    required this.onColorChanged,
    required this.onSave,
  });

  final HighlightColor selectedColor;
  final bool saving;
  final Color panelColor;
  final Color foregroundColor;
  final Color dividerColor;
  final ValueChanged<HighlightColor> onColorChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.full);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: radius,
        border: Border.all(
          color: dividerColor.withValues(alpha: 0.72),
          width: 1 / MediaQuery.devicePixelRatioOf(context),
        ),
        boxShadow: AppShadows.popover,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            children: [
              for (final color in HighlightColor.values)
                _HighlightColorButton(
                  color: color,
                  selected: selectedColor == color,
                  enabled: !saving,
                  onPressed: () => onColorChanged(color),
                ),
              SizedBox(
                height: AppSizes.chipHeight,
                child: VerticalDivider(
                  color: dividerColor,
                  thickness: 1,
                  width: AppSpacing.sm,
                ),
              ),
              SizedBox(
                width: _kHighlightSwatchTapSize,
                height: _kHighlightSwatchTapSize,
                child: Tooltip(
                  message: 'Highlight',
                  child: InkResponse(
                    radius: _kHighlightSwatchTapSize / 2,
                    onTap: saving ? null : onSave,
                    child: Center(
                      child: saving
                          ? const ButtonLoadingIndicator(size: AppIconSize.sm)
                          : Icon(
                              AppIcons.highlight,
                              size: AppIconSize.sm,
                              color: foregroundColor,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightColorButton extends StatelessWidget {
  const _HighlightColorButton({
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final HighlightColor color;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final swatch = _colorForHighlight(context, color);
    final borderColor = context.colors.onSurface.withValues(
      alpha: selected ? 0.72 : 0.16,
    );
    return SizedBox(
      width: _kHighlightSwatchTapSize,
      height: _kHighlightSwatchTapSize,
      child: Tooltip(
        message: color.name,
        child: InkResponse(
          radius: _kHighlightSwatchTapSize / 2,
          onTap: enabled ? onPressed : null,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              width: selected ? _kHighlightSwatchSize : 20,
              height: selected ? _kHighlightSwatchSize : 20,
              decoration: BoxDecoration(
                color: swatch,
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: selected ? 2 : 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _colorForHighlight(BuildContext context, HighlightColor color) {
  final ext = context.appColors;
  return switch (color) {
    HighlightColor.yellow => ext.highlightYellow,
    HighlightColor.green => ext.highlightGreen,
    HighlightColor.blue => ext.highlightBlue,
    HighlightColor.pink => ext.highlightPink,
    HighlightColor.purple => ext.highlightPurple,
  };
}

/// Bottom action strip shown for an active text selection.
///
/// It converts reader selection fields into [TextSelectionContext] and invokes
/// the injected [TextAction]s.
class _ContextPanel extends StatelessWidget {
  const _ContextPanel({
    required this.selection,
    required this.textActions,
    required this.panelColor,
    required this.iconColor,
    required this.dividerColor,
    required this.onActionCompleted,
    required this.onActionError,
  });

  final TextSelectionContext selection;
  final List<TextAction> textActions;
  final Color panelColor;
  final Color iconColor;
  final Color dividerColor;
  final VoidCallback onActionCompleted;
  final void Function(Object error, StackTrace stack) onActionError;

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
                      await action.onExecute(context, selection);
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
