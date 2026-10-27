import 'dart:ui';

import 'package:flutter/foundation.dart';

/// A saved rectangle on a page image, in fractions of the image, as the
/// app stores it (`HighlightImageArea`).
@immutable
class ComicImageArea {
  const ComicImageArea({
    required this.id,
    required this.page,
    required this.rect,
    required this.color,
  });

  final String id;
  final int page;

  /// `x`, `y`, `width`, `height` in `0…1` of the displayed image.
  final Rect rect;
  final Color color;

  @override
  bool operator ==(Object other) =>
      other is ComicImageArea &&
      other.id == id &&
      other.page == page &&
      other.rect == rect &&
      other.color == color;

  @override
  int get hashCode => Object.hash(id, page, rect, color);
}

/// Corner a draft is resized from.
enum ComicAreaHandle { nw, ne, sw, se }

/// Geometry of image-area drafts, in fractions of the image, with the
/// numbers of the WebView reader (`book.js`).
abstract final class ComicImageAreaGeometry {
  /// A new draft is this big, centred on the press.
  static const defaultWidth = 0.213333;
  static const defaultHeight = 0.146667;

  /// A draft can shrink to this on either side.
  static const minSize = 0.015;

  /// The long press that starts a draft.
  static const longPressDuration = Duration(milliseconds: 280);

  /// Screen pixels: the border, the L-shaped corner marks, and the corner
  /// drag zones, which are capped to a share of the rectangle so opposite
  /// corners never overlap.
  static const borderWidth = 6.0;
  static const cornerMarkLength = 22.0;
  static const cornerMarkStroke = 4.0;
  static const handleTarget = 64.0;
  static const handleMaxFraction = 0.4;

  /// The draft a press at [point] (fractions of the image) creates:
  /// default size, centred, kept inside the image.
  static Rect draftAt(Offset point) {
    final x = (point.dx - defaultWidth / 2).clamp(0.0, 1 - defaultWidth);
    final y = (point.dy - defaultHeight / 2).clamp(0.0, 1 - defaultHeight);
    return Rect.fromLTWH(x, y, defaultWidth, defaultHeight);
  }

  static Rect move(Rect rect, Offset delta) => Rect.fromLTWH(
    (rect.left + delta.dx).clamp(0.0, 1 - rect.width),
    (rect.top + delta.dy).clamp(0.0, 1 - rect.height),
    rect.width,
    rect.height,
  );

  static Rect resize(Rect rect, ComicAreaHandle handle, Offset delta) {
    var left = rect.left;
    var top = rect.top;
    var right = rect.right;
    var bottom = rect.bottom;
    final west = handle == ComicAreaHandle.nw || handle == ComicAreaHandle.sw;
    final north = handle == ComicAreaHandle.nw || handle == ComicAreaHandle.ne;
    if (west) {
      left = (left + delta.dx).clamp(0.0, right - minSize);
    } else {
      right = (right + delta.dx).clamp(left + minSize, 1.0);
    }
    if (north) {
      top = (top + delta.dy).clamp(0.0, bottom - minSize);
    } else {
      bottom = (bottom + delta.dy).clamp(top + minSize, 1.0);
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  /// Side of the square corner zones for a draft drawn at [drawnSize]
  /// (logical pixels of the layer) under [zoomScale].
  static double handleSize(Size drawnSize, double zoomScale) {
    final target = handleTarget / zoomScale;
    final cap = drawnSize.shortestSide * handleMaxFraction;
    return target < cap ? target : cap;
  }

  /// The corner zone under [point] of a draft drawn at [drawn], or null.
  static ComicAreaHandle? handleAt(Offset point, Rect drawn, double zoomScale) {
    final size = handleSize(drawn.size, zoomScale);
    if (!drawn.contains(point)) return null;
    final west = point.dx < drawn.left + size;
    final east = point.dx > drawn.right - size;
    final north = point.dy < drawn.top + size;
    final south = point.dy > drawn.bottom - size;
    if (north && west) return ComicAreaHandle.nw;
    if (north && east) return ComicAreaHandle.ne;
    if (south && west) return ComicAreaHandle.sw;
    if (south && east) return ComicAreaHandle.se;
    return null;
  }

  /// The topmost saved area under [point] (fractions), or null.
  static ComicImageArea? areaAt(Offset point, List<ComicImageArea> areas) {
    for (final area in areas.reversed) {
      if (area.rect.contains(point)) return area;
    }
    return null;
  }
}

/// The image-area selection being made: which page, where, and whether a
/// sheet above it is keeping it alive.
///
/// Owned by the app for the whole reader like a `TextEditingController`;
/// `ComicImageAreaLayer` edits it and `FixedPagesView` locks input while
/// it exists. The app saves it or clears it.
class ComicImageAreaDraft extends ChangeNotifier {
  int? _page;
  Rect? _rect;
  bool _retained = false;
  Color _color = const Color(0xFFFFE600);
  double _opacity = 0.35;

  int? get page => _page;

  Rect? get rect => _rect;

  bool get isActive => _rect != null;

  /// While retained, taps outside the draft do not dismiss it.
  bool get retained => _retained;

  Color get color => _color;

  double get opacity => _opacity;

  void start(int page, Rect rect) {
    _page = page;
    _rect = rect;
    notifyListeners();
  }

  void update(Rect rect) {
    if (_rect == null || rect == _rect) return;
    _rect = rect;
    notifyListeners();
  }

  void clear() {
    if (_rect == null) return;
    _page = null;
    _rect = null;
    _retained = false;
    notifyListeners();
  }

  void retain(bool retained) {
    if (_retained == retained) return;
    _retained = retained;
    notifyListeners();
  }

  /// The colour and opacity the draft is drawn with, from the app's
  /// highlight palette.
  void setStyle({Color? color, double? opacity}) {
    final newColor = color ?? _color;
    final newOpacity = opacity ?? _opacity;
    if (newColor == _color && newOpacity == _opacity) return;
    _color = newColor;
    _opacity = newOpacity;
    notifyListeners();
  }
}
