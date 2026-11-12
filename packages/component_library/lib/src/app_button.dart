import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_sizes.dart';
import 'theme/tokens/app_spacing.dart';

enum AppButtonVariant { filled, tonal, outlined, text }

enum AppIconAlignment { start, end }

/// An app action with platform presentation and shared command semantics.
class AppButton extends StatelessWidget {
  /// The normal action typography for width/height measurements.
  static TextStyle textStyleOf(
    BuildContext context, {
    AppButtonVariant variant = AppButtonVariant.filled,
  }) {
    if (context.isCupertino) {
      return cupertino.CupertinoTheme.of(context).textTheme.actionTextStyle;
    }
    final style = switch (variant) {
      AppButtonVariant.filled ||
      AppButtonVariant.tonal => material.FilledButtonTheme.of(context).style,
      AppButtonVariant.outlined => material.OutlinedButtonTheme.of(
        context,
      ).style,
      AppButtonVariant.text => material.TextButtonTheme.of(context).style,
    };
    return style?.textStyle?.resolve(const {}) ??
        context.theme.textTheme.labelLarge!;
  }

  const AppButton({
    required this.child,
    required this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.foregroundColor,
    this.backgroundColor,
    this.disabledForegroundColor,
    this.disabledBackgroundColor,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.textStyle,
    this.shape,
    this.side,
    this.alignment = Alignment.center,
    this.autofocus = false,
    super.key,
  });

  const AppButton.tonal({
    required Widget child,
    required VoidCallback? onPressed,
    Key? key,
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    TextStyle? textStyle,
    OutlinedBorder? shape,
    BorderSide? side,
    AlignmentGeometry alignment = Alignment.center,
    bool autofocus = false,
  }) : this(
         key: key,
         child: child,
         onPressed: onPressed,
         variant: AppButtonVariant.tonal,
         foregroundColor: foregroundColor,
         backgroundColor: backgroundColor,
         disabledForegroundColor: disabledForegroundColor,
         disabledBackgroundColor: disabledBackgroundColor,
         padding: padding,
         minimumSize: minimumSize,
         fixedSize: fixedSize,
         textStyle: textStyle,
         shape: shape,
         side: side,
         alignment: alignment,
         autofocus: autofocus,
       );

  const AppButton.outlined({
    required Widget child,
    required VoidCallback? onPressed,
    Key? key,
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    TextStyle? textStyle,
    OutlinedBorder? shape,
    BorderSide? side,
    AlignmentGeometry alignment = Alignment.center,
    bool autofocus = false,
  }) : this(
         key: key,
         child: child,
         onPressed: onPressed,
         variant: AppButtonVariant.outlined,
         foregroundColor: foregroundColor,
         backgroundColor: backgroundColor,
         disabledForegroundColor: disabledForegroundColor,
         disabledBackgroundColor: disabledBackgroundColor,
         padding: padding,
         minimumSize: minimumSize,
         fixedSize: fixedSize,
         textStyle: textStyle,
         shape: shape,
         side: side,
         alignment: alignment,
         autofocus: autofocus,
       );

  const AppButton.text({
    required Widget child,
    required VoidCallback? onPressed,
    Key? key,
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    TextStyle? textStyle,
    OutlinedBorder? shape,
    BorderSide? side,
    AlignmentGeometry alignment = Alignment.center,
    bool autofocus = false,
  }) : this(
         key: key,
         child: child,
         onPressed: onPressed,
         variant: AppButtonVariant.text,
         foregroundColor: foregroundColor,
         backgroundColor: backgroundColor,
         disabledForegroundColor: disabledForegroundColor,
         disabledBackgroundColor: disabledBackgroundColor,
         padding: padding,
         minimumSize: minimumSize,
         fixedSize: fixedSize,
         textStyle: textStyle,
         shape: shape,
         side: side,
         alignment: alignment,
         autofocus: autofocus,
       );

  AppButton.icon({
    required Widget icon,
    required Widget label,
    required VoidCallback? onPressed,
    AppButtonVariant variant = AppButtonVariant.filled,
    AppIconAlignment iconAlignment = AppIconAlignment.start,
    Key? key,
    Color? foregroundColor,
    Color? backgroundColor,
    Color? disabledForegroundColor,
    Color? disabledBackgroundColor,
    EdgeInsetsGeometry? padding,
    Size? minimumSize,
    Size? fixedSize,
    TextStyle? textStyle,
    OutlinedBorder? shape,
    BorderSide? side,
    AlignmentGeometry alignment = Alignment.center,
    bool autofocus = false,
  }) : this(
         key: key,
         child: _AppButtonIconLabel(
           icon: icon,
           label: label,
           alignment: iconAlignment,
         ),
         onPressed: onPressed,
         variant: variant,
         foregroundColor: foregroundColor,
         backgroundColor: backgroundColor,
         disabledForegroundColor: disabledForegroundColor,
         disabledBackgroundColor: disabledBackgroundColor,
         padding: padding,
         minimumSize: minimumSize,
         fixedSize: fixedSize,
         textStyle: textStyle,
         shape: shape,
         side: side,
         alignment: alignment,
         autofocus: autofocus,
       );

  final Widget child;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? disabledForegroundColor;
  final Color? disabledBackgroundColor;
  final EdgeInsetsGeometry? padding;
  final Size? minimumSize;
  final Size? fixedSize;
  final TextStyle? textStyle;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final AlignmentGeometry alignment;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final minimum = Size(
      (minimumSize?.width ?? AppSizes.buttonHeight).clamp(
        AppSizes.buttonHeight,
        double.infinity,
      ),
      (minimumSize?.height ?? AppSizes.buttonHeight).clamp(
        AppSizes.buttonHeight,
        double.infinity,
      ),
    );
    if (context.isCupertino) {
      final foreground = onPressed == null
          ? disabledForegroundColor ??
                cupertino.CupertinoColors.placeholderText.resolveFrom(context)
          : foregroundColor;
      final radius = switch (shape) {
        CircleBorder() || StadiumBorder() => BorderRadius.circular(999),
        RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(
          Directionality.of(context),
        ),
        _ => null,
      };
      final content = DefaultTextStyle.merge(style: textStyle, child: child);
      final button = switch (variant) {
        AppButtonVariant.filled => cupertino.CupertinoButton.filled(
          onPressed: onPressed,
          autofocus: autofocus,
          color: backgroundColor,
          foregroundColor: foreground,
          disabledColor:
              disabledBackgroundColor ??
              cupertino.CupertinoColors.tertiarySystemFill,
          minimumSize: minimum,
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
          borderRadius: radius,
          alignment: alignment,
          child: content,
        ),
        AppButtonVariant.tonal ||
        AppButtonVariant.outlined => cupertino.CupertinoButton.tinted(
          onPressed: onPressed,
          autofocus: autofocus,
          color: backgroundColor,
          foregroundColor: foreground,
          disabledColor:
              disabledBackgroundColor ??
              cupertino.CupertinoColors.tertiarySystemFill,
          minimumSize: minimum,
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
          borderRadius: radius,
          alignment: alignment,
          child: content,
        ),
        AppButtonVariant.text => cupertino.CupertinoButton(
          onPressed: onPressed,
          autofocus: autofocus,
          color: backgroundColor,
          foregroundColor: foreground,
          disabledColor:
              disabledBackgroundColor ??
              cupertino.CupertinoColors.quaternarySystemFill,
          minimumSize: minimum,
          padding:
              padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
          borderRadius: radius,
          alignment: alignment,
          child: content,
        ),
      };
      return MergeSemantics(
        child: Semantics(
          enabled: onPressed != null,
          child: IgnorePointer(
            ignoring: onPressed == null,
            child: fixedSize == null
                ? button
                : SizedBox.fromSize(size: fixedSize, child: button),
          ),
        ),
      );
    }
    final style = material.TextButton.styleFrom(
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
      disabledForegroundColor: disabledForegroundColor,
      disabledBackgroundColor: disabledBackgroundColor,
      minimumSize: minimum,
      fixedSize: fixedSize,
      padding: padding,
      textStyle: textStyle,
      shape: shape,
      side: side,
      alignment: alignment,
    );
    final content = child;
    if (content is _AppButtonIconLabel) {
      final iconAlignment = content.alignment == AppIconAlignment.start
          ? material.IconAlignment.start
          : material.IconAlignment.end;
      return switch (variant) {
        AppButtonVariant.filled => material.FilledButton.icon(
          onPressed: onPressed,
          autofocus: autofocus,
          style: style,
          icon: content.icon,
          label: content.label,
          iconAlignment: iconAlignment,
        ),
        AppButtonVariant.tonal => material.FilledButton.tonalIcon(
          onPressed: onPressed,
          autofocus: autofocus,
          style: style,
          icon: content.icon,
          label: content.label,
          iconAlignment: iconAlignment,
        ),
        AppButtonVariant.outlined => material.OutlinedButton.icon(
          onPressed: onPressed,
          autofocus: autofocus,
          style: style,
          icon: content.icon,
          label: content.label,
          iconAlignment: iconAlignment,
        ),
        AppButtonVariant.text => material.TextButton.icon(
          onPressed: onPressed,
          autofocus: autofocus,
          style: style,
          icon: content.icon,
          label: content.label,
          iconAlignment: iconAlignment,
        ),
      };
    }
    return switch (variant) {
      AppButtonVariant.filled => material.FilledButton(
        onPressed: onPressed,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
      AppButtonVariant.tonal => material.FilledButton.tonal(
        onPressed: onPressed,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
      AppButtonVariant.outlined => material.OutlinedButton(
        onPressed: onPressed,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
      AppButtonVariant.text => material.TextButton(
        onPressed: onPressed,
        autofocus: autofocus,
        style: style,
        child: child,
      ),
    };
  }
}

class _AppButtonIconLabel extends StatelessWidget {
  const _AppButtonIconLabel({
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Widget icon;
  final Widget label;
  final AppIconAlignment alignment;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (alignment == AppIconAlignment.start) ...[
        icon,
        const SizedBox(width: AppSpacing.sm),
      ],
      Flexible(child: label),
      if (alignment == AppIconAlignment.end) ...[
        const SizedBox(width: AppSpacing.sm),
        icon,
      ],
    ],
  );
}
