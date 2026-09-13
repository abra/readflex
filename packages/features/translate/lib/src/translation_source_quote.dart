import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

class TranslationSourceQuote extends StatelessWidget {
  const TranslationSourceQuote({
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
