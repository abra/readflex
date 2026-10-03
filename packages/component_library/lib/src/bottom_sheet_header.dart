import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'app_plain_icon_button.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Sheet title with an optional explicit close action.
class BottomSheetHeader extends StatelessWidget {
  const BottomSheetHeader({
    required this.title,
    this.onClose,
    this.closeLabel,
    this.trailing,
    this.padding = EdgeInsets.zero,
    super.key,
  }) : assert(onClose == null || closeLabel != null);

  final String title;
  final VoidCallback? onClose;
  final String? closeLabel;
  final Widget? trailing;

  /// Gutters for the title and close icon, not the close button's hit target.
  /// The target extends into the trailing gutter where space is available.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final insets = padding.resolve(direction);
    const iconInset = (AppSizes.buttonHeight - AppIconSize.sm) / 2;
    final closeOutset = closeLabel == null
        ? 0.0
        : math.min(
            iconInset,
            direction == TextDirection.ltr ? insets.right : insets.left,
          );
    final effectivePadding = switch (direction) {
      TextDirection.ltr => insets.copyWith(right: insets.right - closeOutset),
      TextDirection.rtl => insets.copyWith(left: insets.left - closeOutset),
    };
    final heading = Semantics(
      header: true,
      child: Text(title, style: context.text.titleMedium),
    );
    return Padding(
      padding: effectivePadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        child: Row(
          children: [
            Expanded(
              child: trailing == null
                  ? heading
                  : OverflowBar(
                      alignment: MainAxisAlignment.spaceBetween,
                      overflowAlignment: OverflowBarAlignment.start,
                      spacing: AppSpacing.md,
                      overflowSpacing: AppSpacing.xs,
                      children: [heading, trailing!],
                    ),
            ),
            if (closeLabel != null) ...[
              // Preserve title wrapping and trailing-action placement.
              SizedBox(width: closeOutset),
              AppPlainIconButton(
                icon: AppIcons.close,
                tooltip: closeLabel!,
                onPressed: onClose,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
