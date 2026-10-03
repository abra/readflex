import 'package:flutter/material.dart';

import 'bottom_sheet_header.dart';
import 'scroll_edge_fade_stack.dart';
import 'theme/tokens/app_spacing.dart';

/// Canonical title-and-body shell for bottom sheets.
///
/// Use this as the root of your sheet content (the [WidgetBuilder]
/// passed to `showAppBottomSheet`) and the visual rhythm — title
/// typography, horizontal gutter, gap between header and body,
/// bottom inset — comes for free and matches every other sheet in
/// the app. Drag handle, keyboard offset, and the bottom safe area
/// are owned by `showAppBottomSheet` itself, so this widget only
/// concerns itself with what's *inside* the sheet.
class ActionBottomSheetLayout extends StatelessWidget {
  const ActionBottomSheetLayout({
    required this.title,
    required this.child,
    this.headerTrailing,
    this.onClose,
    this.closeLabel,
    this.headerPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      0,
    ),
    this.bodyPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      0,
      AppSpacing.xl,
      AppSpacing.lg,
    ),
    this.headerSpacing = AppSpacing.sm,
    this.constrainBody = false,
    this.footer,
    this.footerPadding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.sm,
      AppSpacing.xl,
      AppSpacing.lg,
    ),
    super.key,
  }) : _scrollable = false,
       headerBottom = null,
       assert(footer == null || constrainBody);

  /// Content-sized sheet with a pinned header and one full-width viewport.
  /// Pass non-scrolling content as [child]. Lazy lists and staged forms use the
  /// default constructor to retain their own viewport and footer contracts.
  const ActionBottomSheetLayout.scrollable({
    required this.title,
    required this.child,
    this.headerTrailing,
    this.onClose,
    this.closeLabel,
    this.headerBottom,
    super.key,
  }) : _scrollable = true,
       constrainBody = true,
       headerPadding = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
       bodyPadding = const EdgeInsets.fromLTRB(
         AppSpacing.xl,
         0,
         AppSpacing.xl,
         AppSpacing.lg,
       ),
       headerSpacing = AppSpacing.sm,
       footer = null,
       footerPadding = EdgeInsets.zero;

  final bool _scrollable;

  /// Persistent context, such as translation direction, below the title.
  final Widget? headerBottom;

  final String title;
  final Widget child;
  final Widget? headerTrailing;
  final VoidCallback? onClose;
  final String? closeLabel;

  /// Visual gutters for the title and close icon. Default: 24 dp on each side, 0 on
  /// the top (the wrapper's drag handle already provides spacing
  /// above) and 0 on the bottom (the gap to the body comes from
  /// [headerSpacing]).
  final EdgeInsetsGeometry headerPadding;

  /// Insets around the body [child]. Default: 24 dp on each side and
  /// 16 dp on the bottom for breathing room above the home-indicator
  /// safe area.
  final EdgeInsetsGeometry bodyPadding;

  /// Vertical gap between the title row and the body. Default 8 dp.
  final double headerSpacing;

  /// Keep the header visible and give the body the remaining height.
  /// Requires bounded vertical constraints and a scrollable body.
  final bool constrainBody;

  /// Pinned actions below the header/body group. Requires [constrainBody].
  /// With a minimum sheet height, spare space stays above these actions.
  final Widget? footer;

  /// Insets around [footer], independent of [bodyPadding].
  final EdgeInsetsGeometry footerPadding;

  @override
  Widget build(BuildContext context) {
    final header = BottomSheetHeader(
      title: title,
      onClose: onClose,
      closeLabel: closeLabel,
      trailing: headerTrailing,
      padding: headerPadding,
    );

    final body = _scrollable
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight:
                  MediaQuery.sizeOf(context).height *
                  (MediaQuery.textScalerOf(context).scale(14) > 20 ? .78 : .72),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (headerBottom != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: headerBottom,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Flexible(
                  child: ScrollEdgeFadeStack(
                    child: SingleChildScrollView(
                      padding: bodyPadding,
                      child: SizedBox(width: double.infinity, child: child),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Padding(padding: bodyPadding, child: child);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        if (headerSpacing > 0) SizedBox(height: headerSpacing),
        if (constrainBody) Flexible(child: body) else body,
      ],
    );

    if (footer == null) return content;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(child: content),
        Padding(padding: footerPadding, child: footer),
      ],
    );
  }
}
