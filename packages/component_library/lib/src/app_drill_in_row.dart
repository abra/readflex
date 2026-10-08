import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_radius.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

/// Full-width row that opens a nested step inside a sheet or settings list.
///
/// The leading [icon] uses the accent foreground; [leading] replaces it for
/// rows whose glyph sits in a caller-styled frame such as a tinted tile.
/// [title] is `bodyMedium`
/// and the optional [subtitle] is a muted `bodySmall`. [trailing] defaults
/// to a chevron that follows the layout direction; an optional [value] is
/// shown beside that chevron and moves with it under the title when both
/// cannot share one line at the current text scale. The owning layout
/// applies the outer gutter; [padding] is inside the ripple for rows that
/// need more vertical room. The row keeps a 48dp minimum height and an
/// 8dp-radius ripple. Disabled rows mute their text and drop the ripple.
class AppDrillInRow extends StatelessWidget {
  const AppDrillInRow({
    required this.title,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.leading,
    this.subtitle,
    this.value,
    this.valueStyle,
    this.trailing,
    this.padding = EdgeInsets.zero,
    this.enabled = true,
    super.key,
  }) : assert(
         value == null || trailing == null,
         'value is rendered beside the default chevron; pass one or the other.',
       ),
       assert(
         icon == null || leading == null,
         'leading replaces the icon glyph; pass one or the other.',
       );

  final IconData? icon;

  /// Overrides the accent icon tone, for example a warning glyph.
  final Color? iconColor;

  /// Widget in the leading slot, followed by the same 12dp gap as [icon].
  /// It is decorative: the row keeps one semantics node and one tap target.
  final Widget? leading;
  final String title;
  final String? subtitle;

  /// Current setting shown before the chevron, in `onSurfaceVariant`.
  final String? value;

  /// Merged into the muted value style, e.g. a font-family preview.
  final TextStyle? valueStyle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.text;
    final isEnabled = enabled && onTap != null;
    final titleStyle = text.bodyMedium.copyWith(
      color: isEnabled ? colors.onSurface : colors.onSurfaceVariant,
    );
    final valueStyle = text.bodyMedium
        .copyWith(color: colors.onSurfaceVariant)
        .merge(this.valueStyle);
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    final leading =
        this.leading ??
        (icon == null
            ? null
            : Icon(
                icon,
                size: AppIconSize.sm,
                color:
                    iconColor ??
                    (isEnabled
                        ? context.actionForeground
                        : colors.onSurfaceVariant),
              ));
    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: titleStyle),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: text.bodySmall.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
    final chevron = Icon(
      isRtl ? AppIcons.chevronLeft : AppIcons.chevronRight,
      size: AppIconSize.sm,
      color: colors.onSurfaceVariant,
    );
    final end =
        trailing ??
        (value == null
            ? chevron
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(value!, style: valueStyle)),
                  const SizedBox(width: AppSpacing.sm),
                  chevron,
                ],
              ));

    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: isEnabled,
      label: title,
      value: subtitle ?? value,
      onTap: isEnabled ? onTap : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: padding,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppSizes.buttonHeight,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: value == null
                        ? Row(
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: AppSpacing.md),
                              end,
                            ],
                          )
                        : _ValueRowLayout(
                            title: title,
                            titleStyle: titleStyle,
                            value: value!,
                            valueStyle: valueStyle,
                            titleBlock: titleBlock,
                            end: end,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Measures the two labels once; wraps the value under the title when the
/// row cannot hold both, without intrinsic layout of the whole row.
class _ValueRowLayout extends StatelessWidget {
  const _ValueRowLayout({
    required this.title,
    required this.titleStyle,
    required this.value,
    required this.valueStyle,
    required this.titleBlock,
    required this.end,
  });

  final String title;
  final TextStyle titleStyle;
  final String value;
  final TextStyle valueStyle;
  final Widget titleBlock;
  final Widget end;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final direction = Directionality.of(context);
      var width = AppSpacing.md + AppSpacing.sm + AppIconSize.sm;
      for (final (label, style) in [(title, titleStyle), (value, valueStyle)]) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        width += painter.width;
        painter.dispose();
      }
      if (width > constraints.maxWidth) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleBlock,
            const SizedBox(height: AppSpacing.sm),
            Align(alignment: AlignmentDirectional.centerEnd, child: end),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: titleBlock),
          const SizedBox(width: AppSpacing.md),
          end,
        ],
      );
    },
  );
}
