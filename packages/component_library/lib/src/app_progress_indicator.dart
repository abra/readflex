import 'dart:ui' show SemanticsRole;

import 'package:cupertino_ui/cupertino_ui.dart' as cupertino;
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';

class AppProgressIndicator extends StatelessWidget {
  const AppProgressIndicator({
    this.value,
    this.size,
    this.strokeWidth,
    this.color,
    this.semanticsLabel,
    this.semanticsValue,
    super.key,
  });

  final double? value;
  final double? size;
  final double? strokeWidth;
  final Color? color;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    if (context.isCupertino) {
      return _AppProgressSemantics(
        progress: value,
        label: semanticsLabel,
        value: semanticsValue,
        child: value == null
            ? cupertino.CupertinoActivityIndicator(
                radius: (size ?? 20) / 2,
                color: color,
              )
            : cupertino.CupertinoActivityIndicator.partiallyRevealed(
                radius: (size ?? 20) / 2,
                color: color,
                progress: value!.clamp(0, 1),
              ),
      );
    }
    final indicator = material.CircularProgressIndicator(
      value: value,
      color: color,
      strokeWidth: strokeWidth,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
    );
    return size == null
        ? indicator
        : SizedBox.square(dimension: size, child: indicator);
  }
}

class AppLinearProgressIndicator extends StatelessWidget {
  const AppLinearProgressIndicator({
    this.value,
    this.color,
    this.backgroundColor,
    this.minHeight,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
    super.key,
  });

  final double? value;
  final Color? color;
  final Color? backgroundColor;
  final double? minHeight;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return material.LinearProgressIndicator(
        value: value,
        color: color,
        backgroundColor: backgroundColor,
        minHeight: minHeight,
        borderRadius: borderRadius,
        stopIndicatorRadius: 0,
        trackGap: 0,
        semanticsLabel: semanticsLabel,
        semanticsValue: semanticsValue,
      );
    }
    if (value == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: AppProgressIndicator(
          color: color,
          semanticsLabel: semanticsLabel,
          semanticsValue: semanticsValue,
        ),
      );
    }
    return _AppProgressSemantics(
      progress: value,
      label: semanticsLabel,
      value: semanticsValue,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(999),
        child: SizedBox(
          height: minHeight ?? 4,
          child: ColoredBox(
            color:
                backgroundColor ??
                cupertino.CupertinoColors.tertiarySystemFill.resolveFrom(
                  context,
                ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: value!.clamp(0, 1),
                heightFactor: 1,
                child: ColoredBox(
                  color:
                      color ??
                      cupertino.CupertinoTheme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppProgressSemantics extends StatelessWidget {
  const _AppProgressSemantics({
    required this.progress,
    required this.child,
    this.label,
    this.value,
  });

  final double? progress;
  final Widget child;
  final String? label;
  final String? value;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    role: progress == null
        ? SemanticsRole.loadingSpinner
        : SemanticsRole.progressBar,
    minValue: progress == null ? null : '0',
    maxValue: progress == null ? null : '100',
    value:
        value ??
        (progress == null ? null : '${(progress!.clamp(0, 1) * 100).round()}'),
    child: child,
  );
}
