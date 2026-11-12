import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'app_tooltip.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_sizes.dart';

/// A named icon action with a consistent accessible target.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.foregroundColor,
    this.backgroundColor,
    this.disabledForegroundColor,
    this.disabledBackgroundColor,
    this.padding,
    this.minimumSize,
    this.fixedSize,
    this.shape,
    this.iconSize,
    super.key,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? disabledForegroundColor;
  final Color? disabledBackgroundColor;
  final EdgeInsetsGeometry? padding;
  final Size? minimumSize;
  final Size? fixedSize;
  final OutlinedBorder? shape;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final minimum = Size(
      (minimumSize?.width ?? 48).clamp(AppSizes.buttonHeight, double.infinity),
      (minimumSize?.height ?? 48).clamp(AppSizes.buttonHeight, double.infinity),
    );
    if (!context.isCupertino) {
      return material.IconButton(
        icon: icon,
        iconSize: iconSize,
        tooltip: tooltip,
        onPressed: onPressed,
        style: material.IconButton.styleFrom(
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
          disabledForegroundColor: disabledForegroundColor,
          disabledBackgroundColor: disabledBackgroundColor,
          padding: padding,
          minimumSize: minimum,
          fixedSize: fixedSize,
          shape: shape,
          visualDensity: material.VisualDensity.standard,
        ),
      );
    }
    final enabled = onPressed != null;
    final foreground = enabled
        ? foregroundColor ?? cupertino.CupertinoTheme.of(context).primaryColor
        : disabledForegroundColor ??
              cupertino.CupertinoColors.placeholderText.resolveFrom(context);
    final radius = switch (shape) {
      CircleBorder() || StadiumBorder() => BorderRadius.circular(999),
      RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(
        Directionality.of(context),
      ),
      _ => BorderRadius.circular(999),
    };
    final button = cupertino.CupertinoButton(
      onPressed: onPressed,
      color: backgroundColor,
      disabledColor:
          disabledBackgroundColor ??
          (backgroundColor == null || backgroundColor!.a == 0
              ? const Color(0x00000000)
              : cupertino.CupertinoColors.quaternarySystemFill),
      foregroundColor: foreground,
      padding: padding ?? EdgeInsets.zero,
      minimumSize: minimum,
      borderRadius: radius,
      child: IconTheme.merge(
        data: IconThemeData(color: foreground, size: iconSize),
        child: icon,
      ),
    );
    return Semantics(
      tooltip: tooltip,
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      onTap: onPressed,
      child: AppTooltip(
        message: tooltip,
        child: fixedSize == null
            ? button
            : SizedBox.fromSize(size: fixedSize, child: button),
      ),
    );
  }
}
