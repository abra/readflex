import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:material_ui/material_ui.dart';
import 'package:readflex_localizations/readflex_localizations.dart';

import 'reader_control_styles.dart';
import 'reader_drawer_layout.dart';
import 'reader_search_cubit.dart';

double _lineHeight(BuildContext context, TextStyle style) =>
    (MediaQuery.textScalerOf(context).scale(style.fontSize!) *
            (style.height ?? 1.5))
        .ceilToDouble();

double _navigationRowHeight(BuildContext context) => math.max(
  AppSizes.buttonHeight + AppSpacing.sm * 2,
  _lineHeight(context, context.text.bodyMedium) +
      _lineHeight(context, readerControlCaptionStyle(context)) +
      AppSpacing.xs +
      AppSpacing.sm * 2,
);

double _returnRowHeight(BuildContext context) =>
    math.max(48, _lineHeight(context, context.text.labelLarge) * 2 + 16);

/// Overlay extent, including large text and bottom system insets. Used to
/// describe the covered band to the page, never to resize its content.
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final origin = state.returnLocation;
    return AppSurface(
      color: context.colors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppDivider(height: 1),
          SizedBox(
            height: _navigationRowHeight(context),
            child: Padding(
              // The trailing Close target extends into the gutter so its glyph
              // ends on 16 like the return row's percentage.
              padding: EdgeInsetsDirectional.fromSTEB(
                AppSpacing.sm,
                0,
                readerDrawerActionEndPadding(context, inPanel: false),
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton.text(
                      key: const ValueKey('reader-search-reopen'),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      onPressed: onOpenSearch,
                      child: Row(
                        children: [
                          // Muted like the counter; only the return row is
                          // accent-coloured.
                          Icon(
                            AppIcons.search,
                            size: readerControlIconSize(context),
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
                                  style: readerControlCaptionStyle(context)
                                      .copyWith(
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
                  AppPlainIconButton(
                    tooltip: l10n.readerPreviousMatch,
                    icon: AppIcons.chevronUp,
                    onPressed: state.canGoPrevious ? onPrevious : null,
                  ),
                  AppPlainIconButton(
                    tooltip: l10n.readerNextMatch,
                    icon: AppIcons.chevronDown,
                    onPressed: state.canGoNext ? onNext : null,
                  ),
                  AppPlainIconButton(
                    tooltip: l10n.readerEndSearch,
                    icon: AppIcons.close,
                    onPressed: onEndSearch,
                  ),
                ],
              ),
            ),
          ),
          if (origin != null) ...[
            const AppDivider(height: 1),
            SizedBox(
              height: _returnRowHeight(context),
              width: double.infinity,
              child: AppButton.text(
                key: const ValueKey('reader-search-return'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                onPressed: onReturn,
                child: Row(
                  children: [
                    Icon(
                      AppIcons.returnToReading,
                      size: readerControlIconSize(context),
                    ),
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
                      style: readerControlCaptionStyle(context).copyWith(
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
}
