import 'package:flutter/material.dart';

import 'theme/tokens/app_spacing.dart';

/// Bottom safe area with a minimum visual gap for fullscreen Android.
class AppBottomSafeArea extends StatelessWidget {
  const AppBottomSafeArea({
    required this.child,
    this.minimumBottom = AppSpacing.lg,
    super.key,
  });

  final Widget child;
  final double minimumBottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: minimumBottom),
      child: child,
    );
  }
}

double appBottomSafeInset(
  BuildContext context, {
  double minimumBottom = AppSpacing.lg,
}) {
  final bottom = MediaQuery.paddingOf(context).bottom;
  return bottom < minimumBottom ? minimumBottom : bottom;
}
