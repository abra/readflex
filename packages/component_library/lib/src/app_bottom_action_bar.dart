import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_shadows.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';
import 'app_bottom_safe_area.dart';

/// Thumb-friendly action bar anchored at the bottom of a screen.
///
/// Use it for route-level secondary actions that should stay reachable on
/// large phones. The bar owns the bottom safe area, surface color, and
/// horizontal rhythm; feature screens provide only the controls.
class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    required this.children,
    this.showShadow = false,
    super.key,
  });

  final List<Widget> children;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: showShadow ? AppShadows.panelUp : null,
        border: Border(
          top: BorderSide(
            color: context.appColors.divider,
            width: 1 / MediaQuery.devicePixelRatioOf(context),
          ),
        ),
      ),
      child: AppBottomSafeArea(
        child: SizedBox(
          height: AppSizes.navBarHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                for (final (index, child) in children.indexed) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.sm),
                  child,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
