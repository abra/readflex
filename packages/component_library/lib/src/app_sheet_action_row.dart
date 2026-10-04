import 'package:flutter/material.dart';

import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Full-width sheet row whose utility glyph shares the header's content edge.
/// The 48dp action target extends into the gutter, not outside the row.
class AppSheetActionRow extends StatelessWidget {
  const AppSheetActionRow({
    required this.child,
    required this.action,
    super.key,
  });

  final Widget child;
  final Widget action;

  @override
  Widget build(BuildContext context) => Padding(
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
}
