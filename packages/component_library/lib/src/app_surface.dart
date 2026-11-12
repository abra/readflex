import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' as material;

import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_motion.dart';
import 'theme/tokens/app_shadows.dart';

/// Shared app surface; only Android uses Material's painted elevation.
class AppSurface extends StatelessWidget {
  const AppSurface({
    required this.child,
    this.color,
    this.shape,
    this.borderRadius,
    this.elevation = 0,
    this.shadowColor,
    this.clipBehavior = Clip.none,
    this.transparent = false,
    super.key,
  });

  final Widget child;
  final Color? color;
  final ShapeBorder? shape;
  final BorderRadiusGeometry? borderRadius;
  final double elevation;
  final Color? shadowColor;
  final Clip clipBehavior;
  final bool transparent;

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return material.Material(
        color: color,
        type: transparent
            ? material.MaterialType.transparency
            : material.MaterialType.canvas,
        shape: shape,
        borderRadius: borderRadius,
        elevation: elevation,
        shadowColor: shadowColor,
        surfaceTintColor: const Color(0x00000000),
        clipBehavior: clipBehavior,
        child: child,
      );
    }
    final effectiveShape =
        shape ??
        RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.zero,
        );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: transparent
            ? const Color(0x00000000)
            : color ?? context.colors.surface,
        shape: effectiveShape,
        shadows: elevation > 0 ? AppShadows.popover : null,
      ),
      child: clipBehavior == Clip.none
          ? child
          : ClipPath(
              clipper: ShapeBorderClipper(shape: effectiveShape),
              clipBehavior: clipBehavior,
              child: child,
            ),
    );
  }
}

/// Custom rows/cards retain native press feedback and keyboard activation.
class AppTappable extends StatefulWidget {
  const AppTappable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
    this.onTapDown,
    this.onTapCancel,
    this.borderRadius,
    this.customBorder,
    this.splashColor,
    this.highlightColor,
    this.hoverColor,
    this.focusColor,
    this.excludeFromSemantics = false,
    super.key,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final GestureTapCallback? onDoubleTap;
  final GestureTapDownCallback? onTapDown;
  final GestureTapCancelCallback? onTapCancel;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? hoverColor;
  final Color? focusColor;
  final bool excludeFromSemantics;

  @override
  State<AppTappable> createState() => _AppTappableState();
}

class _AppTappableState extends State<AppTappable> {
  bool _pressed = false;
  bool _focused = false;

  bool get _enabled =>
      widget.onTap != null ||
      widget.onLongPress != null ||
      widget.onDoubleTap != null;

  void _press(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  void didUpdateWidget(covariant AppTappable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (!context.isCupertino) {
      return material.InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onDoubleTap: widget.onDoubleTap,
        onTapDown: widget.onTapDown,
        onTapCancel: widget.onTapCancel,
        borderRadius: widget.borderRadius,
        customBorder: widget.customBorder,
        splashColor: widget.splashColor,
        highlightColor: widget.highlightColor,
        hoverColor: widget.hoverColor,
        focusColor: widget.focusColor,
        excludeFromSemantics: widget.excludeFromSemantics,
        child: widget.child,
      );
    }
    final outline = widget.customBorder;
    final focusSide = _focused
        ? BorderSide(color: context.actionForeground, width: 2)
        : BorderSide.none;
    final focusShape = outline is OutlinedBorder
        ? outline.copyWith(side: focusSide)
        : RoundedRectangleBorder(
            borderRadius: widget.borderRadius ?? BorderRadius.zero,
            side: focusSide,
          );
    return FocusableActionDetector(
      enabled: _enabled,
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (focused) => setState(() => _focused = focused),
      child: Semantics(
        button: !widget.excludeFromSemantics,
        enabled: _enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: widget.excludeFromSemantics,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onDoubleTap: widget.onDoubleTap,
          onTapDown: _enabled
              ? (details) {
                  _press(true);
                  widget.onTapDown?.call(details);
                }
              : null,
          onTapUp: _enabled ? (_) => _press(false) : null,
          onLongPressEnd: _enabled ? (_) => _press(false) : null,
          onTapCancel: _enabled
              ? () {
                  _press(false);
                  widget.onTapCancel?.call();
                }
              : null,
          child: AnimatedOpacity(
            opacity: _pressed ? .55 : 1,
            duration: context.motion(AppMotion.quick),
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: focusShape,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class AppDivider extends StatelessWidget {
  const AppDivider({
    this.color,
    this.height,
    this.thickness,
    this.indent,
    this.endIndent,
    super.key,
  });

  final Color? color;
  final double? height;
  final double? thickness;
  final double? indent;
  final double? endIndent;

  @override
  Widget build(BuildContext context) => context.isCupertino
      ? SizedBox(
          height: (height ?? 1).clamp(thickness ?? .5, double.infinity),
          child: Center(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: indent ?? 0,
                end: endIndent ?? 0,
              ),
              child: SizedBox(
                width: double.infinity,
                height: thickness ?? .5,
                child: ColoredBox(color: color ?? context.appColors.divider),
              ),
            ),
          ),
        )
      : material.Divider(
          color: color,
          height: height,
          thickness: thickness,
          indent: indent,
          endIndent: endIndent,
        );
}
