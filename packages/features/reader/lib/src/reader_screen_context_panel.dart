part of 'reader_screen.dart';

const _kHighlightPopupColorCount = 5;
const _kHighlightSwatchSize = 24.0;
const _kHighlightSwatchTapSize = 40.0;
const _kHighlightPopupHorizontalPadding = AppSpacing.xs;
const _kHighlightPopupDividerWidth = AppSpacing.sm;
const _kHighlightPopupWidth =
    _kHighlightPopupColorCount * _kHighlightSwatchTapSize +
    _kHighlightPopupDividerWidth +
    _kHighlightSwatchTapSize +
    _kHighlightPopupHorizontalPadding * 2;
const _kHighlightPopupHeight = 52.0;
const _kHighlightPopupGap = AppSpacing.sm;
const _kHighlightPopupHorizontalInset = AppSpacing.lg;

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
    final highlightFocus = context
        .select<ReaderHighlightFocusCubit, ReaderHighlightFocusState>(
          (c) => c.state,
        );
    final focusedHighlight = context.select<ReaderBloc, Highlight?>(
      (b) => _focusedHighlightById(
        b.state.highlights,
        highlightFocus.highlightId,
      ),
    );

    if (sourceId == null) {
      return const SizedBox.shrink();
    }

    final bloc = context.read<ReaderBloc>();
    final selectionCubit = context.read<ReaderSelectionCubit>();
    final highlightFocusCubit = context.read<ReaderHighlightFocusCubit>();
    final colors = context.colors;
    final appearance = context.select<ReaderAppearanceCubit, String>(
      (c) => c.state.effectiveAppearance.themeId,
    );
    final readerTheme = ReaderThemePreset.fromId(appearance).data;

    if (!_selectionActionsVisible(sel.hasSelection)) {
      if (!highlightFocus.hasHighlight || focusedHighlight == null) {
        return const SizedBox.shrink();
      }
      return Positioned.fill(
        child: _SavedHighlightPopup(
          position: highlightFocus.position,
          selectedColor: focusedHighlight.color,
          readerTheme: readerTheme,
          panelColor: colors.surface,
          destructiveColor: Theme.of(context).colorScheme.error,
          dividerColor: colors.outlineVariant,
          onDismiss: highlightFocusCubit.clear,
          onColorChanged: (color) {
            if (color == focusedHighlight.color) return;
            bloc.add(
              ReaderHighlightColorChangeRequested(
                highlightId: focusedHighlight.id,
                color: color,
              ),
            );
          },
          onDelete: () {
            highlightFocusCubit.clear();
            bloc.add(
              ReaderHighlightDeleteRequested(
                highlightId: focusedHighlight.id,
              ),
            );
            showToast(
              context,
              type: NotificationType.success,
              message: 'Highlight removed',
            );
          },
        ),
      );
    }

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
      progress: sel.progress,
      chapterTitle: sel.chapterTitle,
    );
    final highlightAction = _highlightActionFor(textActions);

    void showHighlightPreview(HighlightColor color) {
      final cfiRange = sel.cfiRange;
      if (cfiRange == null || cfiRange.isEmpty) return;
      webViewKey.currentState?.showSelectionHighlightPreview(
        cfiRange: cfiRange,
        color: readerHighlightCssColor(color, readerTheme),
        opacity: readerHighlightOpacity(readerTheme),
        mixBlendMode: readerHighlightBlendMode(readerTheme),
      );
    }

    void clearHighlightPreview() {
      webViewKey.currentState?.clearSelectionHighlightPreview();
    }

    void dismissSelection() {
      selectionCubit.deselect();
      highlightFocusCubit.clear();
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
          readerTheme: readerTheme,
          panelColor: colors.surface,
          foregroundColor: colors.onSurface,
          dividerColor: colors.outlineVariant,
          onPreviewColorChanged: showHighlightPreview,
          onPreviewCleared: clearHighlightPreview,
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

Highlight? _focusedHighlightById(List<Highlight> highlights, String? id) {
  if (id == null || id.isEmpty) return null;
  for (final highlight in highlights) {
    if (highlight.id == id) return highlight;
  }
  return null;
}

double _highlightPopupLeft({
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

double _highlightPopupTop({
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
  final aboveTop = selectionTop - _kHighlightPopupHeight - _kHighlightPopupGap;
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

/// Compact floating edit menu for an already saved highlight.
class _SavedHighlightPopup extends StatelessWidget {
  const _SavedHighlightPopup({
    required this.selectedColor,
    required this.readerTheme,
    required this.panelColor,
    required this.destructiveColor,
    required this.dividerColor,
    required this.onDismiss,
    required this.onColorChanged,
    required this.onDelete,
    this.position,
  });

  final ReaderSelectionPosition? position;
  final HighlightColor selectedColor;
  final ReaderThemeData readerTheme;
  final Color panelColor;
  final Color destructiveColor;
  final Color dividerColor;
  final VoidCallback onDismiss;
  final ValueChanged<HighlightColor> onColorChanged;
  final VoidCallback onDelete;

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
        final left = _highlightPopupLeft(
          constraints: constraints,
          horizontalInset: horizontalInset,
          width: width,
          position: position,
        );
        final top = _highlightPopupTop(
          constraints: constraints,
          mediaPadding: mediaPadding,
          position: position,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onDismiss,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: width,
              height: _kHighlightPopupHeight,
              child: _HighlightPopupSurface(
                selectedColor: selectedColor,
                saving: false,
                readerTheme: readerTheme,
                panelColor: panelColor,
                actionColor: destructiveColor,
                actionIcon: AppIcons.delete,
                actionTooltip: 'Remove highlight',
                dividerColor: dividerColor,
                onColorChanged: onColorChanged,
                onAction: onDelete,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Compact floating highlight menu anchored to the active WebView selection.
class _HighlightSelectionPopup extends StatefulWidget {
  const _HighlightSelectionPopup({
    required this.action,
    required this.selection,
    required this.readerTheme,
    required this.panelColor,
    required this.foregroundColor,
    required this.dividerColor,
    required this.onPreviewColorChanged,
    required this.onPreviewCleared,
    required this.onDismiss,
    required this.onActionCompleted,
    required this.onActionError,
    this.selectionPosition,
  });

  final ColorHighlightTextAction action;
  final TextSelectionContext selection;
  final ReaderSelectionPosition? selectionPosition;
  final ReaderThemeData readerTheme;
  final Color panelColor;
  final Color foregroundColor;
  final Color dividerColor;
  final ValueChanged<HighlightColor> onPreviewColorChanged;
  final VoidCallback onPreviewCleared;
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

  @override
  void initState() {
    super.initState();
    widget.onPreviewColorChanged(_selectedColor);
  }

  @override
  void didUpdateWidget(covariant _HighlightSelectionPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection.cfiRange != widget.selection.cfiRange) {
      _selectedColor = HighlightColor.yellow;
      widget.onPreviewColorChanged(_selectedColor);
      return;
    }
    if (oldWidget.readerTheme != widget.readerTheme) {
      widget.onPreviewColorChanged(_selectedColor);
    }
  }

  @override
  void dispose() {
    widget.onPreviewCleared();
    super.dispose();
  }

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
        final left = _highlightPopupLeft(
          constraints: constraints,
          horizontalInset: horizontalInset,
          width: width,
          position: widget.selectionPosition,
        );
        final top = _highlightPopupTop(
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
                readerTheme: widget.readerTheme,
                panelColor: widget.panelColor,
                actionColor: widget.foregroundColor,
                actionIcon: AppIcons.highlight,
                actionTooltip: 'Highlight',
                dividerColor: widget.dividerColor,
                onColorChanged: (color) {
                  if (_saving || _selectedColor == color) return;
                  setState(() => _selectedColor = color);
                  widget.onPreviewColorChanged(color);
                },
                onAction: _save,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightPopupSurface extends StatelessWidget {
  const _HighlightPopupSurface({
    required this.selectedColor,
    required this.saving,
    required this.readerTheme,
    required this.panelColor,
    required this.actionColor,
    required this.actionIcon,
    required this.actionTooltip,
    required this.dividerColor,
    required this.onColorChanged,
    required this.onAction,
  });

  final HighlightColor selectedColor;
  final bool saving;
  final ReaderThemeData readerTheme;
  final Color panelColor;
  final Color actionColor;
  final IconData actionIcon;
  final String actionTooltip;
  final Color dividerColor;
  final ValueChanged<HighlightColor> onColorChanged;
  final VoidCallback onAction;

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
          padding: const EdgeInsets.symmetric(
            horizontal: _kHighlightPopupHorizontalPadding,
          ),
          child: Row(
            children: [
              for (final color in HighlightColor.values)
                _HighlightColorButton(
                  color: color,
                  readerTheme: readerTheme,
                  selected: selectedColor == color,
                  enabled: !saving,
                  onPressed: () => onColorChanged(color),
                ),
              SizedBox(
                height: AppSizes.chipHeight,
                child: VerticalDivider(
                  color: dividerColor,
                  thickness: 1,
                  width: _kHighlightPopupDividerWidth,
                ),
              ),
              SizedBox(
                width: _kHighlightSwatchTapSize,
                height: _kHighlightSwatchTapSize,
                child: Tooltip(
                  message: actionTooltip,
                  child: InkResponse(
                    radius: _kHighlightSwatchTapSize / 2,
                    onTap: saving ? null : onAction,
                    child: Center(
                      child: saving
                          ? const ButtonLoadingIndicator(size: AppIconSize.sm)
                          : Icon(
                              actionIcon,
                              size: AppIconSize.sm,
                              color: actionColor,
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
    required this.readerTheme,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final HighlightColor color;
  final ReaderThemeData readerTheme;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final swatch = readerHighlightColor(color, readerTheme);
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
