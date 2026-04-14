import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_radius.dart';

/// Rounded card container that renders [children] separated by dividers.
///
/// Used for grouped settings rows and similar list sections.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = context.colors;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    final divider = context.appColors.divider;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outline.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: divider),
          ],
        ],
      ),
    );
  }
}
