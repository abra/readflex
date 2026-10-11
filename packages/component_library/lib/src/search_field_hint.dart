import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The hint of a [SearchField]: [text] when it fits on one line, otherwise
/// [compactText], ellipsized only if even that does not fit. Screen readers
/// always hear [text].
///
/// A render object rather than a `LayoutBuilder`: the input decorator asks
/// its hint for intrinsic widths, dry layout and baselines, none of which a
/// `LayoutBuilder` can answer.
class SearchFieldHint extends LeafRenderObjectWidget {
  const SearchFieldHint({
    required this.text,
    required this.compactText,
    required this.style,
    super.key,
  });

  final String text;
  final String compactText;
  final TextStyle style;

  // Resolved the way a `Text` resolves its style, so the hint draws exactly
  // like the `hintText` the decorator would otherwise build.
  TextStyle _effectiveStyle(BuildContext context) {
    var effective = style.inherit
        ? DefaultTextStyle.of(context).style.merge(style)
        : style;
    if (MediaQuery.boldTextOf(context)) {
      effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    return effective;
  }

  TextHeightBehavior? _heightBehavior(BuildContext context) =>
      DefaultTextStyle.of(context).textHeightBehavior ??
      DefaultTextHeightBehavior.maybeOf(context);

  @override
  RenderSearchFieldHint createRenderObject(BuildContext context) =>
      RenderSearchFieldHint(
        text: text,
        compactText: compactText,
        style: _effectiveStyle(context),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
        textHeightBehavior: _heightBehavior(context),
        textWidthBasis: DefaultTextStyle.of(context).textWidthBasis,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSearchFieldHint renderObject,
  ) {
    renderObject
      ..text = text
      ..compactText = compactText
      ..style = _effectiveStyle(context)
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context)
      ..locale = Localizations.maybeLocaleOf(context)
      ..textHeightBehavior = _heightBehavior(context)
      ..textWidthBasis = DefaultTextStyle.of(context).textWidthBasis;
  }
}

/// Lays out and paints one of two single-line strings; see [SearchFieldHint].
class RenderSearchFieldHint extends RenderBox {
  RenderSearchFieldHint({
    required String text,
    required String compactText,
    required TextStyle style,
    required TextDirection textDirection,
    required TextScaler textScaler,
    Locale? locale,
    TextHeightBehavior? textHeightBehavior,
    TextWidthBasis textWidthBasis = TextWidthBasis.parent,
  }) : _text = text,
       _compactText = compactText,
       _style = style,
       _textDirection = textDirection,
       _textScaler = textScaler,
       _locale = locale,
       _textHeightBehavior = textHeightBehavior,
       _textWidthBasis = textWidthBasis {
    _full = _painterFor(text);
    _compact = _painterFor(compactText);
  }

  late final TextPainter _full;
  late final TextPainter _compact;
  TextPainter? _shown;

  /// The string painted after the last layout.
  @visibleForTesting
  String? get shownText =>
      _shown == null ? null : (identical(_shown, _full) ? _text : _compactText);

  String get text => _text;
  String _text;
  set text(String value) {
    if (value == _text) return;
    _text = value;
    _full.text = _span(value);
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  String get compactText => _compactText;
  String _compactText;
  set compactText(String value) {
    if (value == _compactText) return;
    _compactText = value;
    _compact.text = _span(value);
    markNeedsLayout();
  }

  TextStyle get style => _style;
  TextStyle _style;
  set style(TextStyle value) {
    if (value == _style) return;
    _style = value;
    _full.text = _span(_text);
    _compact.text = _span(_compactText);
    markNeedsLayout();
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    _full.textDirection = value;
    _compact.textDirection = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  TextScaler get textScaler => _textScaler;
  TextScaler _textScaler;
  set textScaler(TextScaler value) {
    if (value == _textScaler) return;
    _textScaler = value;
    _full.textScaler = value;
    _compact.textScaler = value;
    markNeedsLayout();
  }

  Locale? get locale => _locale;
  Locale? _locale;
  set locale(Locale? value) {
    if (value == _locale) return;
    _locale = value;
    _full
      ..locale = value
      ..text = _span(_text);
    _compact
      ..locale = value
      ..text = _span(_compactText);
    markNeedsLayout();
  }

  TextHeightBehavior? get textHeightBehavior => _textHeightBehavior;
  TextHeightBehavior? _textHeightBehavior;
  set textHeightBehavior(TextHeightBehavior? value) {
    if (value == _textHeightBehavior) return;
    _textHeightBehavior = value;
    _full.textHeightBehavior = value;
    _compact.textHeightBehavior = value;
    markNeedsLayout();
  }

  TextWidthBasis get textWidthBasis => _textWidthBasis;
  TextWidthBasis _textWidthBasis;
  set textWidthBasis(TextWidthBasis value) {
    if (value == _textWidthBasis) return;
    _textWidthBasis = value;
    _full.textWidthBasis = value;
    _compact.textWidthBasis = value;
    markNeedsLayout();
  }

  TextSpan _span(String value) =>
      TextSpan(text: value, style: _style, locale: _locale);

  TextPainter _painterFor(String value) => TextPainter(
    text: _span(value),
    textDirection: _textDirection,
    textScaler: _textScaler,
    locale: _locale,
    textHeightBehavior: _textHeightBehavior,
    textWidthBasis: _textWidthBasis,
    maxLines: 1,
    ellipsis: '…',
  );

  // Lays out the full text, then the compact one only if the full one would
  // be cut. Like a paragraph, the painter spans the minimum width, so start
  // alignment lands on the right in RTL inside the decorator's tight width.
  // Painters keep their layout while the widths are unchanged.
  TextPainter _choose(
    TextPainter full,
    TextPainter compact,
    BoxConstraints constraints,
  ) {
    full.layout(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (!full.didExceedMaxLines) return full;
    compact.layout(
      minWidth: constraints.minWidth,
      maxWidth: constraints.maxWidth,
    );
    return compact;
  }

  // Dry layout, intrinsics and dry baselines must not disturb the painters
  // used for painting, so they measure throwaway copies.
  T _measure<T>(
    BoxConstraints constraints,
    T Function(TextPainter shown) read,
  ) {
    final full = _painterFor(_text);
    final compact = _painterFor(_compactText);
    try {
      return read(_choose(full, compact, constraints));
    } finally {
      full.dispose();
      compact.dispose();
    }
  }

  double _naturalWidth(String value) {
    final painter = _painterFor(value)..layout();
    try {
      return painter.width;
    } finally {
      painter.dispose();
    }
  }

  @override
  void performLayout() {
    final shown = _shown = _choose(_full, _compact, constraints);
    size = constraints.constrain(shown.size);
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      constraints.constrain(_measure(constraints, (p) => p.size));

  @override
  double computeMinIntrinsicWidth(double height) => _naturalWidth(_compactText);

  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth(_text);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _measure(BoxConstraints(maxWidth: width), (p) => p.height);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _measure(BoxConstraints(maxWidth: width), (p) => p.height);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      _shown!.computeDistanceToActualBaseline(baseline);

  @override
  double? computeDryBaseline(
    covariant BoxConstraints constraints,
    TextBaseline baseline,
  ) => _measure(
    constraints,
    (p) => p.computeDistanceToActualBaseline(baseline),
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    _shown!.paint(context.canvas, offset);
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..label = _text
      ..textDirection = _textDirection;
  }

  @override
  void dispose() {
    _full.dispose();
    _compact.dispose();
    super.dispose();
  }
}
