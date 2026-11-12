import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'library_selection_cubit.dart';

const double _controlInset = AppSpacing.xs;
const double _countStartInset = AppSpacing.xl - _controlInset;
const double _capsuleMaxWidth = 320;
const double _cancelExtent = AppSizes.floatingActionButton;
const double _collectionLabelPadding = AppSpacing.md;

/// Floating selection actions: a separate cancel FAB and a destination capsule.
///
/// The owning Scaffold supplies safe insets and bottom placement. The capsule
/// grows upwards for large text and opens collection choices in a bottom sheet.
class LibrarySelectionBar extends StatelessWidget {
  const LibrarySelectionBar({
    required this.onAddToCollection,
    required this.onDelete,
    this.onCancelSelection,
    this.busy = false,
    this.collectionPickerOpen = false,
    this.viewPadding = EdgeInsets.zero,
    super.key,
  });

  final VoidCallback onAddToCollection;
  final VoidCallback onDelete;
  final VoidCallback? onCancelSelection;
  final bool busy;
  final bool collectionPickerOpen;

  /// Original window insets, before Scaffold removes them from its FAB slot.
  final EdgeInsets viewPadding;

  /// Space scrollable Library content must leave above the selection controls.
  static double heightOf(
    BuildContext context, {
    EdgeInsets viewPadding = EdgeInsets.zero,
  }) {
    final width =
        MediaQuery.sizeOf(context).width -
        viewPadding.horizontal -
        AppSpacing.lg * 2;
    final capsuleWidth = math.min(
      _capsuleMaxWidth,
      math.max(0.0, width - _cancelExtent - AppSpacing.lg),
    );
    return _SelectionLayout.resolve(context, capsuleWidth).height;
  }

  @override
  Widget build(BuildContext context) =>
      BlocSelector<LibrarySelectionCubit, LibrarySelectionState, int>(
        selector: (state) => state.selectedIds.length,
        builder: (context, count) {
          if (count == 0) return const SizedBox.shrink();
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                MediaQuery.sizeOf(context).width -
                    viewPadding.horizontal -
                    AppSpacing.lg * 2,
                constraints.maxWidth,
              );
              final capsuleWidth = math.min(
                _capsuleMaxWidth,
                math.max(0.0, width - _cancelExtent - AppSpacing.lg),
              );
              final layout = _SelectionLayout.resolve(context, capsuleWidth);
              return SizedBox(
                width: width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CancelSelectionFab(
                      onPressed: busy
                          ? null
                          : onCancelSelection ??
                                context.read<LibrarySelectionCubit>().clear,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.bottomEnd,
                        heightFactor: 1,
                        child: SizedBox(
                          width: capsuleWidth,
                          child: _SelectionCapsule(
                            count: count,
                            busy: busy,
                            open: collectionPickerOpen,
                            layout: layout,
                            onAddToCollection: onAddToCollection,
                            onDelete: onDelete,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
}

class _SelectionLayout {
  const _SelectionLayout({
    required this.stacked,
    required this.height,
    required this.summaryHeight,
    required this.collectionHeight,
  });

  final bool stacked;
  final double height;
  final double summaryHeight;
  final double collectionHeight;

  static _SelectionLayout resolve(BuildContext context, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final labelStyle = context.text.labelLarge;
    final labelSize = labelStyle.fontSize ?? 14;
    final stacked = width < 256 || scaler.scale(labelSize) > labelSize * 1.3;
    if (!stacked) {
      return const _SelectionLayout(
        stacked: false,
        height: AppSizes.floatingActionButton,
        summaryHeight: AppSizes.buttonHeight,
        collectionHeight: AppSizes.buttonHeight,
      );
    }
    final summaryStyle = context.text.titleMedium;
    final summaryHeight = math.max(
      AppSizes.buttonHeight,
      scaler.scale(summaryStyle.fontSize ?? 18) * (summaryStyle.height ?? 1.2) +
          AppSpacing.sm,
    );
    final labelWidth = math.max(
      1.0,
      width -
          2 * _controlInset -
          2 * _collectionLabelPadding -
          AppPlainIconButton.defaultIconSizeOf(context) -
          AppSpacing.sm -
          AppIconSize.xs -
          AppSpacing.xs,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: context.l10n.libraryCollectionsTitle,
        style: labelStyle,
      ),
      textScaler: scaler,
      textDirection: Directionality.of(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: labelWidth);
    final collectionHeight = math.max(
      AppSizes.buttonHeight,
      painter.height + AppSpacing.sm * 2,
    );
    painter.dispose();
    return _SelectionLayout(
      stacked: true,
      height: 2 * _controlInset + summaryHeight + collectionHeight,
      summaryHeight: summaryHeight,
      collectionHeight: collectionHeight,
    );
  }
}

class _CancelSelectionFab extends StatelessWidget {
  const _CancelSelectionFab({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: _cancelExtent,
    child: AppFloatingCapsule(
      height: _cancelExtent,
      child: AppIconButton(
        key: const ValueKey('libraryCancelSelectionFab'),
        tooltip: context.l10n.libraryCancelSelection,
        onPressed: onPressed,
        backgroundColor: Colors.transparent,
        foregroundColor: context.colors.onSurface,
        shape: const CircleBorder(),
        minimumSize: const Size.square(_cancelExtent),
        fixedSize: const Size.square(_cancelExtent),
        icon: Icon(
          AppIcons.close,
          size: AppIconSize.md,
          color: onPressed == null
              ? context.colors.onSurface.withValues(alpha: .38)
              : null,
        ),
      ),
    ),
  );
}

class _SelectionCapsule extends StatelessWidget {
  const _SelectionCapsule({
    required this.count,
    required this.busy,
    required this.open,
    required this.layout,
    required this.onAddToCollection,
    required this.onDelete,
  });

  final int count;
  final bool busy;
  final bool open;
  final _SelectionLayout layout;
  final VoidCallback onAddToCollection;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => AppFloatingCapsule(
    key: const ValueKey('librarySelectionCapsule'),
    height: layout.height,
    child: Padding(
      padding: const EdgeInsets.all(_controlInset),
      child: layout.stacked
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: layout.summaryHeight,
                  child: Row(
                    children: [
                      const SizedBox(width: _countStartInset),
                      Expanded(child: _SelectedCount(count: count)),
                      _DeleteSelectedButton(
                        onPressed: busy || open ? null : onDelete,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: layout.collectionHeight,
                  child: _CollectionAction(
                    busy: busy,
                    open: open,
                    onPressed: busy ? null : onAddToCollection,
                  ),
                ),
              ],
            )
          : Row(
              children: [
                const SizedBox(width: _countStartInset),
                _SelectedCount(count: count),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _CollectionAction(
                    busy: busy,
                    open: open,
                    onPressed: busy ? null : onAddToCollection,
                  ),
                ),
                const SizedBox(width: _controlInset),
                _DeleteSelectedButton(
                  onPressed: busy || open ? null : onDelete,
                ),
              ],
            ),
    ),
  );
}

class _SelectedCount extends StatelessWidget {
  const _SelectedCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.librarySelectedCount(count);
    final compact = count > 999
        ? '${MaterialLocalizations.of(context).formatDecimal(999)}+'
        : MaterialLocalizations.of(context).formatDecimal(count);
    return AppTooltip(
      message: label,
      child: Semantics(
        key: const ValueKey('librarySelectedCount'),
        label: label,
        liveRegion: true,
        excludeSemantics: true,
        child: Text(
          compact,
          style: context.text.titleMedium,
          softWrap: false,
        ),
      ),
    );
  }
}

class _CollectionAction extends StatelessWidget {
  const _CollectionAction({
    required this.busy,
    required this.open,
    required this.onPressed,
  });

  final bool busy;
  final bool open;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AppTooltip(
    message: context.l10n.libraryAddToCollection,
    child: Semantics(
      expanded: open,
      child: AppButton.text(
        key: const ValueKey('libraryAddToCollectionButton'),
        onPressed: onPressed,

        minimumSize: const Size(0, AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: _collectionLabelPadding,
          vertical: AppSpacing.sm,
        ),
        textStyle: context.text.labelLarge,
        foregroundColor: open
            ? context.colors.selectedControlForeground
            : context.colors.onSurface,
        backgroundColor: open ? context.colors.selectedControlBackground : null,
        shape: const StadiumBorder(),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              SizedBox.square(
                dimension: AppPlainIconButton.defaultIconSizeOf(context),
                child: const AppProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                AppIcons.collectionAdd,
                size: AppPlainIconButton.defaultIconSizeOf(context),
              ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                context.l10n.libraryCollectionsTitle,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              open ? AppIcons.chevronUp : AppIcons.chevronDown,
              size: AppIconSize.xs,
            ),
          ],
        ),
      ),
    ),
  );
}

class _DeleteSelectedButton extends StatelessWidget {
  const _DeleteSelectedButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppIconButton(
      key: const ValueKey('libraryDeleteSelectedButton'),
      onPressed: onPressed,
      tooltip: context.l10n.commonDelete,

      foregroundColor: colors.onError,
      backgroundColor: colors.error,
      disabledForegroundColor: colors.onSurface.withValues(alpha: .38),
      disabledBackgroundColor: colors.onSurface.withValues(alpha: .12),
      fixedSize: const Size.square(AppSizes.buttonHeight),
      minimumSize: const Size.square(AppSizes.buttonHeight),
      padding: EdgeInsets.zero,
      shape: const CircleBorder(),

      icon: const Icon(AppIcons.delete, size: AppIconSize.md),
    );
  }
}
