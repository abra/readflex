import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'sheet_action_row_slot.dart';

/// Lays out an `AppSheetActionRow`: optional lead text across the row, the
/// body text beside the action, and the action centered on the body's first
/// line.
class SheetActionRowLayout
    extends SlottedMultiChildRenderObjectWidget<SheetActionRowSlot, RenderBox> {
  const SheetActionRowLayout({
    required this.body,
    required this.action,
    required this.firstLineHeight,
    required this.leadSpacing,
    required this.leadEndInset,
    required this.minTextRoom,
    this.lead,
    super.key,
  });

  final Widget? lead;
  final Widget body;
  final Widget action;
  final double firstLineHeight;
  final double leadSpacing;
  final double leadEndInset;
  final double minTextRoom;

  @override
  Iterable<SheetActionRowSlot> get slots => SheetActionRowSlot.values;

  @override
  Widget? childForSlot(SheetActionRowSlot slot) => switch (slot) {
    SheetActionRowSlot.lead => lead,
    SheetActionRowSlot.body => body,
    SheetActionRowSlot.action => action,
  };

  @override
  RenderSheetActionRow createRenderObject(BuildContext context) =>
      RenderSheetActionRow(
        textDirection: Directionality.of(context),
        firstLineHeight: firstLineHeight,
        leadSpacing: leadSpacing,
        leadEndInset: leadEndInset,
        minTextRoom: minTextRoom,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSheetActionRow renderObject,
  ) {
    renderObject
      ..textDirection = Directionality.of(context)
      ..firstLineHeight = firstLineHeight
      ..leadSpacing = leadSpacing
      ..leadEndInset = leadEndInset
      ..minTextRoom = minTextRoom;
  }
}

/// Render object of [SheetActionRowLayout].
///
/// The body takes the width beside the action; the lead spans the row up to
/// [leadEndInset] from its end, so lead text keeps both content edges in
/// either direction. The action is centered on the body's first line,
/// [firstLineHeight] tall, and always fits in the row: an action taller than
/// that line moves the text down unless lead text already gives it room.
/// [minTextRoom] is the least room above the first line of text, lead or
/// body, and below the last one; room the action takes counts toward it.
class RenderSheetActionRow extends RenderBox
    with SlottedContainerRenderObjectMixin<SheetActionRowSlot, RenderBox> {
  RenderSheetActionRow({
    required TextDirection textDirection,
    required double firstLineHeight,
    required double leadSpacing,
    required double leadEndInset,
    required double minTextRoom,
  }) : _textDirection = textDirection,
       _firstLineHeight = firstLineHeight,
       _leadSpacing = leadSpacing,
       _leadEndInset = leadEndInset,
       _minTextRoom = minTextRoom;

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsLayout();
  }

  double get firstLineHeight => _firstLineHeight;
  double _firstLineHeight;
  set firstLineHeight(double value) {
    if (value == _firstLineHeight) return;
    _firstLineHeight = value;
    markNeedsLayout();
  }

  double get leadSpacing => _leadSpacing;
  double _leadSpacing;
  set leadSpacing(double value) {
    if (value == _leadSpacing) return;
    _leadSpacing = value;
    markNeedsLayout();
  }

  double get leadEndInset => _leadEndInset;
  double _leadEndInset;
  set leadEndInset(double value) {
    if (value == _leadEndInset) return;
    _leadEndInset = value;
    markNeedsLayout();
  }

  double get minTextRoom => _minTextRoom;
  double _minTextRoom;
  set minTextRoom(double value) {
    if (value == _minTextRoom) return;
    _minTextRoom = value;
    markNeedsLayout();
  }

  RenderBox? get _lead => childForSlot(SheetActionRowSlot.lead);
  RenderBox get _body => childForSlot(SheetActionRowSlot.body)!;
  RenderBox get _action => childForSlot(SheetActionRowSlot.action)!;

  // Reading order: paint, hit testing and semantics follow it.
  @override
  Iterable<RenderBox> get children => [
    ?childForSlot(SheetActionRowSlot.lead),
    ?childForSlot(SheetActionRowSlot.body),
    ?childForSlot(SheetActionRowSlot.action),
  ];

  // The one decision behind layout, dry layout, intrinsics and baselines.
  ({
    Size size,
    BoxConstraints? leadConstraints,
    BoxConstraints bodyConstraints,
    Offset leadOffset,
    Offset bodyOffset,
    Offset actionOffset,
  })
  _computeLayout(BoxConstraints constraints, ChildLayouter layoutChild) {
    final action = layoutChild(_action, constraints.loosen());
    final bounded = constraints.hasBoundedWidth;
    final bodyConstraints = bounded
        ? BoxConstraints.tightFor(
            width: math.max(0.0, constraints.maxWidth - action.width),
          )
        : const BoxConstraints();
    final body = layoutChild(_body, bodyConstraints);
    final lead = _lead;
    final leadConstraints = lead == null
        ? null
        : bounded
        ? BoxConstraints.tightFor(
            width: math.max(0.0, constraints.maxWidth - leadEndInset),
          )
        : const BoxConstraints();
    final leadSize = lead == null ? null : layoutChild(lead, leadConstraints!);
    final width = bounded
        ? constraints.maxWidth
        : math.max(
            body.width + action.width,
            (leadSize?.width ?? 0) + leadEndInset,
          );

    final bodyTop = leadSize == null ? 0.0 : leadSize.height + leadSpacing;
    final actionTop = bodyTop + (firstLineHeight - action.height) / 2;
    // A target taller than the line reaches above the text; lead text there
    // already gives it room.
    final shift = math.max(minTextRoom, -actionTop);
    final size = constraints.constrain(
      Size(
        width,
        math.max(
          shift + bodyTop + body.height + minTextRoom,
          shift + actionTop + action.height,
        ),
      ),
    );
    final rtl = textDirection == TextDirection.rtl;
    return (
      size: size,
      leadConstraints: leadConstraints,
      bodyConstraints: bodyConstraints,
      leadOffset: Offset(
        rtl ? size.width - (leadSize?.width ?? 0) : 0,
        shift,
      ),
      bodyOffset: Offset(rtl ? size.width - body.width : 0, shift + bodyTop),
      actionOffset: Offset(
        rtl ? 0 : size.width - action.width,
        shift + actionTop,
      ),
    );
  }

  static Size _intrinsicLayoutChild(
    RenderBox child,
    BoxConstraints constraints,
  ) {
    final width = constraints.hasTightWidth
        ? constraints.maxWidth
        : math.min(
            child.getMaxIntrinsicWidth(double.infinity),
            constraints.maxWidth,
          );
    return Size(width, child.getMaxIntrinsicHeight(width));
  }

  @override
  void performLayout() {
    final layout = _computeLayout(constraints, ChildLayoutHelper.layoutChild);
    size = layout.size;
    if (_lead case final lead?) {
      (lead.parentData! as BoxParentData).offset = layout.leadOffset;
    }
    (_body.parentData! as BoxParentData).offset = layout.bodyOffset;
    (_action.parentData! as BoxParentData).offset = layout.actionOffset;
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _computeLayout(constraints, ChildLayoutHelper.dryLayoutChild).size;

  @override
  double computeMinIntrinsicWidth(double height) => math.max(
    _body.getMinIntrinsicWidth(double.infinity) +
        _action.getMinIntrinsicWidth(double.infinity),
    (_lead?.getMinIntrinsicWidth(double.infinity) ?? 0) + leadEndInset,
  );

  @override
  double computeMaxIntrinsicWidth(double height) => math.max(
    _body.getMaxIntrinsicWidth(double.infinity) +
        _action.getMaxIntrinsicWidth(double.infinity),
    (_lead?.getMaxIntrinsicWidth(double.infinity) ?? 0) + leadEndInset,
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _computeLayout(
    BoxConstraints(maxWidth: width),
    _intrinsicLayoutChild,
  ).size.height;

  // The first line of text, the lead's when there is one, gives the baseline.
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final first = _lead ?? _body;
    final distance = first.getDistanceToActualBaseline(baseline);
    if (distance == null) return null;
    return (first.parentData! as BoxParentData).offset.dy + distance;
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
    final lead = _lead;
    final distance = lead == null
        ? _body.getDryBaseline(layout.bodyConstraints, baseline)
        : lead.getDryBaseline(layout.leadConstraints!, baseline);
    if (distance == null) return null;
    return (lead == null ? layout.bodyOffset : layout.leadOffset).dy + distance;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(
        child,
        offset + (child.parentData! as BoxParentData).offset,
      );
    }
  }

  // The action first: it is painted last, on top of any lead text it
  // reaches.
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children.toList().reversed) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, transformed) =>
            child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }
}
