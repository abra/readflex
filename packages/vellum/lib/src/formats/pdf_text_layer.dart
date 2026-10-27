import 'package:meta/meta.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart'
    show PdfPageBaseExtensions, PdfRect;

import '../search/text_search.dart';
import 'pdf_book.dart';

/// A rectangle on a displayed PDF page, in points with the origin at the
/// top-left corner (the page's `/Rotate` already applied), so it scales
/// to pixels with one factor.
@immutable
class PdfBox {
  const PdfBox(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  bool get isEmpty => width <= 0 || height <= 0;

  bool contains(double x, double y) =>
      x >= left && x < right && y >= top && y < bottom;

  PdfBox union(PdfBox other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    return PdfBox(
      left < other.left ? left : other.left,
      top < other.top ? top : other.top,
      right > other.right ? right : other.right,
      bottom > other.bottom ? bottom : other.bottom,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PdfBox &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'PdfBox($left, $top, $right, $bottom)';
}

/// A span of a page's text, [end] exclusive.
@immutable
class PdfTextRange {
  const PdfTextRange(this.start, this.end) : assert(start <= end);

  final int start;
  final int end;

  int get length => end - start;
  bool get isEmpty => start == end;

  @override
  bool operator ==(Object other) =>
      other is PdfTextRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PdfTextRange($start, $end)';
}

/// One line of text and its box.
@immutable
class PdfTextLine {
  const PdfTextLine({required this.range, required this.box});

  final PdfTextRange range;
  final PdfBox box;
}

/// The sentence around a selection, for dictionary and translation
/// actions: as `readflex_selection_context.js` built it from the DOM.
@immutable
class PdfTextContext {
  const PdfTextContext({
    required this.contextText,
    required this.markedContextText,
  });

  /// The sentence (or the selection alone), whitespace collapsed.
  final String contextText;

  /// The same with the selection wrapped in `[[` and `]]`.
  final String markedContextText;
}

/// The text of one PDF page with a box per character: what selection,
/// search and anchors work on. The counterpart of the text layer
/// `pdf.js` drew over each page in the WebView reader.
///
/// [text] is pdfium's reading-order text with one `\n` per line break,
/// as `pdfrx_engine` formats it; [charBoxes] has one [PdfBox] per UTF-16
/// unit of [text], empty for whitespace pdfium generated between words.
/// Boxes are in display points, so a [PdfTextLayer] built from a `/Rotate`d
/// page already matches what `PdfPageImage` draws.
class PdfTextLayer {
  /// Builds a layer from a page's text and boxes; [load] does this from
  /// the engine, tests from literals.
  PdfTextLayer({
    required this.pageIndex,
    required this.text,
    required List<PdfBox> charBoxes,
  }) : assert(charBoxes.length == text.length),
       charBoxes = List.unmodifiable(charBoxes),
       lines = List.unmodifiable(_linesOf(text, charBoxes));

  /// Loads the text of [book]'s page [pageIndex] from pdfium.
  static Future<PdfTextLayer> load(PdfBook book, int pageIndex) async {
    final info = book.pages[pageIndex];
    final structured = await book.document.pages[pageIndex]
        .loadStructuredText();
    final mapper = _DisplayMapper(info);
    return PdfTextLayer(
      pageIndex: pageIndex,
      text: structured.fullText,
      charBoxes: [for (final rect in structured.charRects) mapper.box(rect)],
    );
  }

  final int pageIndex;
  final String text;
  final List<PdfBox> charBoxes;
  final List<PdfTextLine> lines;

  bool get isEmpty => text.trim().isEmpty;

  /// The character under ([x], [y]) in display points, or the nearest one
  /// on that line within a character's height; null off the text.
  int? charIndexAt(double x, double y) {
    for (final line in lines) {
      if (y < line.box.top || y >= line.box.bottom) continue;
      int? nearest;
      var nearestDistance = double.infinity;
      for (var i = line.range.start; i < line.range.end; i++) {
        final box = charBoxes[i];
        if (box.isEmpty) continue;
        if (box.contains(x, y)) return i;
        final distance = x < box.left ? box.left - x : x - box.right;
        if (distance < nearestDistance && distance <= box.height) {
          nearest = i;
          nearestDistance = distance;
        }
      }
      if (nearest != null) return nearest;
    }
    return null;
  }

  /// The word around [index]: letters, digits and marks, with apostrophes
  /// and hyphens inside a word; null when [index] is not on a word.
  PdfTextRange? wordAt(int index) {
    if (index < 0 || index >= text.length || !_isWordChar(index)) return null;
    var start = index;
    while (start > 0 && _joinsWord(start - 1)) {
      start--;
    }
    var end = index + 1;
    while (end < text.length && _joinsWord(end)) {
      end++;
    }
    return PdfTextRange(start, end);
  }

  /// The word under a point, see [charIndexAt] and [wordAt].
  PdfTextRange? wordAtPoint(double x, double y) {
    final index = charIndexAt(x, y);
    return index == null ? null : wordAt(index);
  }

  String textOf(PdfTextRange range) => text.substring(range.start, range.end);

  /// One box per line the range touches, for drawing selections and
  /// highlights.
  List<PdfBox> boxesOf(PdfTextRange range) {
    final boxes = <PdfBox>[];
    for (final line in lines) {
      final start = range.start > line.range.start
          ? range.start
          : line.range.start;
      final end = range.end < line.range.end ? range.end : line.range.end;
      if (start >= end) continue;
      PdfBox? box;
      for (var i = start; i < end; i++) {
        final charBox = charBoxes[i];
        if (charBox.isEmpty) continue;
        box = box == null ? charBox : box.union(charBox);
      }
      if (box != null) boxes.add(box);
    }
    return boxes;
  }

  /// The sentence around [range], for context-aware text actions.
  ///
  /// Sentences end at `.`, `!`, `?` or `…` (with closing quotes or
  /// brackets) followed by whitespace; line breaks are whitespace, as in
  /// a reflowed book. Up to [contextSideChars] on each side are read; a
  /// sentence cut by that window, or an empty selection, falls back to the
  /// selection alone, as the WebView did.
  PdfTextContext contextOf(PdfTextRange range) {
    final selected = textOf(range);
    final fallback = PdfTextContext(
      contextText: _collapse(selected),
      markedContextText: selected.trim().isEmpty
          ? ''
          : '[[${_collapse(selected)}]]',
    );
    if (selected.trim().isEmpty) return fallback;
    final windowStart = range.start - contextSideChars < 0
        ? 0
        : range.start - contextSideChars;
    final windowEnd = range.end + contextSideChars > text.length
        ? text.length
        : range.end + contextSideChars;
    var sentenceStart = windowStart;
    var sentenceEnd = windowEnd;
    for (final match in _sentenceEnd.allMatches(text, windowStart)) {
      if (match.end <= range.start) {
        sentenceStart = match.end;
      } else if (match.start >= range.end) {
        sentenceEnd = match.start + match.group(1)!.length;
        break;
      }
      if (match.start >= windowEnd) break;
    }
    final beforeClipped = windowStart > 0 && sentenceStart == windowStart;
    final afterClipped = windowEnd < text.length && sentenceEnd == windowEnd;
    if (beforeClipped || afterClipped) return fallback;
    final before = text.substring(sentenceStart, range.start);
    final after = text.substring(range.end, sentenceEnd);
    // The selection keeps its edge spaces inside the brackets, as the
    // WebView's did; only the whole string is trimmed.
    final selection = selected.replaceAll(_whitespaceRun, ' ');
    return PdfTextContext(
      contextText: _collapse('$before$selected$after'),
      markedContextText: _collapse('$before[[$selection]]$after'),
    );
  }

  /// Matches of [query] on this page, see [searchText].
  List<TextSearchMatch> search(String query) => searchText(text, query);

  /// The first occurrence of [exact] on the page, comparing with
  /// whitespace runs collapsed, for anchors saved as text; null if absent.
  PdfTextRange? rangeOfText(String exact) {
    final needle = _collapse(exact).trim();
    if (needle.isEmpty) return null;
    final folded = _foldWhitespace(text);
    final index = folded.text.indexOf(needle);
    if (index < 0) return null;
    return PdfTextRange(
      folded.starts[index],
      folded.ends[index + needle.length - 1],
    );
  }

  /// Characters read on each side of a selection for its sentence.
  static const contextSideChars = 2048;

  bool _isWordChar(int index) => _wordChar.hasMatch(text[index]);

  bool _joinsWord(int index) {
    if (_isWordChar(index)) return true;
    if (!_wordJoiner.hasMatch(text[index])) return false;
    return index > 0 &&
        index + 1 < text.length &&
        _isWordChar(index - 1) &&
        _isWordChar(index + 1);
  }

  static final _wordChar = RegExp(r'[\p{L}\p{N}\p{M}]', unicode: true);
  static final _wordJoiner = RegExp("[''’‐-]", unicode: true);
  static final _sentenceEnd = RegExp(
    '([.!?…]+["\'”’)\\]]*)(?:\\s+|\$)',
    unicode: true,
  );
  static final _whitespaceRun = RegExp(r'\s+');

  static String _collapse(String value) =>
      value.replaceAll(_whitespaceRun, ' ').trim();

  static List<PdfTextLine> _linesOf(String text, List<PdfBox> boxes) {
    final lines = <PdfTextLine>[];
    var start = 0;
    for (var i = 0; i <= text.length; i++) {
      if (i < text.length && text[i] != '\n') continue;
      if (i > start) {
        PdfBox? box;
        for (var j = start; j < i; j++) {
          if (boxes[j].isEmpty) continue;
          box = box == null ? boxes[j] : box.union(boxes[j]);
        }
        if (box != null) {
          lines.add(PdfTextLine(range: PdfTextRange(start, i), box: box));
        }
      }
      start = i + 1;
    }
    return lines;
  }
}

/// [text] with whitespace runs folded to one space and a map back.
({String text, List<int> starts, List<int> ends}) _foldWhitespace(String text) {
  final out = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  final whitespace = RegExp(r'\s');
  for (var i = 0; i < text.length; i++) {
    if (whitespace.hasMatch(text[i])) {
      if (starts.isNotEmpty && whitespace.hasMatch(text[starts.last])) {
        ends[ends.length - 1] = i + 1;
        continue;
      }
      out.write(' ');
    } else {
      out.write(text[i]);
    }
    starts.add(i);
    ends.add(i + 1);
  }
  return (text: out.toString(), starts: starts, ends: ends);
}

/// Maps pdfium's page coordinates (origin bottom-left, y up, before
/// `/Rotate`) to display points (origin top-left, after it).
class _DisplayMapper {
  _DisplayMapper(PdfPageInfo page)
    : rotation = page.rotation,
      unrotatedWidth = page.rotation.isOdd ? page.height : page.width,
      unrotatedHeight = page.rotation.isOdd ? page.width : page.height;

  final int rotation;
  final double unrotatedWidth;
  final double unrotatedHeight;

  PdfBox box(PdfRect rect) {
    if (rect.left >= rect.right || rect.bottom >= rect.top) {
      return const PdfBox(0, 0, 0, 0);
    }
    final a = _point(rect.left, rect.bottom);
    final b = _point(rect.right, rect.top);
    return PdfBox(
      a.$1 < b.$1 ? a.$1 : b.$1,
      a.$2 < b.$2 ? a.$2 : b.$2,
      a.$1 > b.$1 ? a.$1 : b.$1,
      a.$2 > b.$2 ? a.$2 : b.$2,
    );
  }

  (double, double) _point(double x, double y) => switch (rotation) {
    1 => (y, x),
    2 => (unrotatedWidth - x, y),
    3 => (unrotatedHeight - y, unrotatedWidth - x),
    _ => (x, unrotatedHeight - y),
  };
}
