import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'fixed_pages_controller.dart';
import 'comic_image_area.dart';
import 'fixed_pages_view.dart';
import 'repaint_after_build.dart';

/// Saved image areas and the selection draft over one page image.
///
/// Placed by `FixedPagesView.pageOverlayBuilder`, so it is scaled with the
/// page while zoomed; sizes meant in screen pixels are divided by the zoom.
/// A long press starts a draft at the finger and drags it; afterwards a
/// drag inside moves it, a drag from a corner zone resizes it, a tap
/// outside cancels it unless the draft is retained. A long press on a
/// saved area reports that area instead.
class ComicImageAreaLayer extends StatefulWidget {
  const ComicImageAreaLayer({
    super.key,
    required this.page,
    required this.imageRect,
    required this.controller,
    required this.draft,
    this.areas = const [],
    this.onDraftCommitted,
    this.onDraftCancelled,
    this.onAreaPressed,
    this.enabled = true,
  });

  final int page;

  /// Where the image is drawn inside this layer.
  final Rect imageRect;

  final FixedPagesController controller;
  final ComicImageAreaDraft draft;

  /// Saved areas of this page, oldest first; later ones are drawn and hit
  /// on top.
  final List<ComicImageArea> areas;

  /// The draft was created, moved or resized and the finger lifted.
  /// The second argument is where it sits in the whole view, for chrome
  /// that must keep clear of it; null outside a `FixedPagesView`.
  final ComicDraftCommitted? onDraftCommitted;

  /// A tap outside dismissed the draft.
  final VoidCallback? onDraftCancelled;

  /// A long press on a saved area, with where the area sits in the whole
  /// view (null outside a `FixedPagesView`).
  final ComicAreaPressed? onAreaPressed;

  /// False leaves the areas drawn but takes no input (text pages).
  final bool enabled;

  @override
  State<ComicImageAreaLayer> createState() => _ComicImageAreaLayerState();
}

/// A committed draft: its rectangle in fractions of the image and, when
/// the layer sits in a `FixedPagesView`, in fractions of the view.
typedef ComicDraftCommitted = void Function(Rect rect, Rect? viewportRect);

/// A pressed saved area and where it sits in the whole view.
typedef ComicAreaPressed =
    void Function(ComicImageArea area, Rect? viewportRect);

class _ComicImageAreaLayerState extends State<ComicImageAreaLayer>
    with RepaintAfterBuild {
  _Edit? _edit;

  ComicImageAreaDraft get _draft => widget.draft;

  bool get _hasDraftHere => _draft.isActive && _draft.page == widget.page;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_onDraftChanged);
  }

  @override
  void didUpdateWidget(ComicImageAreaLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft.removeListener(_onDraftChanged);
      widget.draft.addListener(_onDraftChanged);
    }
  }

  @override
  void dispose() {
    _draft.removeListener(_onDraftChanged);
    super.dispose();
  }

  void _onDraftChanged() {
    if (!_draft.isActive) _edit = null;
    repaint();
  }

  // Coordinates.

  Offset _toImage(Offset local) => Offset(
    (local.dx - widget.imageRect.left) / widget.imageRect.width,
    (local.dy - widget.imageRect.top) / widget.imageRect.height,
  );

  Offset _deltaToImage(Offset delta) => Offset(
    delta.dx / widget.imageRect.width,
    delta.dy / widget.imageRect.height,
  );

  Rect _toLayer(Rect rect) => Rect.fromLTWH(
    widget.imageRect.left + rect.left * widget.imageRect.width,
    widget.imageRect.top + rect.top * widget.imageRect.height,
    rect.width * widget.imageRect.width,
    rect.height * widget.imageRect.height,
  );

  // Long press: a new draft, or a saved area.

  void _onLongPressStart(LongPressStartDetails details) {
    if (_hasDraftHere) return;
    final point = _toImage(details.localPosition);
    if (point.dx < 0 || point.dx > 1 || point.dy < 0 || point.dy > 1) return;
    final area = ComicImageAreaGeometry.areaAt(point, [
      for (final area in widget.areas)
        if (area.page == widget.page) area,
    ]);
    if (area != null) {
      widget.onAreaPressed?.call(area, _viewportRectOf(area.rect));
      return;
    }
    final rect = ComicImageAreaGeometry.draftAt(point);
    _draft.start(widget.page, rect);
    widget.controller.lockInput(true);
    _edit = _Edit(
      mode: _EditMode.move,
      start: details.localPosition,
      startRect: rect,
    );
    _commit(rect);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    _updateEdit(details.localPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _endEdit();
  }

  // After release: move from inside, resize from a corner, cancel outside.

  void _onPanDown(DragDownDetails details) {
    if (!_hasDraftHere) return;
    final drawn = _toLayer(_draft.rect!);
    final handle = ComicImageAreaGeometry.handleAt(
      details.localPosition,
      drawn,
      widget.controller.zoomScale,
    );
    if (handle != null) {
      _edit = _Edit(
        mode: _EditMode.resize,
        handle: handle,
        start: details.localPosition,
        startRect: _draft.rect!,
      );
    } else if (drawn.contains(details.localPosition)) {
      _edit = _Edit(
        mode: _EditMode.move,
        start: details.localPosition,
        startRect: _draft.rect!,
      );
    } else {
      _edit = null;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _updateEdit(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    _endEdit();
  }

  void _onPanCancel() {
    _edit = null;
  }

  void _onTapUp(TapUpDetails details) {
    if (!_hasDraftHere) return;
    if (_toLayer(_draft.rect!).contains(details.localPosition)) return;
    if (_draft.retained) return;
    _draft.clear();
    widget.controller.lockInput(false);
    widget.onDraftCancelled?.call();
  }

  void _updateEdit(Offset local) {
    final edit = _edit;
    if (edit == null || !_hasDraftHere) return;
    final delta = _deltaToImage(local - edit.start);
    final rect = switch (edit.mode) {
      _EditMode.move => ComicImageAreaGeometry.move(edit.startRect, delta),
      _EditMode.resize => ComicImageAreaGeometry.resize(
        edit.startRect,
        edit.handle!,
        delta,
      ),
    };
    _draft.update(rect);
  }

  void _endEdit() {
    if (_edit == null || !_hasDraftHere) return;
    _edit = null;
    _commit(_draft.rect!);
  }

  void _commit(Rect rect) {
    widget.onDraftCommitted?.call(rect, _viewportRectOf(rect));
  }

  Rect? _viewportRectOf(Rect rect) {
    final box = context.findRenderObject();
    if (box is! RenderBox) return null;
    return FixedPagesViewportScope.fractionsOf(context, _toLayer(rect), box);
  }

  @override
  Widget build(BuildContext context) {
    final zoomScale = widget.controller.zoomScale;
    final painter = _ImageAreaPainter(
      imageRect: widget.imageRect,
      areas: [
        for (final area in widget.areas)
          if (area.page == widget.page) area,
      ],
      draft: _hasDraftHere ? _draft.rect : null,
      draftColor: _draft.color,
      draftOpacity: _draft.opacity,
      zoomScale: zoomScale,
    );
    if (!widget.enabled) return CustomPaint(painter: painter);
    final editing = _hasDraftHere;
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
        // Drags and taps compete with page swipes only while a draft is
        // being edited: then they belong to the draft.
        if (editing)
          PanGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                PanGestureRecognizer.new,
                (recognizer) => recognizer
                  ..onDown = _onPanDown
                  ..onUpdate = _onPanUpdate
                  ..onEnd = _onPanEnd
                  ..onCancel = _onPanCancel,
              ),
        if (editing)
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (recognizer) => recognizer..onTapUp = _onTapUp,
              ),
      },
      child: CustomPaint(painter: painter, child: const SizedBox.expand()),
    );
  }
}

enum _EditMode { move, resize }

class _Edit {
  _Edit({
    required this.mode,
    required this.start,
    required this.startRect,
    this.handle,
  });

  final _EditMode mode;
  final ComicAreaHandle? handle;
  final Offset start;
  final Rect startRect;
}

class _ImageAreaPainter extends CustomPainter {
  _ImageAreaPainter({
    required this.imageRect,
    required this.areas,
    required this.draft,
    required this.draftColor,
    required this.draftOpacity,
    required this.zoomScale,
  });

  final Rect imageRect;
  final List<ComicImageArea> areas;
  final Rect? draft;
  final Color draftColor;
  final double draftOpacity;
  final double zoomScale;

  Rect _toLayer(Rect rect) => Rect.fromLTWH(
    imageRect.left + rect.left * imageRect.width,
    imageRect.top + rect.top * imageRect.height,
    rect.width * imageRect.width,
    rect.height * imageRect.height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(imageRect);
    for (final area in areas) {
      canvas.drawRect(
        _toLayer(area.rect),
        Paint()..color = area.color.withValues(alpha: 0.35),
      );
    }
    final draft = this.draft;
    if (draft != null) {
      final drawn = _toLayer(draft);
      canvas.drawRect(
        drawn,
        Paint()..color = draftColor.withValues(alpha: draftOpacity),
      );
      final border = ComicImageAreaGeometry.borderWidth / zoomScale;
      canvas.drawRect(
        drawn.deflate(border / 2),
        Paint()
          ..color = draftColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = border,
      );
      _paintCornerMarks(canvas, drawn);
    }
    canvas.restore();
  }

  /// L-shaped marks inside each corner, with a light halo so they read on
  /// any art.
  void _paintCornerMarks(Canvas canvas, Rect drawn) {
    final length = ComicImageAreaGeometry.cornerMarkLength / zoomScale;
    final stroke = ComicImageAreaGeometry.cornerMarkStroke / zoomScale;
    final inset = ComicImageAreaGeometry.borderWidth / zoomScale;
    final halo = Paint()
      ..color = const Color(0xF2FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 3 / zoomScale
      ..strokeCap = StrokeCap.square;
    final ink = Paint()
      ..color = draftColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;
    for (final (dx, dy) in const [(1, 1), (-1, 1), (1, -1), (-1, -1)]) {
      final corner = Offset(
        dx > 0 ? drawn.left + inset : drawn.right - inset,
        dy > 0 ? drawn.top + inset : drawn.bottom - inset,
      );
      final path = Path()
        ..moveTo(corner.dx + dx * length, corner.dy)
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx, corner.dy + dy * length);
      canvas.drawPath(path, halo);
      canvas.drawPath(path, ink);
    }
  }

  @override
  bool shouldRepaint(_ImageAreaPainter oldDelegate) =>
      oldDelegate.imageRect != imageRect ||
      oldDelegate.draft != draft ||
      oldDelegate.draftColor != draftColor ||
      oldDelegate.draftOpacity != draftOpacity ||
      oldDelegate.zoomScale != zoomScale ||
      !_sameAreas(oldDelegate.areas, areas);

  static bool _sameAreas(List<ComicImageArea> a, List<ComicImageArea> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
