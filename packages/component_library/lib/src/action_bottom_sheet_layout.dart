import 'package:flutter/material.dart';

import 'bottom_sheet_header.dart';
import 'theme/spacing.dart';

/// Shared shell for action-oriented bottom sheets.
///
/// Keeps sheet chrome consistent while leaving the actual form or content
/// feature-specific.
class ActionBottomSheetLayout extends StatelessWidget {
  const ActionBottomSheetLayout({
    required this.title,
    required this.onClose,
    required this.child,
    this.headerPadding = const EdgeInsets.fromLTRB(
      Spacing.large,
      Spacing.large,
      Spacing.large,
      0,
    ),
    this.bodyPadding = EdgeInsets.zero,
    this.headerSpacing = 0,
    super.key,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry bodyPadding;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: headerPadding,
              child: BottomSheetHeader(
                title: title,
                onClose: onClose,
              ),
            ),
            if (headerSpacing > 0) SizedBox(height: headerSpacing),
            Padding(
              padding: bodyPadding,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
