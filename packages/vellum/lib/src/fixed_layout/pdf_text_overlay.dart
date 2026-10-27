import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../formats/pdf_text_layer.dart';
import 'comic_image_area.dart';
import 'fixed_pages_controller.dart';
import 'fixed_pages_view.dart';
import 'pdf_text_selection.dart';
import 'repaint_after_build.dart';

/// Text on one PDF page: saved highlights, the search hit, and the
/// selection with its handles, over the page image.
///
/// Placed by `FixedPagesView.pageOverlayBuilder`, so it is scaled with the
/// page while zoomed; sizes meant in screen pixels are divided by the
/// zoom. A long press (280 ms, as image areas) on a word selects it and
/// drags its end over the text; afterwards a drag from either handle (a
/// 44 px target at the selection's ends) moves that end by character, a
/// tap outside clears the selection, and a tap on a
/// saved highlight reports it. The page's text
/// comes as a [PdfTextLayer]; until it is loaded the overlay only draws
/// what it is given.
class PdfTextOverlay extends StatefulWidget {
  const PdfTextOverlay({
    super.key,
    required this.page,
    required this.imageRect,
    required this.pageWidth,
    required this.pageHeight,
    required this.controller,
    required this.selection,
    this.layer,
    this.highlights = const [],
    this.searchMark,
    this.searchMarkColor = const Color(0x66FFB300),
    this.onSelectionChanged,
    this.onSelectionCleared,
    this.onHighlightPressed,
    this.enabled = true,
  });

  final int page;

  /// Where the whole page is drawn inside this layer.
  final Rect imageRect;

  /// The page's display size in points, the unit of [PdfTextLayer] boxes.
  final double pageWidth;
  final double pageHeight;

  final FixedPagesController controller;
  final PdfTextSelection selection;
  final PdfTextLayer? layer;

  /// Saved highlights of this page, oldest first.
  final List<PdfTextHighlight> highlights;

  /// The search hit to mark on this page.
  final PdfTextRange? searchMark;
  final Color searchMarkColor;

  /// The selection was made or its end moved and the finger lifted, with
  /// where it sits in the whole view (null outside a `FixedPagesView`).
  final PdfSelectionChanged? onSelectionChanged;

  /// A tap outside dismissed the selection.
  final VoidCallback? onSelectionCleared;

  /// A tap on a saved highlight, with where it sits in the whole view.
  final PdfHighlightPressed? onHighlightPressed;

  /// False leaves everything drawn but takes no input.
  final bool enabled;

  /// Touch target of a selection handle, in screen pixels.
  static const handleTarget = 44.0;

  /// Drawn radius of a handle's knob, in screen pixels.
  static const handleRadius = 6.0;

  @override
  State<PdfTextOverlay> createState() => _PdfTextOverlayState();
}

typedef PdfSelectionChanged =
    void Function(PdfTextRange range, Rect? viewportRect);

typedef PdfHighlightPressed =
    void Function(PdfTextHighlight highlight, Rect? viewportRect);

enum _Drag { selecting, startHandle, endHandle }

class _PdfTextOverlayState extends State<PdfTextOverlay>
    with RepaintAfterBuild {
  _Drag? _drag;

  /// The character the press started on; the other end follows the finger.
  int? _anchorStart;
  int? _anchorEnd;

  PdfTextSelection get _selection => widget.selection;

  bool get _hasSelectionHere =>
      _selection.isActive && _selection.page == widget.page;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void didUpdateWidget(PdfTextOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      oldWidget.selection.removeListener(_onSelectionChanged);
      widget.selection.addListener(_onSelectionChanged);
    }
  }

  @override
  void dispose() {
    _selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    if (!_selection.isActive) _drag = null;
    repaint();
  }

  // Coordinates: layer pixels ↔ page points.

  double get _scale => widget.imageRect.width / widget.pageWidth;

  Offset _toPage(Offset local) => Offset(
    (local.dx - widget.imageRect.left) / _scale,
    (local.dy - widget.imageRect.top) / _scale,
  );

  Rect _toLayer(PdfBox box) => Rect.fromLTRB(
    widget.imageRect.left + box.left * _scale,
    widget.imageRect.top + box.top * _scale,
    widget.imageRect.left + box.right * _scale,
    widget.imageRect.top + box.bottom * _scale,
  );

  List<Rect> _rectsOf(PdfTextRange range) {
    final layer = widget.layer;
    if (layer == null) return const [];
    return [for (final box in layer.boxesOf(range)) _toLayer(box)];
  }

  Rect? _boundsOf(PdfTextRange range) {
    final rects = _rectsOf(range);
    if (rects.isEmpty) return null;
    return rects.reduce((a, b) => a.expandToInclude(b));
  }

  Rect? _viewportRectOf(PdfTextRange range) {
    final bounds = _boundsOf(range);
    final box = context.findRenderObject();
    if (bounds == null || box is! RenderBox) return null;
    return FixedPagesViewportScope.fractionsOf(context, bounds, box);
  }

  // Long press: select the word under the finger and drag over the text.

  void _onLongPressStart(LongPressStartDetails details) {
    final layer = widget.layer;
    if (layer == null) return;
    final point = _toPage(details.localPosition);
    final word = layer.wordAtPoint(point.dx, point.dy);
    if (word == null) return;
    _anchorStart = word.start;
    _anchorEnd = word.end;
    _drag = _Drag.selecting;
    _selection.start(widget.page, word);
    widget.controller.lockInput(true);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _extendTo(details.localPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _endDrag();
  }

  void _extendTo(Offset local) {
    final layer = widget.layer;
    if (_drag == null || layer == null || !_hasSelectionHere) return;
    final point = _toPage(local);
    final index = layer.charIndexAt(point.dx, point.dy);
    if (index == null) return;
    final current = _selection.range!;
    final range = switch (_drag!) {
      _Drag.selecting =>
        index < _anchorStart!
            ? PdfTextRange(index, _anchorEnd!)
            : PdfTextRange(_anchorStart!, index + 1),
      _Drag.startHandle =>
        index < current.end
            ? PdfTextRange(index, current.end)
            : PdfTextRange(current.end - 1, index + 1),
      _Drag.endHandle =>
        index + 1 > current.start
            ? PdfTextRange(current.start, index + 1)
            : PdfTextRange(index, current.start + 1),
    };
    _selection.update(range);
  }

  void _endDrag() {
    if (_drag == null || !_hasSelectionHere) return;
    _drag = null;
    final range = _selection.range!;
    widget.onSelectionChanged?.call(range, _viewportRectOf(range));
  }

  // After release: a drag from a handle moves that end, a tap outside
  // clears. The nearer handle takes a touch where their targets overlap.

  void _onPanDown(DragDownDetails details) {
    _drag = null;
    if (!_hasSelectionHere) return;
    final rects = _rectsOf(_selection.range!);
    if (rects.isEmpty) return;
    final radius =
        PdfTextOverlay.handleTarget / 2 / widget.controller.zoomScale;
    final start = (details.localPosition - rects.first.bottomLeft).distance;
    final end = (details.localPosition - rects.last.bottomRight).distance;
    if (start > radius && end > radius) return;
    _drag = start <= end ? _Drag.startHandle : _Drag.endHandle;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _extendTo(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _endDrag();
  }

  void _onPanCancel() {
    _drag = null;
  }

  void _onTapUp(TapUpDetails details) {
    if (!_hasSelectionHere) return;
    final bounds = _boundsOf(_selection.range!);
    if (bounds != null && bounds.contains(details.localPosition)) return;
    _selection.clear();
    widget.controller.lockInput(false);
    widget.onSelectionCleared?.call();
  }

  void _onHighlightTap(PdfTextHighlight highlight) {
    widget.onHighlightPressed?.call(
      highlight,
      _viewportRectOf(highlight.range),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zoomScale = widget.controller.zoomScale;
    final highlights = [
      for (final highlight in widget.highlights)
        if (highlight.page == widget.page) highlight,
    ];
    final selectionRects = _hasSelectionHere
        ? _rectsOf(_selection.range!)
        : const <Rect>[];
    final painter = _TextOverlayPainter(
      highlights: [
        for (final highlight in highlights)
          (rects: _rectsOf(highlight.range), color: highlight.color),
      ],
      searchMark: widget.searchMark == null
          ? const []
          : _rectsOf(widget.searchMark!),
      searchMarkColor: widget.searchMarkColor,
      selection: selectionRects,
      selectionColor: _selection.color,
      handleRadius: PdfTextOverlay.handleRadius / zoomScale,
    );
    if (!widget.enabled) return CustomPaint(painter: painter);
    final selecting = _hasSelectionHere;
    return RawGestureDetector(
      behavior: HitTestBehavior.translucent,
      gestures: <Type, GestureRecognizerFactory>{
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(
                duration: ComicImageAreaGeometry.longPressDuration,
              ),
              (recognizer) => recognizer
                ..onLongPressStart = _onLongPressStart
                ..onLongPressMoveUpdate = _onLongPressMoveUpdate
                ..onLongPressEnd = _onLongPressEnd,
            ),
        // Drags and taps compete with page swipes only while a selection
        // is up: then a drag from a handle and a tap outside belong to it.
        if (selecting)
          PanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                PanGestureRecognizer.new,
                (recognizer) => recognizer
                  ..onDown = _onPanDown
                  ..onUpdate = _onPanUpdate
                  ..onEnd = _onPanEnd
                  ..onCancel = _onPanCancel,
              ),
        if (selecting)
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (recognizer) => recognizer..onTapUp = _onTapUp,
              ),
      },
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(painter: painter, child: const SizedBox.expand()),
          // Saved highlights take taps only where they are drawn.
          if (!selecting)
            for (final highlight in highlights)
              for (final rect in _rectsOf(highlight.range))
                Positioned.fromRect(
                  rect: rect,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onHighlightTap(highlight),
                    child: const SizedBox.expand(),
                  ),
                ),
        ],
      ),
    );
  }
}

class _TextOverlayPainter extends CustomPainter {
  const _TextOverlayPainter({
    required this.highlights,
    required this.searchMark,
    required this.searchMarkColor,
    required this.selection,
    required this.selectionColor,
    required this.handleRadius,
  });

  final List<({List<Rect> rects, Color color})> highlights;
  final List<Rect> searchMark;
  final Color searchMarkColor;
  final List<Rect> selection;
  final Color selectionColor;
  final double handleRadius;

  @override
  void paint(Canvas canvas, Size size) {
    for (final highlight in highlights) {
      final paint = Paint()..color = highlight.color;
      for (final rect in highlight.rects) {
        canvas.drawRect(rect, paint);
      }
    }
    final markPaint = Paint()..color = searchMarkColor;
    for (final rect in searchMark) {
      canvas.drawRect(rect, markPaint);
    }
    if (selection.isEmpty) return;
    final selectionPaint = Paint()..color = selectionColor;
    for (final rect in selection) {
      canvas.drawRect(rect, selectionPaint);
    }
    final knob = Paint()..color = selectionColor.withValues(alpha: 1);
    final bar = Paint()
      ..color = knob.color
      ..strokeWidth = handleRadius / 3;
    final first = selection.first;
    final last = selection.last;
    canvas.drawLine(first.topLeft, first.bottomLeft, bar);
    canvas.drawCircle(first.bottomLeft, handleRadius, knob);
    canvas.drawLine(last.topRight, last.bottomRight, bar);
    canvas.drawCircle(last.bottomRight, handleRadius, knob);
  }

  @override
  bool shouldRepaint(_TextOverlayPainter oldDelegate) =>
      oldDelegate.highlights != highlights ||
      oldDelegate.searchMark != searchMark ||
      oldDelegate.searchMarkColor != searchMarkColor ||
      oldDelegate.selection != selection ||
      oldDelegate.selectionColor != selectionColor ||
      oldDelegate.handleRadius != handleRadius;
}
