import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';

class AppSlider extends StatelessWidget {
  const AppSlider({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.onChangeStart,
    this.onChangeEnd,
    this.activeColor,
    this.label,
    this.semanticsLabel,
    this.tapToSeek = false,
    super.key,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double>? onChangeStart;
  final ValueChanged<double>? onChangeEnd;
  final Color? activeColor;
  final String? label;
  final String? semanticsLabel;

  /// Allows direct track taps for navigation controls such as reading progress.
  /// Cupertino's default thumb dragging remains unchanged otherwise.
  final bool tapToSeek;

  @override
  Widget build(BuildContext context) {
    Widget slider;
    if (context.isCupertino) {
      slider = cupertino.CupertinoSlider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        activeColor: activeColor,
      );
      if (tapToSeek) {
        slider = _CupertinoSliderTrackTap(
          onSeek: onChanged == null || min == max
              ? null
              : (fraction) {
                  if (divisions != null) {
                    fraction = (fraction * divisions!).round() / divisions!;
                  }
                  final nextValue = min + fraction * (max - min);
                  onChangeStart?.call(value);
                  onChanged!(nextValue);
                  onChangeEnd?.call(nextValue);
                },
          child: slider,
        );
      }
    } else {
      slider = material.Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
        divisions: divisions,
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
        activeColor: activeColor,
        label: label,
      );
    }
    return Semantics(
      label: semanticsLabel,
      child: SizedBox(height: 48, width: double.infinity, child: slider),
    );
  }
}

class _CupertinoSliderTrackTap extends StatelessWidget {
  const _CupertinoSliderTrackTap({required this.onSeek, required this.child});

  final ValueChanged<double>? onSeek;
  final Widget child;

  // Cupertino's track has 8dp end padding; the thumb center stops one radius
  // inside it. Geometry tests guard this contract against SDK changes.
  static const _thumbInset = 8 + cupertino.CupertinoThumbPainter.radius;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTapUp: onSeek == null || constraints.maxWidth <= _thumbInset * 2
          ? null
          : (details) {
              var fraction =
                  ((details.localPosition.dx - _thumbInset) /
                          (constraints.maxWidth - _thumbInset * 2))
                      .clamp(0.0, 1.0);
              if (Directionality.of(context) == TextDirection.rtl) {
                fraction = 1 - fraction;
              }
              onSeek!(fraction);
            },
      child: child,
    ),
  );
}
