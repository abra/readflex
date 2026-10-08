import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_inline_sheet_geometry.dart';
import 'app_sheet_drag_handle.dart';
import 'theme/extensions/build_context_ext.dart';
import 'theme/tokens/app_motion.dart';
import 'theme/tokens/app_radius.dart';

/// Material's bottom sheet width limit, so tablets get a centered sheet.
const double _kMaxWidth = 640;

/// A release faster than this (logical pixels per second) moves one rest
/// position in its direction, whatever the distance dragged.
const double _kFlingVelocity = 700;

/// A slow release below this position closes the sheet.
const double _kClosePosition = 0.5;

/// Pulling a list this far past its top steps the sheet down.
const double _kPullToCollapseDistance = 64;

const double _kRestTolerance = 0.001;

/// A bottom sheet drawn inside the current screen's [Stack] instead of pushed
/// as a route, for panels whose content must survive being closed: search
/// queries, scroll offsets, tab state. Place it as a full-size child, e.g. in
/// [Positioned.fill].
///
/// It opens at 60% of the height above the keyboard so its header lands in
/// the middle of the screen, and grows to just below the status bar; on short
/// screens and with large text it opens at full ([AppInlineSheetGeometry]). The grab handle and [header] drag it; in
/// [body], scrolling forward from half grows it and pulling a list down past
/// its top steps it down. A non-scrolling body drags like the header.
///
/// Dumb by design: a tap on the scrim, a downward fling from half and a pull
/// past the top call [onClose], and the owner closes the sheet by setting
/// [visible] to false. If the owner keeps it open, it settles back at half.
///
/// The sheet sits on the keyboard and hands [body] a [MediaQuery] without
/// the keyboard inset, so lists pad only for the visible system inset. A
/// hidden sheet stays mounted offstage: no paint, tickers, focus or
/// semantics.
class AppInlineSheet extends StatefulWidget {
  const AppInlineSheet({
    required this.visible,
    required this.onClose,
    required this.semanticsLabel,
    required this.header,
    required this.body,
    super.key,
  });

  final bool visible;
  final VoidCallback onClose;

  /// Names the sheet for assistive technology, like a route title.
  final String semanticsLabel;

  /// Title row and fixed controls under the grab handle; drags the sheet.
  final Widget header;

  /// Fills the rest of the sheet.
  final Widget body;

  @override
  State<AppInlineSheet> createState() => _AppInlineSheetState();
}

class _AppInlineSheetState extends State<AppInlineSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _position = AnimationController(
    vsync: this,
    lowerBound: AppInlineSheetPosition.closed,
    upperBound: AppInlineSheetPosition.full,
    value: widget.visible
        ? AppInlineSheetPosition.half
        : AppInlineSheetPosition.closed,
  );

  late bool _offstage = !widget.visible;

  /// Heights from the latest layout, for gesture math between frames.
  var _geometry = const AppInlineSheetGeometry(half: 0, full: 0);

  /// Distance a body list has been pulled past its top in the current drag.
  double _pull = 0;

  /// Whether the latest layout scrolls the sheet's content as a whole.
  bool _compact = false;

  @override
  void didUpdateWidget(AppInlineSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible == oldWidget.visible) return;
    if (widget.visible) {
      _offstage = false;
      _animateTo(AppInlineSheetPosition.half);
    } else {
      _pull = 0;
      _animateTo(AppInlineSheetPosition.closed).whenCompleteOrCancel(() {
        if (!mounted || widget.visible) return;
        if (_position.value == AppInlineSheetPosition.closed) {
          setState(() => _offstage = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  TickerFuture _animateTo(double target) {
    final opening = target > _position.value;
    return _position.animateTo(
      target,
      duration: context.motion(opening ? AppMotion.medium : AppMotion.short),
      curve: Curves.easeOutCubic,
    );
  }

  bool get _restsAtHalf =>
      !_position.isAnimating &&
      (_position.value - AppInlineSheetPosition.half).abs() < _kRestTolerance;

  /// Asks the owner to close; settles back at half if it keeps the sheet.
  void _requestClose() {
    widget.onClose();
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted && widget.visible) _animateTo(AppInlineSheetPosition.half);
      })
      ..ensureVisualUpdate();
  }

  void _stepDown() {
    if (_position.value > AppInlineSheetPosition.half + _kRestTolerance) {
      _animateTo(AppInlineSheetPosition.half);
    } else {
      _requestClose();
    }
  }

  void _handleDragStart(DragStartDetails _) {
    if (widget.visible) _position.stop();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (!widget.visible || delta == null) return;
    final extent = (_geometry.extentAt(_position.value) - delta).clamp(
      0.0,
      _geometry.full,
    );
    _position.value = _geometry.positionForExtent(extent);
  }

  void _handleDragEnd(DragEndDetails details) =>
      _settle(details.primaryVelocity ?? 0);

  void _handleDragCancel() => _settle(0);

  /// Picks the rest position for a released drag; [velocity] is positive
  /// downward.
  void _settle(double velocity) {
    if (!widget.visible) return;
    final position = _position.value;
    final aboveHalf = position > AppInlineSheetPosition.half + _kRestTolerance;
    final double target;
    if (velocity > _kFlingVelocity) {
      target = aboveHalf
          ? AppInlineSheetPosition.half
          : AppInlineSheetPosition.closed;
    } else if (velocity < -_kFlingVelocity) {
      target = _geometry.canExpand
          ? AppInlineSheetPosition.full
          : AppInlineSheetPosition.half;
    } else if (position < _kClosePosition) {
      target = AppInlineSheetPosition.closed;
    } else if (_geometry.canExpand &&
        position >
            (AppInlineSheetPosition.half + AppInlineSheetPosition.full) / 2) {
      target = AppInlineSheetPosition.full;
    } else {
      target = AppInlineSheetPosition.half;
    }
    if (target == AppInlineSheetPosition.closed) {
      _requestClose();
    } else {
      _animateTo(target);
    }
  }

  bool _handleBodyScroll(ScrollNotification notification) {
    if (!widget.visible ||
        _compact ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    switch (notification) {
      case ScrollStartNotification():
        _pull = 0;
      case ScrollUpdateNotification(:final dragDetails, :final scrollDelta):
        if (dragDetails == null) break;
        if ((scrollDelta ?? 0) > 0 && _restsAtHalf && _geometry.canExpand) {
          _animateTo(AppInlineSheetPosition.full);
        }
        // Bouncing physics report the pull as scrolling past the top.
        final metrics = notification.metrics;
        _pull = math.max(_pull, metrics.minScrollExtent - metrics.pixels);
      case OverscrollNotification(:final dragDetails, :final overscroll):
        // Clamping physics report it as overscroll instead.
        if (dragDetails != null && overscroll < 0) _pull -= overscroll;
      case ScrollEndNotification():
        if (_pull >= _kPullToCollapseDistance) _stepDown();
        _pull = 0;
      default:
        break;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final padding = MediaQuery.paddingOf(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final colors = context.colors;
    final sheetTheme = Theme.of(context).bottomSheetTheme;
    final scrim = sheetTheme.modalBarrierColor ?? Colors.black54;
    final localizations = MaterialLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _geometry = AppInlineSheetGeometry.resolve(
          maxHeight: constraints.maxHeight,
          keyboardInset: keyboardInset,
          topInset: padding.top,
          textScale: textScale,
        );
        // Less room than the content's minimum (a landscape phone with the
        // keyboard up): it scrolls as a whole (see _AppInlineSheetMinHeight).
        // Dragging would fight that scroll and has no second position to
        // reach, so it is off.
        final compact = _compact = geometry.scrollsContent;
        // A centered tablet or landscape sheet may not reach the side
        // cutouts at all; pad only for the part it covers.
        final side = (constraints.maxWidth - _kMaxWidth).clamp(
          0.0,
          double.infinity,
        );
        final sideInsets = EdgeInsets.only(
          left: math.max(0, padding.left - side / 2),
          right: math.max(0, padding.right - side / 2),
        );

        final content = Column(
          children: [
            _AppInlineSheetDragRegion(
              enabled: !compact,
              onStart: _handleDragStart,
              onUpdate: _handleDragUpdate,
              onEnd: _handleDragEnd,
              onCancel: _handleDragCancel,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [const AppSheetDragHandle(), widget.header],
              ),
            ),
            Expanded(
              child: _AppInlineSheetDragRegion(
                enabled: !compact,
                onStart: _handleDragStart,
                onUpdate: _handleDragUpdate,
                onEnd: _handleDragEnd,
                onCancel: _handleDragCancel,
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleBodyScroll,
                  child: widget.body,
                ),
              ),
            ),
          ],
        );

        final surface = Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: widget.semanticsLabel,
          child: Material(
            color: sheetTheme.backgroundColor ?? colors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: sideInsets,
              // One MediaQuery: nested remove* helpers would each restart
              // from the outer data and undo the other.
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .removePadding(removeLeft: true, removeRight: true)
                    .removeViewInsets(removeBottom: true),
                child: _AppInlineSheetMinHeight(
                  minHeight: AppInlineSheetGeometry.minHalfHeight,
                  child: content,
                ),
              ),
            ),
          ),
        );

        // Both slots stay in place while hidden: dropping the scrim would
        // shift the sheet to its index and discard the body's state.
        return Stack(
          children: [
            Positioned.fill(
              child: _offstage
                  ? const SizedBox.shrink()
                  : IgnorePointer(
                      ignoring: !widget.visible,
                      child: AnimatedBuilder(
                        animation: _position,
                        builder: (context, _) => ModalBarrier(
                          color: scrim.withValues(
                            alpha: scrim.a * math.min(_position.value, 1),
                          ),
                          onDismiss: widget.onClose,
                          semanticsLabel: localizations.scrimLabel,
                          semanticsOnTapHint: localizations.scrimOnTapHint(
                            widget.semanticsLabel,
                          ),
                        ),
                      ),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: keyboardInset,
              child: Offstage(
                offstage: _offstage,
                child: TickerMode(
                  enabled: !_offstage,
                  child: ExcludeFocus(
                    excluding: !widget.visible,
                    child: IgnorePointer(
                      ignoring: !widget.visible,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _kMaxWidth,
                          ),
                          child: AnimatedBuilder(
                            animation: _position,
                            child: surface,
                            builder: (context, surface) {
                              final position = _position.value;
                              return Transform.translate(
                                offset: Offset(0, geometry.slideAt(position)),
                                child: SizedBox(
                                  height: geometry.heightAt(position),
                                  child: surface,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Lays [child] out at least [minHeight] tall and scrolls it when the sheet
/// is shorter. The scroll view is always present so crossing the threshold
/// (rotating, the keyboard opening) never re-inflates the content and drops
/// its focus.
class _AppInlineSheetMinHeight extends StatelessWidget {
  const _AppInlineSheetMinHeight({
    required this.minHeight,
    required this.child,
  });

  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fits = constraints.maxHeight >= minHeight;
        return SingleChildScrollView(
          // Never claim the screen's primary controller from the lists inside.
          primary: false,
          physics: fits ? const NeverScrollableScrollPhysics() : null,
          child: SizedBox(
            height: math.max(constraints.maxHeight, minHeight),
            child: child,
          ),
        );
      },
    );
  }
}

/// Vertical drags on the sheet's frame. Scrollables inside win the gesture
/// arena while they can scroll, so this only moves the sheet from the header
/// or a body that has nothing to scroll.
class _AppInlineSheetDragRegion extends StatelessWidget {
  const _AppInlineSheetDragRegion({
    required this.enabled,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    required this.onCancel,
    required this.child,
  });

  final bool enabled;
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
  final GestureDragCancelCallback onCancel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The detector stays in the tree when disabled, so toggling never
    // re-inflates the header or body.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: enabled ? onStart : null,
      onVerticalDragUpdate: enabled ? onUpdate : null,
      onVerticalDragEnd: enabled ? onEnd : null,
      onVerticalDragCancel: enabled ? onCancel : null,
      child: child,
    );
  }
}
