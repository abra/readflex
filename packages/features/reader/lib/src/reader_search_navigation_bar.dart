import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_search_cubit.dart';

double _lineHeight(BuildContext context, TextStyle style) =>
    (MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            (style.height ?? 1.5))
        .ceilToDouble();

double _navigationRowHeight(BuildContext context) => math.max(
  AppSizes.buttonHeight + AppSpacing.sm * 2,
  _lineHeight(context, context.text.bodyMedium) +
      _lineHeight(context, context.text.labelSmall) +
      AppSpacing.xs +
      AppSpacing.sm * 2,
);

double _returnRowHeight(BuildContext context) =>
    math.max(48, _lineHeight(context, context.text.labelLarge) * 2 + 16);

/// The same extent reserves content space and sizes the controls, including
/// large text and bottom system insets. It changes only at session boundaries.
double readerSearchNavigationHeight(
  BuildContext context, {
  required bool canReturn,
}) =>
    _navigationRowHeight(context) +
    (canReturn ? _returnRowHeight(context) + 1 : 0) +
    appBottomSafeInset(context) +
    1;

class ReaderSearchNavigationBar extends StatelessWidget {
  const ReaderSearchNavigationBar({
    required this.state,
    required this.onOpenSearch,
    required this.onPrevious,
    required this.onNext,
    required this.onEndSearch,
    required this.onReturn,
    super.key,
  });

  final ReaderSearchState state;
  final VoidCallback onOpenSearch;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onEndSearch;
  final VoidCallback onReturn;

  static const _actionStyle = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(Colors.transparent),
    shape: WidgetStatePropertyAll(CircleBorder()),
  );

  ButtonStyle _textActionStyle(BuildContext context, EdgeInsets padding) {
    final focusColor = context.colors.brightness == Brightness.dark
        ? context.colors.primaryFixedDim
        : context.colors.primary;
    return ButtonStyle(
      padding: WidgetStatePropertyAll(padding),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      splashFactory: NoSplash.splashFactory,
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? BorderSide(color: focusColor, width: 1.5)
            : BorderSide.none,
      ),
      foregroundBuilder: (_, states, child) => Opacity(
        opacity: states.contains(WidgetState.pressed)
            ? 0.6
            : states.contains(WidgetState.hovered)
            ? 0.8
            : 1,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final origin = state.returnLocation;
    return Material(
      color: context.colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Divider(height: 1),
          SizedBox(
            height: _navigationRowHeight(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('reader-search-reopen'),
                      style: _textActionStyle(
                        context,
                        const EdgeInsets.all(AppSpacing.sm),
                      ),
                      onPressed: onOpenSearch,
                      child: Row(
                        children: [
                          const Icon(AppIcons.search, size: AppIconSize.sm),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.query,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodyMedium,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  l10n.readerSearchMatchPosition(
                                    (state.activeResultIndex ?? -1) + 1,
                                    state.results.length,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.labelSmall.copyWith(
                                    color: context.colors.onSurfaceVariant,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _action(
                    label: l10n.readerPreviousMatch,
                    icon: AppIcons.chevronUp,
                    onPressed: state.canGoPrevious ? onPrevious : null,
                  ),
                  _action(
                    label: l10n.readerNextMatch,
                    icon: AppIcons.chevronDown,
                    onPressed: state.canGoNext ? onNext : null,
                  ),
                  _action(
                    label: l10n.readerEndSearch,
                    icon: AppIcons.close,
                    onPressed: onEndSearch,
                  ),
                ],
              ),
            ),
          ),
          if (origin != null) ...[
            const Divider(height: 1),
            SizedBox(
              height: _returnRowHeight(context),
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('reader-search-return'),
                style: _textActionStyle(
                  context,
                  const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onPressed: onReturn,
                child: Row(
                  children: [
                    const Icon(AppIcons.returnToReading, size: AppIconSize.sm),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.readerBackToReading,
                        maxLines: 2,
                        style: context.text.labelLarge.copyWith(
                          color: context.colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      '${(origin.fraction.clamp(0, 1) * 100).round()}%',
                      style: context.text.labelSmall.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: appBottomSafeInset(context)),
        ],
      ),
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) => SizedBox.square(
    dimension: AppSizes.buttonHeight,
    child: IconButton(
      style: _actionStyle,
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon, size: AppIconSize.sm),
    ),
  );
}
