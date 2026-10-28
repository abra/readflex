/// The properties the layout understands: each with its grammar, its
/// inheritance and its initial value, plus the shorthands that expand
/// into them. A declaration whose value fails its grammar is dropped,
/// as the cascade requires; unknown properties are dropped too.
library;

import 'css_syntax.dart';
import 'css_tokenizer.dart';
import 'css_values.dart';

/// A specified value: what a declaration says before the cascade.
sealed class CssValue {
  const CssValue();
}

/// A keyword, lowercased. The CSS-wide keywords `inherit`, `initial`
/// and `unset` are keywords too; the cascade treats them.
class CssKeyword extends CssValue {
  const CssKeyword(this.name);

  final String name;

  static const inherit = CssKeyword('inherit');
  static const initial = CssKeyword('initial');
  static const unset = CssKeyword('unset');

  bool get isCssWide =>
      name == 'inherit' || name == 'initial' || name == 'unset';

  @override
  bool operator ==(Object other) => other is CssKeyword && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => name;
}

class CssLengthValue extends CssValue {
  const CssLengthValue(this.length);

  final CssLength length;

  @override
  bool operator ==(Object other) =>
      other is CssLengthValue && other.length == length;

  @override
  int get hashCode => length.hashCode;

  @override
  String toString() => length.toString();
}

class CssNumberValue extends CssValue {
  const CssNumberValue(this.value);

  final double value;

  @override
  bool operator ==(Object other) =>
      other is CssNumberValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

class CssColorValue extends CssValue {
  const CssColorValue(this.color);

  final CssColor color;

  @override
  bool operator ==(Object other) =>
      other is CssColorValue && other.color == color;

  @override
  int get hashCode => color.hashCode;

  @override
  String toString() => color.toString();
}

class CssFontFamilyValue extends CssValue {
  const CssFontFamilyValue(this.families);

  final List<String> families;

  @override
  String toString() => families.join(', ');
}

/// A string value, for `list-style-type: "•"`.
class CssStringValue extends CssValue {
  const CssStringValue(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is CssStringValue && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '"$value"';
}

/// `text-decoration-line`: which lines.
class CssTextDecorationValue extends CssValue {
  const CssTextDecorationValue({
    this.underline = false,
    this.overline = false,
    this.lineThrough = false,
  });

  final bool underline;
  final bool overline;
  final bool lineThrough;

  @override
  bool operator ==(Object other) =>
      other is CssTextDecorationValue &&
      other.underline == underline &&
      other.overline == overline &&
      other.lineThrough == lineThrough;

  @override
  int get hashCode => Object.hash(underline, overline, lineThrough);

  @override
  String toString() => [
    if (underline) 'underline',
    if (overline) 'overline',
    if (lineThrough) 'line-through',
  ].join(' ');
}

typedef CssValueParser = CssValue? Function(List<CssComponentValue> values);

/// One longhand property.
class CssPropertyDefinition {
  const CssPropertyDefinition(
    this.name, {
    required this.inherited,
    required this.initial,
    required this.parse,
  });

  final String name;
  final bool inherited;
  final CssValue initial;
  final CssValueParser parse;
}

/// A parsed longhand declaration.
class CssParsedDeclaration {
  const CssParsedDeclaration(
    this.property,
    this.value, {
    this.isImportant = false,
  });

  final CssPropertyDefinition property;
  final CssValue value;
  final bool isImportant;

  @override
  String toString() =>
      '${property.name}: $value${isImportant ? ' !important' : ''}';
}

/// Parses a declaration into longhands: one for a longhand, several for
/// a shorthand, none when the property is unknown or the value invalid.
List<CssParsedDeclaration> parseCssDeclaration(CssDeclaration declaration) {
  final name = declaration.name;
  final values = cssWithoutWhitespace(declaration.value);
  if (values.isEmpty) return const [];
  final wide = _cssWideKeyword(values);
  final longhand = cssProperties[name];
  if (longhand != null) {
    final value = wide ?? longhand.parse(values);
    if (value == null) return const [];
    return [
      CssParsedDeclaration(
        longhand,
        value,
        isImportant: declaration.isImportant,
      ),
    ];
  }
  final shorthand = _shorthands[name];
  if (shorthand == null) return const [];
  final expanded = wide != null
      ? [for (final p in shorthand.longhands) (cssProperties[p]!, wide)]
      : shorthand.expand(values);
  if (expanded == null) return const [];
  return [
    for (final (property, value) in expanded)
      CssParsedDeclaration(
        property,
        value,
        isImportant: declaration.isImportant,
      ),
  ];
}

CssKeyword? _cssWideKeyword(List<CssComponentValue> values) {
  final ident = cssIdentOf(values);
  return switch (ident) {
    'inherit' => CssKeyword.inherit,
    'initial' => CssKeyword.initial,
    'unset' => CssKeyword.unset,
    _ => null,
  };
}

// Grammar pieces.

CssValueParser _keywords(Set<String> allowed) => (values) {
  final ident = cssIdentOf(values);
  return ident != null && allowed.contains(ident) ? CssKeyword(ident) : null;
};

CssValue? _length(
  List<CssComponentValue> values, {
  bool allowPercent = true,
  bool allowNegative = true,
  Set<String> keywords = const {},
}) {
  if (values.length != 1) return null;
  final ident = cssIdentOf(values);
  if (ident != null) return keywords.contains(ident) ? CssKeyword(ident) : null;
  final length = CssLength.parse(values.single, allowPercent: allowPercent);
  if (length == null || (!allowNegative && length.value < 0)) return null;
  return CssLengthValue(length);
}

CssValue? _color(List<CssComponentValue> values) {
  if (values.length != 1) return null;
  final color = CssColor.parse(values.single);
  return color == null ? null : CssColorValue(color);
}

CssValue? _fontSize(List<CssComponentValue> values) => _length(
  values,
  allowNegative: false,
  keywords: const {
    'xx-small',
    'x-small',
    'small',
    'medium',
    'large',
    'x-large',
    'xx-large',
    'xxx-large',
    'larger',
    'smaller',
  },
);

CssValue? _fontWeight(List<CssComponentValue> values) {
  if (values.length != 1) return null;
  final ident = cssIdentOf(values);
  if (ident != null) {
    return const {'normal', 'bold', 'bolder', 'lighter'}.contains(ident)
        ? CssKeyword(ident)
        : null;
  }
  final v = values.single;
  if (v is CssTokenValue && v.token.type == CssTokenType.number) {
    final n = v.token.number;
    return n >= 1 && n <= 1000 ? CssNumberValue(n) : null;
  }
  return null;
}

CssValue? _lineHeight(List<CssComponentValue> values) {
  if (values.length != 1) return null;
  if (cssIdentOf(values) == 'normal') return const CssKeyword('normal');
  final v = values.single;
  if (v is CssTokenValue && v.token.type == CssTokenType.number) {
    return v.token.number >= 0 ? CssNumberValue(v.token.number) : null;
  }
  return _length(values, allowNegative: false);
}

CssValue? _fontFamily(List<CssComponentValue> values) {
  final families = cssParseFontFamilies(values);
  return families == null ? null : CssFontFamilyValue(families);
}

CssValue? _borderWidth(List<CssComponentValue> values) {
  final ident = cssIdentOf(values);
  return switch (ident) {
    'thin' => const CssLengthValue(CssLength.px(1)),
    'medium' => const CssLengthValue(CssLength.px(3)),
    'thick' => const CssLengthValue(CssLength.px(5)),
    _ => _length(values, allowPercent: false, allowNegative: false),
  };
}

CssValue? _textDecoration(List<CssComponentValue> values) {
  if (cssIdentOf(values) == 'none') return const CssTextDecorationValue();
  var underline = false;
  var overline = false;
  var lineThrough = false;
  var any = false;
  for (final v in values) {
    if (v is! CssTokenValue) return null;
    final t = v.token;
    switch (t.type == CssTokenType.ident ? t.value.toLowerCase() : null) {
      case 'underline':
        underline = true;
        any = true;
      case 'overline':
        overline = true;
        any = true;
      case 'line-through':
        lineThrough = true;
        any = true;
      case 'blink':
        any = true;
      case 'solid' || 'double' || 'dotted' || 'dashed' || 'wavy':
        // A decoration style, in the shorthand; accepted and ignored.
        break;
      default:
        // A decoration color, in the shorthand.
        if (CssColor.parse(v) == null) return null;
    }
  }
  return any
      ? CssTextDecorationValue(
          underline: underline,
          overline: overline,
          lineThrough: lineThrough,
        )
      : null;
}

CssValue? _listStyleType(List<CssComponentValue> values) {
  if (values.length != 1) return null;
  final v = values.single;
  if (v is CssTokenValue && v.token.type == CssTokenType.string) {
    return CssStringValue(v.token.value);
  }
  final ident = cssIdentOf(values);
  return ident == null ? null : CssKeyword(ident);
}

CssValue? _verticalAlign(List<CssComponentValue> values) => _length(
  values,
  keywords: const {
    'baseline',
    'sub',
    'super',
    'text-top',
    'text-bottom',
    'middle',
    'top',
    'bottom',
  },
);

CssValue? _display(List<CssComponentValue> values) {
  final ident = cssIdentOf(values);
  if (ident == null) return null;
  return switch (ident) {
    'flex' || 'grid' || 'flow-root' || 'block' => const CssKeyword('block'),
    'inline-flex' ||
    'inline-grid' ||
    'inline-block' => const CssKeyword('inline-block'),
    'inline' ||
    'none' ||
    'list-item' ||
    'table' ||
    'inline-table' ||
    'table-row-group' ||
    'table-header-group' ||
    'table-footer-group' ||
    'table-row' ||
    'table-cell' ||
    'table-caption' ||
    'table-column' ||
    'table-column-group' ||
    'ruby' ||
    'ruby-base' ||
    'ruby-text' ||
    'contents' => CssKeyword(ident),
    _ => null,
  };
}

/// `break-before: page` and friends map onto the page-break values.
CssValue? _breakValue(List<CssComponentValue> values) {
  final ident = cssIdentOf(values);
  return switch (ident) {
    'auto' || 'always' || 'avoid' || 'left' || 'right' => CssKeyword(ident!),
    'page' || 'column' || 'region' => const CssKeyword('always'),
    'avoid-page' ||
    'avoid-column' ||
    'avoid-region' => const CssKeyword('avoid'),
    'recto' => const CssKeyword('right'),
    'verso' => const CssKeyword('left'),
    _ => null,
  };
}

const _edges = ['top', 'right', 'bottom', 'left'];

const _borderStyles = {
  'none',
  'hidden',
  'solid',
  'dashed',
  'dotted',
  'double',
  'groove',
  'ridge',
  'inset',
  'outset',
};

/// The longhands, by name.
final Map<String, CssPropertyDefinition> cssProperties = {
  for (final p in _definitions) p.name: p,
};

final List<CssPropertyDefinition> _definitions = [
  CssPropertyDefinition(
    'font-family',
    inherited: true,
    initial: const CssFontFamilyValue(['serif']),
    parse: _fontFamily,
  ),
  CssPropertyDefinition(
    'font-size',
    inherited: true,
    initial: const CssKeyword('medium'),
    parse: _fontSize,
  ),
  CssPropertyDefinition(
    'font-style',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: _keywords(const {'normal', 'italic', 'oblique'}),
  ),
  CssPropertyDefinition(
    'font-weight',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: _fontWeight,
  ),
  CssPropertyDefinition(
    'font-variant',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: _keywords(const {'normal', 'small-caps'}),
  ),
  CssPropertyDefinition(
    'color',
    inherited: true,
    initial: const CssColorValue(CssColor.black),
    parse: _color,
  ),
  CssPropertyDefinition(
    'background-color',
    inherited: false,
    initial: const CssColorValue(CssColor.transparent),
    parse: _color,
  ),
  CssPropertyDefinition(
    'text-align',
    inherited: true,
    initial: const CssKeyword('start'),
    parse: _keywords(const {
      'left',
      'right',
      'center',
      'justify',
      'start',
      'end',
    }),
  ),
  CssPropertyDefinition(
    'text-indent',
    inherited: true,
    initial: const CssLengthValue(CssLength.zero),
    parse: (values) => _length(values),
  ),
  CssPropertyDefinition(
    'line-height',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: _lineHeight,
  ),
  for (final edge in _edges)
    CssPropertyDefinition(
      'margin-$edge',
      inherited: false,
      initial: const CssLengthValue(CssLength.zero),
      parse: (values) => _length(values, keywords: const {'auto'}),
    ),
  for (final edge in _edges)
    CssPropertyDefinition(
      'padding-$edge',
      inherited: false,
      initial: const CssLengthValue(CssLength.zero),
      parse: (values) => _length(values, allowNegative: false),
    ),
  for (final edge in _edges)
    CssPropertyDefinition(
      'border-$edge-width',
      inherited: false,
      initial: const CssLengthValue(CssLength.px(3)),
      parse: _borderWidth,
    ),
  for (final edge in _edges)
    CssPropertyDefinition(
      'border-$edge-style',
      inherited: false,
      initial: const CssKeyword('none'),
      parse: _keywords(_borderStyles),
    ),
  for (final edge in _edges)
    CssPropertyDefinition(
      'border-$edge-color',
      inherited: false,
      initial: const CssColorValue(CssColor.currentColor),
      parse: _color,
    ),
  CssPropertyDefinition(
    'display',
    inherited: false,
    initial: const CssKeyword('inline'),
    parse: _display,
  ),
  CssPropertyDefinition(
    'page-break-before',
    inherited: false,
    initial: const CssKeyword('auto'),
    parse: _breakValue,
  ),
  CssPropertyDefinition(
    'page-break-after',
    inherited: false,
    initial: const CssKeyword('auto'),
    parse: _breakValue,
  ),
  CssPropertyDefinition(
    'page-break-inside',
    inherited: false,
    initial: const CssKeyword('auto'),
    parse: _keywords(const {'auto', 'avoid', 'avoid-page', 'avoid-column'}),
  ),
  for (final dimension in ['width', 'height'])
    CssPropertyDefinition(
      dimension,
      inherited: false,
      initial: const CssKeyword('auto'),
      parse: (values) =>
          _length(values, allowNegative: false, keywords: const {'auto'}),
    ),
  for (final dimension in ['max-width', 'max-height'])
    CssPropertyDefinition(
      dimension,
      inherited: false,
      initial: const CssKeyword('none'),
      parse: (values) =>
          _length(values, allowNegative: false, keywords: const {'none'}),
    ),
  for (final dimension in ['min-width', 'min-height'])
    CssPropertyDefinition(
      dimension,
      inherited: false,
      initial: const CssLengthValue(CssLength.zero),
      parse: (values) =>
          _length(values, allowNegative: false, keywords: const {'auto'}),
    ),
  CssPropertyDefinition(
    'float',
    inherited: false,
    initial: const CssKeyword('none'),
    parse: _keywords(const {
      'none',
      'left',
      'right',
      'inline-start',
      'inline-end',
    }),
  ),
  CssPropertyDefinition(
    'clear',
    inherited: false,
    initial: const CssKeyword('none'),
    parse: _keywords(const {
      'none',
      'left',
      'right',
      'both',
      'inline-start',
      'inline-end',
    }),
  ),
  CssPropertyDefinition(
    'text-decoration-line',
    inherited: false,
    initial: const CssTextDecorationValue(),
    parse: _textDecoration,
  ),
  CssPropertyDefinition(
    'letter-spacing',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: (values) =>
        _length(values, allowPercent: false, keywords: const {'normal'}),
  ),
  CssPropertyDefinition(
    'word-spacing',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: (values) => _length(values, keywords: const {'normal'}),
  ),
  CssPropertyDefinition(
    'white-space',
    inherited: true,
    initial: const CssKeyword('normal'),
    parse: _keywords(const {
      'normal',
      'nowrap',
      'pre',
      'pre-wrap',
      'pre-line',
      'break-spaces',
    }),
  ),
  CssPropertyDefinition(
    'vertical-align',
    inherited: false,
    initial: const CssKeyword('baseline'),
    parse: _verticalAlign,
  ),
  CssPropertyDefinition(
    'text-transform',
    inherited: true,
    initial: const CssKeyword('none'),
    parse: _keywords(const {
      'none',
      'capitalize',
      'uppercase',
      'lowercase',
      'full-width',
    }),
  ),
  CssPropertyDefinition(
    'hyphens',
    inherited: true,
    initial: const CssKeyword('manual'),
    parse: _keywords(const {'none', 'manual', 'auto'}),
  ),
  CssPropertyDefinition(
    'direction',
    inherited: true,
    initial: const CssKeyword('ltr'),
    parse: _keywords(const {'ltr', 'rtl'}),
  ),
  CssPropertyDefinition(
    'unicode-bidi',
    inherited: false,
    initial: const CssKeyword('normal'),
    parse: _keywords(const {
      'normal',
      'embed',
      'isolate',
      'bidi-override',
      'isolate-override',
      'plaintext',
    }),
  ),
  CssPropertyDefinition(
    'list-style-type',
    inherited: true,
    initial: const CssKeyword('disc'),
    parse: _listStyleType,
  ),
  CssPropertyDefinition(
    'visibility',
    inherited: true,
    initial: const CssKeyword('visible'),
    parse: _keywords(const {'visible', 'hidden', 'collapse'}),
  ),
  CssPropertyDefinition(
    'widows',
    inherited: true,
    initial: const CssNumberValue(2),
    parse: _positiveInteger,
  ),
  CssPropertyDefinition(
    'orphans',
    inherited: true,
    initial: const CssNumberValue(2),
    parse: _positiveInteger,
  ),
];

CssValue? _positiveInteger(List<CssComponentValue> values) {
  if (values.length != 1) return null;
  final v = values.single;
  if (v is CssTokenValue &&
      v.token.type == CssTokenType.number &&
      v.token.isInteger &&
      v.token.number >= 1) {
    return CssNumberValue(v.token.number);
  }
  return null;
}

class _Shorthand {
  const _Shorthand(this.longhands, this.expand);

  final List<String> longhands;
  final List<(CssPropertyDefinition, CssValue)>? Function(
    List<CssComponentValue> values,
  )
  expand;
}

List<(CssPropertyDefinition, CssValue)>? _expandEdges(
  String prefix,
  String suffix,
  List<CssComponentValue> values,
  CssValueParser parse,
) {
  if (values.isEmpty || values.length > 4) return null;
  final parsed = <CssValue>[];
  for (final v in values) {
    final value = parse([v]);
    if (value == null) return null;
    parsed.add(value);
  }
  final (top, right, bottom, left) = switch (parsed.length) {
    1 => (parsed[0], parsed[0], parsed[0], parsed[0]),
    2 => (parsed[0], parsed[1], parsed[0], parsed[1]),
    3 => (parsed[0], parsed[1], parsed[2], parsed[1]),
    _ => (parsed[0], parsed[1], parsed[2], parsed[3]),
  };
  return [
    (cssProperties['${prefix}top$suffix']!, top),
    (cssProperties['${prefix}right$suffix']!, right),
    (cssProperties['${prefix}bottom$suffix']!, bottom),
    (cssProperties['${prefix}left$suffix']!, left),
  ];
}

/// `border`, `border-top` …: width, style and color in any order.
List<(CssPropertyDefinition, CssValue)>? _expandBorder(
  List<String> edges,
  List<CssComponentValue> values,
) {
  if (values.isEmpty || values.length > 3) return null;
  CssValue width = const CssLengthValue(CssLength.px(3));
  CssValue style = const CssKeyword('none');
  CssValue color = const CssColorValue(CssColor.currentColor);
  for (final v in values) {
    final ident = cssIdentOf([v]);
    if (ident != null && _borderStyles.contains(ident)) {
      style = CssKeyword(ident);
    } else if (_borderWidth([v]) case final w?) {
      width = w;
    } else if (_color([v]) case final c?) {
      color = c;
    } else {
      return null;
    }
  }
  return [
    for (final edge in edges) ...[
      (cssProperties['border-$edge-width']!, width),
      (cssProperties['border-$edge-style']!, style),
      (cssProperties['border-$edge-color']!, color),
    ],
  ];
}

/// `font`: `[style || variant || weight] size [/ line-height] family`,
/// or a system font keyword, which is ignored.
List<(CssPropertyDefinition, CssValue)>? _expandFont(
  List<CssComponentValue> values,
) {
  CssValue style = const CssKeyword('normal');
  CssValue variant = const CssKeyword('normal');
  CssValue weight = const CssKeyword('normal');
  var i = 0;
  // Leading style/variant/weight keywords, `normal` counting for any.
  while (i < values.length) {
    final ident = cssIdentOf([values[i]]);
    if (ident == 'normal') {
      i++;
    } else if (ident == 'italic' || ident == 'oblique') {
      style = CssKeyword(ident!);
      i++;
    } else if (ident == 'small-caps') {
      variant = const CssKeyword('small-caps');
      i++;
    } else if (_fontWeight([values[i]]) case final w?) {
      // A number here is a weight only if a size follows.
      if (i + 1 >= values.length) break;
      weight = w;
      i++;
    } else {
      break;
    }
  }
  if (i >= values.length) return null;
  final size = _fontSize([values[i]]);
  if (size == null) return null;
  i++;
  CssValue lineHeight = const CssKeyword('normal');
  if (i < values.length &&
      values[i] is CssTokenValue &&
      (values[i] as CssTokenValue).token.isDelim('/')) {
    i++;
    if (i >= values.length) return null;
    final lh = _lineHeight([values[i]]);
    if (lh == null) return null;
    lineHeight = lh;
    i++;
  }
  final family = _fontFamily(values.sublist(i));
  if (family == null) return null;
  return [
    (cssProperties['font-style']!, style),
    (cssProperties['font-variant']!, variant),
    (cssProperties['font-weight']!, weight),
    (cssProperties['font-size']!, size),
    (cssProperties['line-height']!, lineHeight),
    (cssProperties['font-family']!, family),
  ];
}

/// `background`: only the color is kept; images, positions and the
/// rest are accepted and ignored.
List<(CssPropertyDefinition, CssValue)>? _expandBackground(
  List<CssComponentValue> values,
) {
  CssValue color = const CssColorValue(CssColor.transparent);
  for (final layer in cssSplitOnCommas(values)) {
    for (final v in layer) {
      if (_color([v]) case final c?) color = c;
    }
  }
  return [(cssProperties['background-color']!, color)];
}

List<(CssPropertyDefinition, CssValue)>? _expandListStyle(
  List<CssComponentValue> values,
) {
  if (values.isEmpty || values.length > 3) return null;
  CssValue type = const CssKeyword('disc');
  var sawType = false;
  for (final v in values) {
    final ident = cssIdentOf([v]);
    if (ident == 'inside' || ident == 'outside') continue;
    if (v is CssTokenValue && v.token.type == CssTokenType.url) continue;
    if (ident == 'none' && !sawType) {
      type = const CssKeyword('none');
      continue;
    }
    final t = _listStyleType([v]);
    if (t == null) return null;
    type = t;
    sawType = true;
  }
  return [(cssProperties['list-style-type']!, type)];
}

final Map<String, _Shorthand> _shorthands = {
  'margin': _Shorthand(
    [for (final e in _edges) 'margin-$e'],
    (values) => _expandEdges(
      'margin-',
      '',
      values,
      (v) => _length(v, keywords: const {'auto'}),
    ),
  ),
  'padding': _Shorthand(
    [for (final e in _edges) 'padding-$e'],
    (values) => _expandEdges(
      'padding-',
      '',
      values,
      (v) => _length(v, allowNegative: false),
    ),
  ),
  'border-width': _Shorthand(
    [for (final e in _edges) 'border-$e-width'],
    (values) => _expandEdges('border-', '-width', values, _borderWidth),
  ),
  'border-style': _Shorthand(
    [for (final e in _edges) 'border-$e-style'],
    (values) =>
        _expandEdges('border-', '-style', values, _keywords(_borderStyles)),
  ),
  'border-color': _Shorthand(
    [for (final e in _edges) 'border-$e-color'],
    (values) => _expandEdges('border-', '-color', values, _color),
  ),
  'border': _Shorthand(
    [
      for (final e in _edges) ...[
        'border-$e-width',
        'border-$e-style',
        'border-$e-color',
      ],
    ],
    (values) => _expandBorder(_edges, values),
  ),
  for (final edge in _edges)
    'border-$edge': _Shorthand(
      ['border-$edge-width', 'border-$edge-style', 'border-$edge-color'],
      (values) => _expandBorder([edge], values),
    ),
  'font': _Shorthand(
    const [
      'font-style',
      'font-variant',
      'font-weight',
      'font-size',
      'line-height',
      'font-family',
    ],
    _expandFont,
  ),
  'background': _Shorthand(const ['background-color'], _expandBackground),
  'text-decoration': _Shorthand(
    const ['text-decoration-line'],
    (values) {
      final v = _textDecoration(values);
      return v == null ? null : [(cssProperties['text-decoration-line']!, v)];
    },
  ),
  'list-style': _Shorthand(const ['list-style-type'], _expandListStyle),
  'break-before': _Shorthand(const ['page-break-before'], (values) {
    final v = _breakValue(values);
    return v == null ? null : [(cssProperties['page-break-before']!, v)];
  }),
  'break-after': _Shorthand(const ['page-break-after'], (values) {
    final v = _breakValue(values);
    return v == null ? null : [(cssProperties['page-break-after']!, v)];
  }),
  'break-inside': _Shorthand(const ['page-break-inside'], (values) {
    final ident = cssIdentOf(values);
    final v = switch (ident) {
      'auto' => const CssKeyword('auto'),
      'avoid' || 'avoid-page' || 'avoid-column' => const CssKeyword('avoid'),
      _ => null,
    };
    return v == null ? null : [(cssProperties['page-break-inside']!, v)];
  }),
};
