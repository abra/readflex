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
    this.onBack,
    this.backLabel,
    this.trailing,
    this.padding = EdgeInsets.zero,
    super.key,
  }) : assert(onClose == null || closeLabel != null),
       assert(onBack == null || backLabel != null);

  final String title;
  final VoidCallback? onClose;
  final String? closeLabel;
  final VoidCallback? onBack;
  final String? backLabel;
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
    final backOutset = backLabel == null
        ? 0.0
        : math.min(
            iconInset,
            direction == TextDirection.ltr ? insets.left : insets.right,
          );
    final effectivePadding = switch (direction) {
      TextDirection.ltr => insets.copyWith(
        left: insets.left - backOutset,
        right: insets.right - closeOutset,
      ),
      TextDirection.rtl => insets.copyWith(
        left: insets.left - closeOutset,
        right: insets.right - backOutset,
      ),
    };
    final heading = Semantics(
      header: true,
      child: Text(title, style: context.text.titleMedium),
    );
    final back = AppPlainIconButton(
      icon: direction == TextDirection.rtl
          ? AppIcons.chevronRight
          : AppIcons.chevronLeft,
      tooltip: backLabel ?? '',
      onPressed: onBack,
    );
    final close = AppPlainIconButton(
      icon: AppIcons.close,
      tooltip: closeLabel ?? '',
      onPressed: onClose,
    );
    final row = Row(
      children: [
        if (backLabel != null) ...[
          back,
          const SizedBox(width: AppSpacing.sm),
        ],
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
          SizedBox(width: closeOutset),
          close,
        ],
      ],
    );
    return Padding(
      padding: effectivePadding,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.buttonHeight),
        child: backLabel == null || trailing != null
            ? row
            : LayoutBuilder(
                builder: (context, constraints) {
                  final painter = TextPainter(
                    text: TextSpan(
                      text: title,
                      style: context.text.titleMedium,
                    ),
                    textDirection: direction,
                    textScaler: MediaQuery.textScalerOf(context),
                    locale: Localizations.maybeLocaleOf(context),
                  )..layout();
                  final wordWidth = painter.minIntrinsicWidth;
                  painter.dispose();
                  final titleWidth =
                      constraints.maxWidth -
                      AppSizes.buttonHeight -
                      AppSpacing.sm -
                      (closeLabel == null
                          ? 0
                          : AppSizes.buttonHeight + closeOutset);
                  if (wordWidth <= titleWidth) return row;
                  // Keep large localized words intact without reducing text scale.
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          back,
                          const Spacer(),
                          if (closeLabel != null) close,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                          start: backOutset,
                          end: closeOutset,
                        ),
                        child: heading,
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
