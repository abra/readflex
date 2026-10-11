import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'bottom_sheet_title_bar_slot.dart';

/// A sheet title and its trailing action on one line.
///
/// A title too long to fit beside [trailing] shrinks, down to
/// [minTitleScale] of its size. When even that does not fit, the narrower
/// [compactTrailing] takes the place of [trailing] under the same rule.
/// Past that, [trailing] wraps below the title, which then wraps in the full
/// width.
///
/// The title is scaled when painted, like a scale-down `FittedBox`: its size
/// depends on the action's laid-out width, which no build-time font size can
/// know.
class BottomSheetTitleBar extends StatefulWidget {
  const BottomSheetTitleBar({
    required this.title,
    required this.trailing,
    required this.spacing,
    required this.overflowSpacing,
    required this.minTitleScale,
    this.compactTrailing,
    super.key,
  }) : assert(minTitleScale > 0 && minTitleScale <= 1);

  final Widget title;
  final Widget trailing;

  /// The same action in less width, such as an icon button for a labeled
  /// one. Only the action on screen is focusable, hit tested and announced.
  final Widget? compactTrailing;

  /// The least gap between the title and the action on one line.
  final double spacing;

  /// The gap between the title and the action wrapped below it.
  final double overflowSpacing;
  final double minTitleScale;

  @override
  State<BottomSheetTitleBar> createState() => _BottomSheetTitleBarState();
}

class _BottomSheetTitleBarState extends State<BottomSheetTitleBar> {
  // Which action the last layout showed. Layout decides it, so the hidden
  // action leaves focus traversal once that frame is done.
  var _compactShown = false;

  void _onCompactShownChanged(bool compactShown) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || compactShown == _compactShown) return;
      setState(() => _compactShown = compactShown);
    });
  }

  @override
  Widget build(BuildContext context) {
    final compactTrailing = widget.compactTrailing;
    return _TitleBarLayout(
      title: widget.title,
      trailing: ExcludeFocus(
        excluding: _compactShown,
        child: widget.trailing,
      ),
      compactTrailing: compactTrailing == null
          ? null
          : ExcludeFocus(excluding: !_compactShown, child: compactTrailing),
      spacing: widget.spacing,
      overflowSpacing: widget.overflowSpacing,
      minTitleScale: widget.minTitleScale,
      onCompactShownChanged: _onCompactShownChanged,
    );
  }
}

class _TitleBarLayout
    extends
        SlottedMultiChildRenderObjectWidget<
          BottomSheetTitleBarSlot,
          RenderBox
        > {
  const _TitleBarLayout({
    required this.title,
    required this.trailing,
    required this.compactTrailing,
    required this.spacing,
    required this.overflowSpacing,
    required this.minTitleScale,
    required this.onCompactShownChanged,
  });

  final Widget title;
  final Widget trailing;
  final Widget? compactTrailing;
  final double spacing;
  final double overflowSpacing;
  final double minTitleScale;
  final ValueChanged<bool> onCompactShownChanged;

  @override
  Iterable<BottomSheetTitleBarSlot> get slots => BottomSheetTitleBarSlot.values;

  @override
  Widget? childForSlot(BottomSheetTitleBarSlot slot) => switch (slot) {
    BottomSheetTitleBarSlot.title => title,
    BottomSheetTitleBarSlot.trailing => trailing,
    BottomSheetTitleBarSlot.compactTrailing => compactTrailing,
  };

  @override
  RenderBottomSheetTitleBar createRenderObject(BuildContext context) =>
      RenderBottomSheetTitleBar(
        textDirection: Directionality.of(context),
        spacing: spacing,
        overflowSpacing: overflowSpacing,
        minTitleScale: minTitleScale,
        onCompactShownChanged: onCompactShownChanged,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderBottomSheetTitleBar renderObject,
  ) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..spacing = spacing
      ..overflowSpacing = overflowSpacing
      ..minTitleScale = minTitleScale
      ..onCompactShownChanged = onCompactShownChanged;
  }
}

/// Lays out a [BottomSheetTitleBar]: the title at the start and the shown
/// action at the end, both centered on the line; wrapped, both at the start.
class RenderBottomSheetTitleBar extends RenderBox
    with SlottedContainerRenderObjectMixin<BottomSheetTitleBarSlot, RenderBox> {
  RenderBottomSheetTitleBar({
    required TextDirection textDirection,
    required double spacing,
    required double overflowSpacing,
    required double minTitleScale,
    this.onCompactShownChanged,
  }) : _textDirection = textDirection,
       _spacing = spacing,
       _overflowSpacing = overflowSpacing,
       _minTitleScale = minTitleScale;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;
  double _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get overflowSpacing => _overflowSpacing;
  double _overflowSpacing;
  set overflowSpacing(double value) {
    if (value == _overflowSpacing) return;
    _overflowSpacing = value;
    markNeedsLayout();
  }

  double get minTitleScale => _minTitleScale;
  double _minTitleScale;
  set minTitleScale(double value) {
    if (value == _minTitleScale) return;
    _minTitleScale = value;
    markNeedsLayout();
  }

  /// Told after a layout that swaps the shown action.
  ValueChanged<bool>? onCompactShownChanged;

  /// The scale the title was painted at after the last layout.
  @visibleForTesting
  double get titleScale => _titleScale;
  double _titleScale = 1;

  /// Whether the last layout showed the compact action.
  @visibleForTesting
  bool get compactShown => _compactShown;
  var _compactShown = false;

  RenderBox get _title => childForSlot(BottomSheetTitleBarSlot.title)!;
  RenderBox get _trailing => childForSlot(BottomSheetTitleBarSlot.trailing)!;
  RenderBox? get _compactTrailing =>
      childForSlot(BottomSheetTitleBarSlot.compactTrailing);
  RenderBox get _shownTrailing => _compactShown ? _compactTrailing! : _trailing;

  // Title first: paint, hit testing and semantics follow reading order.
  @override
  Iterable<RenderBox> get children => [
    ?childForSlot(BottomSheetTitleBarSlot.title),
    ?childForSlot(BottomSheetTitleBarSlot.trailing),
    ?childForSlot(BottomSheetTitleBarSlot.compactTrailing),
  ];

  // The one decision behind layout, dry layout, intrinsics and baselines.
  // The title is measured on one line and stays there when it fits beside an
  // action at [minTitleScale]: the full action first, then the compact one.
  // Otherwise it wraps in the width with the full action below it.
  ({
    Size size,
    BoxConstraints titleConstraints,
    double titleScale,
    bool compactShown,
    Offset titleOffset,
    Offset trailingOffset,
  })
  _computeLayout(BoxConstraints constraints, ChildLayouter layoutChild) {
    final loose = constraints.loosen();
    final trailing = layoutChild(_trailing, loose);
    final compactTrailing = _compactTrailing;
    // Laid out even when not chosen: a focus or semantics query in the frame
    // before the hidden action leaves the tree needs its size.
    final compact = compactTrailing == null
        ? null
        : layoutChild(compactTrailing, loose);
    var titleConstraints = const BoxConstraints();
    var title = layoutChild(_title, titleConstraints);
    double roomBeside(Size action) =>
        constraints.maxWidth - action.width - spacing;
    bool fitsBeside(Size action) =>
        title.width * minTitleScale <= roomBeside(action);
    final compactShown =
        !fitsBeside(trailing) && compact != null && fitsBeside(compact);
    final action = compactShown ? compact : trailing;
    final inline = compactShown || fitsBeside(trailing);
    final rtl = textDirection == TextDirection.rtl;
    if (inline) {
      final room = roomBeside(action);
      final titleScale = title.width > room ? room / title.width : 1.0;
      final shown = title * titleScale;
      final size = constraints.constrain(
        Size(
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : shown.width + spacing + action.width,
          math.max(shown.height, action.height),
        ),
      );
      return (
        size: size,
        titleConstraints: titleConstraints,
        titleScale: titleScale,
        compactShown: compactShown,
        titleOffset: Offset(
          rtl ? size.width - shown.width : 0,
          (size.height - shown.height) / 2,
        ),
        trailingOffset: Offset(
          rtl ? 0 : size.width - action.width,
          (size.height - action.height) / 2,
        ),
      );
    }
    titleConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    title = layoutChild(_title, titleConstraints);
    final size = constraints.constrain(
      Size(
        constraints.maxWidth,
        title.height + overflowSpacing + trailing.height,
      ),
    );
    return (
      size: size,
      titleConstraints: titleConstraints,
      titleScale: 1.0,
      compactShown: false,
      titleOffset: Offset(rtl ? size.width - title.width : 0, 0),
      trailingOffset: Offset(
        rtl ? size.width - trailing.width : 0,
        title.height + overflowSpacing,
      ),
    );
  }

  static Size _intrinsicLayoutChild(
    RenderBox child,
    BoxConstraints constraints,
  ) {
    final width = math.min(
      child.getMaxIntrinsicWidth(double.infinity),
      constraints.maxWidth,
    );
    return Size(width, child.getMaxIntrinsicHeight(width));
  }

  @override
  void performLayout() {
    final layout = _computeLayout(constraints, ChildLayoutHelper.layoutChild);
    size = layout.size;
    _titleScale = layout.titleScale;
    if (layout.compactShown != _compactShown) {
      _compactShown = layout.compactShown;
      onCompactShownChanged?.call(_compactShown);
    }
    (_title.parentData! as BoxParentData).offset = layout.titleOffset;
    // The hidden action shares the place, for focus rects until it leaves.
    for (final action in [_trailing, ?_compactTrailing]) {
      (action.parentData! as BoxParentData).offset = layout.trailingOffset;
    }
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _computeLayout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _title.getMinIntrinsicWidth(double.infinity),
    _trailing.getMinIntrinsicWidth(double.infinity),
  );

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _title.getMaxIntrinsicWidth(double.infinity) +
      spacing +
      _trailing.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _computeLayout(
    BoxConstraints(maxWidth: width),
    _intrinsicLayoutChild,
  ).size.height;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = _title.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    final offset = (_title.parentData! as BoxParentData).offset;
    return offset.dy + distance * _titleScale;
  }

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) {
    final layout = _computeLayout(
      constraints,
      ChildLayoutHelper.dryLayoutChild,
    );
    final distance = _title.getDryBaseline(layout.titleConstraints, baseline);
    if (distance == null) return null;
    return layout.titleOffset.dy + distance * layout.titleScale;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final titleOffset = offset + (_title.parentData! as BoxParentData).offset;
    if (_titleScale == 1) {
      layer = null;
      context.paintChild(_title, titleOffset);
    } else {
      layer = context.pushTransform(
        needsCompositing,
        titleOffset,
        Matrix4.diagonal3Values(_titleScale, _titleScale, 1),
        (context, offset) => context.paintChild(_title, offset),
        oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
      );
    }
    final action = _shownTrailing;
    context.paintChild(
      action,
      offset + (action.parentData! as BoxParentData).offset,
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final offset = (child.parentData! as BoxParentData).offset;
    transform.translateByDouble(offset.dx, offset.dy, 0, 1);
    if (child == _title) {
      transform.scaleByDouble(_titleScale, _titleScale, 1, 1);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final action = _shownTrailing;
    final hitAction = result.addWithPaintOffset(
      offset: (action.parentData! as BoxParentData).offset,
      position: position,
      hitTest: (result, transformed) =>
          action.hitTest(result, position: transformed),
    );
    if (hitAction) return true;
    final transform = Matrix4.identity();
    applyPaintTransform(_title, transform);
    return result.addWithPaintTransform(
      transform: transform,
      position: position,
      hitTest: (result, transformed) =>
          _title.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    visitor(_title);
    visitor(_shownTrailing);
  }
}
