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

/// Overlay extent, including large text and bottom system insets. Used to
/// describe the covered band to the WebView, never to resize its content.
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

  // Only the row padding differs from the themed text button; press feedback
  // stays the theme's ink.
  static ButtonStyle _textActionStyle(EdgeInsets padding) =>
      TextButton.styleFrom(padding: padding);

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
              // The trailing Close target extends into the gutter so its glyph
              // ends on 16 like the return row's percentage.
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.sm,
                0,
                AppSpacing.lg - AppSizes.iconActionOutset,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('reader-search-reopen'),
                      style: _textActionStyle(
                        const EdgeInsets.all(AppSpacing.sm),
                      ),
                      onPressed: onOpenSearch,
                      child: Row(
                        children: [
                          // Muted like the counter; only the return row is
                          // accent-coloured.
                          Icon(
                            AppIcons.search,
                            size: AppIconSize.sm,
                            color: context.colors.onSurfaceVariant,
                          ),
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
                          color: context.actionForeground,
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
  }) => AppPlainIconButton(tooltip: label, onPressed: onPressed, icon: icon);
}
