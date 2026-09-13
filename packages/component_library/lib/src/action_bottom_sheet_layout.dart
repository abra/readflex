import 'package:flutter/material.dart';

import 'bottom_sheet_header.dart';
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
    this.headerSpacing = AppSpacing.lg,
    this.constrainBody = false,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? headerTrailing;

  /// Insets around the title row. Default: 24 dp on each side, 0 on
  /// the top (the wrapper's drag handle already provides spacing
  /// above) and 0 on the bottom (the gap to the body comes from
  /// [headerSpacing]).
  final EdgeInsetsGeometry headerPadding;

  /// Insets around the body [child]. Default: 24 dp on each side and
  /// 16 dp on the bottom for breathing room above the home-indicator
  /// safe area.
  final EdgeInsetsGeometry bodyPadding;

  /// Vertical gap between the title row and the body. Default 16 dp.
  final double headerSpacing;

  /// Keep the header visible and give the body the remaining height.
  /// Requires bounded vertical constraints and a scrollable body.
  final bool constrainBody;

  @override
  Widget build(BuildContext context) {
    final header = headerTrailing == null
        ? BottomSheetHeader(title: title)
        : OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.start,
            spacing: AppSpacing.md,
            overflowSpacing: AppSpacing.xs,
            children: [
              BottomSheetHeader(title: title),
              headerTrailing!,
            ],
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: headerPadding,
          child: header,
        ),
        if (headerSpacing > 0) SizedBox(height: headerSpacing),
        if (constrainBody)
          Flexible(
            child: Padding(padding: bodyPadding, child: child),
          )
        else
          Padding(padding: bodyPadding, child: child),
      ],
    );
  }
}
