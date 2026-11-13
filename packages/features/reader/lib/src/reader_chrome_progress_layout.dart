import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Gap between the chapter (or time) label and the page label above the slider.
const readerProgressLabelGap = AppSpacing.md;

/// Material track inset, matching the Reader slider's overlay radius.
const readerProgressTrackInset = 14.0;

/// Aligns status labels and non-interactive tracks with the platform slider.
double readerProgressTrackInsetOf(BuildContext context) =>
    context.isCupertino ? AppSpacing.sm : readerProgressTrackInset;

const _referenceFontSize = 14.0;
const _stackedTextScale = 1.3;

/// The page label is short and numeric in every locale, so it keeps its
/// natural width, bounded only by the row: its digits never truncate. The
/// chapter label takes the rest and truncates first.
double readerProgressEndLabelMaxWidth(double rowWidth) =>
    math.max(0, rowWidth - readerProgressLabelGap);

/// Above 130% text prefer a line per label when height permits. Use the rendered
/// role's font size so nonlinear system scaling follows the same threshold.
bool readerProgressLabelsStack(
  TextScaler textScaler, {
  double fontSize = _referenceFontSize,
}) => textScaler.scale(fontSize) > fontSize * _stackedTextScale;

/// Chooses a stacked status or a row from the labels' actual rendered sizes.
/// Script fallback fonts may exceed the requested TextStyle line height.
class ReaderProgressLabelLayout extends MultiChildRenderObjectWidget {
  ReaderProgressLabelLayout({
    required Widget? start,
    required Widget page,
    required this.preferStacked,
    super.key,
  }) : super(children: [start ?? const SizedBox.shrink(), page]);

  final bool preferStacked;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReaderProgressLabels(
        preferStacked,
        Directionality.of(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderObject renderObject,
  ) {
    (renderObject as _RenderReaderProgressLabels)
      ..preferStacked = preferStacked
      ..textDirection = Directionality.of(context);
  }
}

class _ProgressLabelParentData extends ContainerBoxParentData<RenderBox> {}

typedef _ProgressLabelSizes = ({
  Size start,
  Size page,
  Size size,
  bool stacked,
});

class _RenderReaderProgressLabels extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ProgressLabelParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ProgressLabelParentData> {
  _RenderReaderProgressLabels(this._preferStacked, this._textDirection);

  bool _preferStacked;
  TextDirection _textDirection;

  set preferStacked(bool value) {
    if (_preferStacked == value) return;
    _preferStacked = value;
    markNeedsLayout();
  }

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ProgressLabelParentData) {
      child.parentData = _ProgressLabelParentData();
    }
  }

  Size _measure(
    RenderBox child,
    BoxConstraints constraints, {
    required bool dry,
  }) {
    if (dry) return child.getDryLayout(constraints);
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }

  _ProgressLabelSizes _measureLabels(
    BoxConstraints constraints, {
    required bool dry,
  }) {
    final width = constraints.maxWidth;
    final start = firstChild!;
    final page = lastChild!;
    final rowPageWidth = readerProgressEndLabelMaxWidth(width);
    var pageSize = _measure(
      page,
      BoxConstraints(maxWidth: _preferStacked ? width : rowPageWidth),
      dry: dry,
    );
    if (_preferStacked) {
      final startSize = _measure(
        start,
        BoxConstraints.tightFor(width: width),
        dry: dry,
      );
      final height = startSize.height + pageSize.height;
      if (height <= constraints.maxHeight) {
        return (
          start: startSize,
          page: pageSize,
          size: constraints.constrain(Size(width, height)),
          stacked: true,
        );
      }
      // Only the two bounded labels are re-laid out for the narrower row.
      if (pageSize.width > rowPageWidth) {
        pageSize = _measure(
          page,
          BoxConstraints(maxWidth: rowPageWidth),
          dry: dry,
        );
      }
    }
    final startSize = _measure(
      start,
      BoxConstraints.tightFor(
        width: math.max(0, width - pageSize.width - readerProgressLabelGap),
      ),
      dry: dry,
    );
    return (
      start: startSize,
      page: pageSize,
      size: constraints.constrain(
        Size(width, math.max(startSize.height, pageSize.height)),
      ),
      stacked: false,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _measureLabels(constraints, dry: true).size;

  @override
  void performLayout() {
    final labels = _measureLabels(constraints, dry: false);
    size = labels.size;
    final rtl = _textDirection == TextDirection.rtl;
    (firstChild!.parentData! as _ProgressLabelParentData).offset = Offset(
      labels.stacked || !rtl ? 0 : size.width - labels.start.width,
      0,
    );
    (lastChild!.parentData! as _ProgressLabelParentData).offset = Offset(
      rtl ? 0 : size.width - labels.page.width,
      labels.stacked ? labels.start.height : 0,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
