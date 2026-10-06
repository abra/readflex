import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_icon_size.dart';
import 'theme/tokens/app_motion.dart';
import 'theme/tokens/app_sizes.dart';

/// Round color sample with a 48dp target, used by highlight palettes.
///
/// The visible circle is [size] wide and sits centered in an
/// [AppSizes.buttonHeight] square with circular ink. Selection thickens the
/// `onSurface` ring and draws a check whose ink is `onLightSwatch` or
/// `onDarkSwatch`, chosen by the sample's luminance so it stays visible on
/// pale yellow and deep purple alike. The ring and check settle in one frame
/// under reduced motion. Pass `null` [onPressed] to disable.
class AppColorSwatchButton extends StatelessWidget {
  const AppColorSwatchButton({
    required this.color,
    required this.selected,
    required this.tooltip,
    required this.onPressed,
    this.size = AppSizes.chipHeight,
    this.semanticsLabel,
    this.onTapHint,
    super.key,
  });

  final Color color;
  final bool selected;
  final String tooltip;
  final VoidCallback? onPressed;

  /// Diameter of the painted circle, not the tap target.
  final double size;

  /// Accessible name; defaults to [tooltip].
  final String? semanticsLabel;
  final String? onTapHint;

  /// Ring alpha for the selected and resting states.
  static const selectedRingAlpha = 0.42;
  static const restingRingAlpha = 0.16;

  /// Luminance above which the check uses the light-swatch ink.
  static const lightSwatchLuminance = 0.5;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final appColors = context.appColors;
    final checkColor = color.computeLuminance() > lightSwatchLuminance
        ? appColors.onLightSwatch
        : appColors.onDarkSwatch;
    final ringColor = context.colors.onSurface.withValues(
      alpha: selected ? selectedRingAlpha : restingRingAlpha,
    );
    return Semantics(
      label: semanticsLabel ?? tooltip,
      button: true,
      enabled: enabled,
      selected: selected,
      onTapHint: onTapHint,
      excludeSemantics: true,
      onTap: onPressed,
      child: SizedBox.square(
        dimension: AppSizes.buttonHeight,
        child: Tooltip(
          message: tooltip,
          excludeFromSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: AnimatedContainer(
                  duration: context.motion(AppMotion.quick),
                  curve: Curves.easeOutCubic,
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          AppIcons.check,
                          size: AppIconSize.xs,
                          color: checkColor,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
