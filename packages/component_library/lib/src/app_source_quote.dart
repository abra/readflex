import 'package:flutter/material.dart';

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_spacing.dart';

/// Quoted source phrase with a leading rule, used above dictionary and
/// translation results.
///
/// The whole block, including the rule and its inset, follows
/// [textDirection] — the direction of the quoted text — so the rule stays on
/// the reading-start side of the quote regardless of the app locale.
class AppSourceQuote extends StatelessWidget {
  const AppSourceQuote({
    required this.textDirection,
    required this.child,
    super.key,
  });

  final TextDirection textDirection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: textDirection,
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(
            start: BorderSide(color: context.colors.onSurfaceVariant, width: 2),
          ),
        ),
        padding: const EdgeInsetsDirectional.only(
          start: AppSpacing.md,
          top: AppSpacing.xs,
          bottom: AppSpacing.xs,
        ),
        child: child,
      ),
    );
  }
}
