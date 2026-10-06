import 'package:flutter/material.dart';

import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Full-width sheet row whose utility glyph shares the header's content edge.
/// The 48dp action target extends into the gutter, not outside the row.
///
/// [textDirection] lets the row follow its content rather than the app
/// locale: an LTR answer in an RTL interface keeps its copy action trailing
/// the text it copies instead of leading it.
class AppSheetActionRow extends StatelessWidget {
  const AppSheetActionRow({
    required this.child,
    required this.action,
    this.textDirection,
    super.key,
  });

  final Widget child;
  final Widget action;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.xl,
        end: AppSpacing.xl - (AppSizes.buttonHeight - AppIconSize.sm) / 2,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child),
          action,
        ],
      ),
    );
    final direction = textDirection;
    if (direction == null) return row;
    return Directionality(textDirection: direction, child: row);
  }
}
