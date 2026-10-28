/// The cascade: stylesheets in their origins, matched against a
/// [ContentDocument], become one [ComputedStyle] per element.
///
/// Rules are indexed by the rightmost compound of each selector (id,
/// class, type or universal) so an element only tests the rules that
/// could match it. Elements resolve in document order, parents first,
/// so inheritance reads a finished parent. Computed styles are interned:
/// a thousand identical paragraphs share one object.
///
/// Precedence follows CSS Cascading Level 4 for the three origins:
/// user-agent, then user, then author, normal declarations in that
/// order; important declarations reverse it. Inline `style` attributes
/// are author declarations that beat every author selector.
/// Presentational attributes (`align`, `width`, `bgcolor`, Kindle's
/// `height` and `width` on paragraphs) are author declarations that
/// every author rule beats.
library;

import 'dart:collection';

import '../document/content_document.dart';
import 'computed_style.dart';
import 'css_properties.dart';
import 'css_selector.dart';
import 'css_syntax.dart';
import 'css_tokenizer.dart';
import 'css_values.dart';

enum CssOrigin { userAgent, user, author }

/// A stylesheet with the origin it came from.
class CssSheetSource {
  const CssSheetSource(this.sheet, this.origin);

  final CssStyleSheet sheet;
  final CssOrigin origin;
}

/// The computed styles of one document, by element index. Text nodes
/// take their parent's style.
class ComputedStyles {
  ComputedStyles._(this.document, this._styles, this.rootFontSize);

  final ContentDocument document;
  final List<ComputedStyle?> _styles;
  final double rootFontSize;

  ComputedStyle operator [](int node) {
    var n = node;
    while (!document.isElement(n)) {
      n = document.parentOf(n);
    }
    return _styles[n]!;
  }

  /// How many distinct style objects the document needed.
  int get distinctStyleCount =>
      _styles.whereType<ComputedStyle>().toSet().length;
}

/// What the resolver needs to know about the viewport and the reader's
/// base font size.
class StyleResolverOptions {
  const StyleResolverOptions({
    this.rootFontSize = 16,
    this.viewportWidth = 0,
    this.viewportHeight = 0,
  });

  /// The size `medium` and `1rem` mean, in px.
  final double rootFontSize;
  final double viewportWidth;
  final double viewportHeight;
}

class StyleResolver {
  /// Builds the rule index for [sheets], in the order given within each
  /// origin. `@media` blocks are included unless they name `print` only;
  /// other at-rules are ignored here (`@import` is the loader's job).
  StyleResolver(List<CssSheetSource> sheets) {
    var order = 0;
    for (final source in sheets) {
      order = _index(source.sheet.rules, source.origin, order);
    }
  }

  final _byId = <String, List<_IndexedRule>>{};
  final _byClass = <String, List<_IndexedRule>>{};
  final _byType = <String, List<_IndexedRule>>{};
  final _universal = <_IndexedRule>[];

  int _index(List<CssRule> rules, CssOrigin origin, int order) {
    var next = order;
    for (final rule in rules) {
      switch (rule) {
        case CssQualifiedRule():
          final selectors = CssSelectorList.parse(rule.prelude);
          if (selectors == null) continue;
          final declarations = [
            for (final d in rule.declarations) ...parseCssDeclaration(d),
          ];
          if (declarations.isEmpty) continue;
          for (final selector in selectors.selectors) {
            if (selector.neverMatches) continue;
            final indexed = _IndexedRule(
              selector,
              declarations,
              origin,
              next++,
            );
            final last = selector.compounds.last;
            final id = last.simples.whereType<CssIdSelector>().firstOrNull;
            final cls = last.simples.whereType<CssClassSelector>().firstOrNull;
            if (id != null) {
              _byId.putIfAbsent(id.id, () => []).add(indexed);
            } else if (cls != null) {
              _byClass.putIfAbsent(cls.name, () => []).add(indexed);
            } else if (last.type != null) {
              _byType.putIfAbsent(last.type!, () => []).add(indexed);
            } else {
              _universal.add(indexed);
            }
          }
        case CssAtRule(name: 'media', :final rules?):
          if (_mediaApplies(rule.prelude)) next = _index(rules, origin, next);
        case CssAtRule():
          break;
      }
    }
    return next;
  }

  /// A media query list applies unless it is `print` alone (or with
  /// `only`); `not print`, `screen`, `all` and feature queries apply.
  static bool _mediaApplies(List<CssComponentValue> prelude) {
    final idents = [
      for (final v in prelude)
        if (v is CssTokenValue && v.token.type == CssTokenType.ident)
          v.token.value.toLowerCase(),
    ];
    final queries = cssSplitOnCommas(prelude);
    if (idents.isEmpty) return true;
    for (final query in queries) {
      final words = [
        for (final v in query)
          if (v is CssTokenValue && v.token.type == CssTokenType.ident)
            v.token.value.toLowerCase(),
      ];
      final negated = words.contains('not');
      final print = words.contains('print');
      final other = words.any((w) => w == 'screen' || w == 'all');
      if (negated ? print || !other : !print || other) return true;
    }
    return false;
  }

  /// Resolves every element of [document].
  ComputedStyles resolve(
    ContentDocument document, {
    StyleResolverOptions options = const StyleResolverOptions(),
  }) {
    final styles = List<ComputedStyle?>.filled(document.nodeCount, null);
    final intern = HashMap<ComputedStyle, ComputedStyle>();
    for (var n = 0; n < document.nodeCount; n++) {
      if (!document.isElement(n)) continue;
      final parent = document.parentOf(n);
      final parentStyle = parent == ContentDocument.none
          ? null
          : styles[parent];
      final computed = _compute(document, n, parentStyle, options);
      styles[n] = intern.putIfAbsent(computed, () => computed);
    }
    return ComputedStyles._(document, styles, options.rootFontSize);
  }

  ComputedStyle _compute(
    ContentDocument doc,
    int element,
    ComputedStyle? parent,
    StyleResolverOptions options,
  ) {
    final candidates = <_Candidate>[];
    void collect(List<_IndexedRule>? rules) {
      if (rules == null) return;
      for (final rule in rules) {
        if (rule.selector.matches(doc, element)) {
          for (final d in rule.declarations) {
            candidates.add(
              _Candidate(
                d,
                _level(rule.origin, d.isImportant),
                rule.selector.specificity,
                rule.order,
              ),
            );
          }
        }
      }
    }

    final id = doc.idOf(element);
    if (id != null) collect(_byId[id]);
    final classes = doc.attributeOf(element, 'class');
    if (classes != null) {
      for (final cls in classes.split(RegExp(r'\s+'))) {
        if (cls.isNotEmpty) collect(_byClass[cls]);
      }
    }
    collect(_byType[doc.localNameOf(element).toLowerCase()]);
    collect(_universal);

    // Presentational hints: author origin, below every author rule.
    for (final d in _presentationalHints(doc, element)) {
      candidates.add(_Candidate(d, _level(CssOrigin.author, false), -1, -1));
    }
    // The style attribute: author origin, above every author rule.
    final inline = doc.attributeOf(element, 'style');
    if (inline != null) {
      var order = 0;
      for (final declaration in parseCssDeclarations(inline)) {
        for (final d in parseCssDeclaration(declaration)) {
          candidates.add(
            _Candidate(
              d,
              _level(CssOrigin.author, d.isImportant),
              1 << 40,
              1 << 40 + order++,
            ),
          );
        }
      }
    }
    candidates.sort();

    final specified = <String, CssValue>{};
    for (final c in candidates) {
      specified[c.declaration.property.name] = c.declaration.value;
    }
    return _ComputedStyleBuilder(specified, parent, options).build();
  }

  /// Cascade precedence: higher wins.
  static int _level(CssOrigin origin, bool important) =>
      switch ((origin, important)) {
        (CssOrigin.userAgent, false) => 0,
        (CssOrigin.user, false) => 1,
        (CssOrigin.author, false) => 2,
        (CssOrigin.author, true) => 3,
        (CssOrigin.user, true) => 4,
        (CssOrigin.userAgent, true) => 5,
      };

  /// HTML attributes that carry style, as declarations.
  static List<CssParsedDeclaration> _presentationalHints(
    ContentDocument doc,
    int element,
  ) {
    final tag = doc.localNameOf(element).toLowerCase();
    final out = <CssParsedDeclaration>[];
    void add(String property, String value) {
      out.addAll(
        parseCssDeclaration(
          CssDeclaration(property, parseCssComponentValues(value)),
        ),
      );
    }

    for (final (name, value) in doc.attributesOf(element)) {
      switch (name.toLowerCase()) {
        case 'align':
          final v = value.toLowerCase();
          if (v == 'left' || v == 'right' || v == 'center' || v == 'justify') {
            if (tag == 'img' || tag == 'table') {
              if (v == 'left' || v == 'right') add('float', v);
            } else {
              add('text-align', v);
            }
          }
        case 'width' when tag == 'p' || tag == 'div' || tag == 'blockquote':
          // Kindle: the paragraph's first-line indent.
          add('text-indent', _dimension(value));
        case 'height' when tag == 'p' || tag == 'div' || tag == 'blockquote':
          // Kindle: space above the paragraph.
          add('margin-top', _dimension(value));
        case 'width'
            when tag == 'img' ||
                tag == 'table' ||
                tag == 'td' ||
                tag == 'th' ||
                tag == 'hr':
          add('width', _dimension(value));
        case 'height'
            when tag == 'img' || tag == 'table' || tag == 'td' || tag == 'th':
          add('height', _dimension(value));
        case 'bgcolor':
          add('background-color', _colorAttribute(value));
        case 'color' when tag == 'font':
          add('color', _colorAttribute(value));
        case 'face' when tag == 'font':
          add('font-family', value);
        case 'size' when tag == 'font':
          final size = _fontSizeAttribute(value);
          if (size != null) add('font-size', size);
        case 'text' when tag == 'body':
          add('color', _colorAttribute(value));
        case 'dir':
          final v = value.toLowerCase();
          if (v == 'ltr' || v == 'rtl') add('direction', v);
        case 'nowrap':
          add('white-space', 'nowrap');
        case 'hidden':
          add('display', 'none');
        case 'hspace' when tag == 'img':
          add('margin-left', _dimension(value));
          add('margin-right', _dimension(value));
        case 'vspace' when tag == 'img':
          add('margin-top', _dimension(value));
          add('margin-bottom', _dimension(value));
        case 'border' when tag == 'img':
          add('border', '${_dimension(value)} solid');
        case 'valign' when tag == 'td' || tag == 'th' || tag == 'tr':
          add('vertical-align', value.toLowerCase());
      }
    }
    return out;
  }

  /// `12` means px; `50%` and `2em` are as written.
  static String _dimension(String value) {
    final v = value.trim();
    return RegExp(r'^\d+(\.\d+)?$').hasMatch(v) ? '${v}px' : v;
  }

  static String _colorAttribute(String value) {
    final v = value.trim();
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(v) ? '#$v' : v;
  }

  static String? _fontSizeAttribute(String value) {
    final v = value.trim();
    final relative = RegExp(r'^([+-])(\d)$').firstMatch(v);
    var n = int.tryParse(v);
    if (relative != null) {
      n =
          3 +
          (relative.group(1) == '+' ? 1 : -1) * int.parse(relative.group(2)!);
    }
    if (n == null) return null;
    return switch (n.clamp(1, 7)) {
      1 => 'x-small',
      2 => 'small',
      3 => 'medium',
      4 => 'large',
      5 => 'x-large',
      6 => 'xx-large',
      _ => 'xxx-large',
    };
  }
}

class _IndexedRule {
  const _IndexedRule(this.selector, this.declarations, this.origin, this.order);

  final CssSelector selector;
  final List<CssParsedDeclaration> declarations;
  final CssOrigin origin;
  final int order;
}

class _Candidate implements Comparable<_Candidate> {
  const _Candidate(this.declaration, this.level, this.specificity, this.order);

  final CssParsedDeclaration declaration;
  final int level;
  final int specificity;
  final int order;

  @override
  int compareTo(_Candidate other) {
    if (level != other.level) return level.compareTo(other.level);
    if (specificity != other.specificity) {
      return specificity.compareTo(other.specificity);
    }
    return order.compareTo(other.order);
  }
}

/// Turns the cascaded specified values of one element into its computed
/// style: inheritance, initial values, `em` and keyword resolution.
class _ComputedStyleBuilder {
  _ComputedStyleBuilder(this.specified, this.parent, this.options);

  final Map<String, CssValue> specified;
  final ComputedStyle? parent;
  final StyleResolverOptions options;

  /// The specified value after the CSS-wide keywords: null means "take
  /// the parent's computed value", whether the property inherits by
  /// default or `inherit`/`unset` asked for it.
  CssValue? _value(String name) {
    final property = cssProperties[name]!;
    final value = specified[name];
    if (value == null) {
      return property.inherited && parent != null ? null : property.initial;
    }
    if (value is CssKeyword && value.isCssWide) {
      final inherit =
          value.name == 'inherit' ||
          (value.name == 'unset' && property.inherited);
      return inherit && parent != null ? null : property.initial;
    }
    return value;
  }

  late final double fontSize = _fontSize();

  late final CssLengthContext lengths = CssLengthContext(
    fontSize: fontSize,
    rootFontSize: options.rootFontSize,
    viewportWidth: options.viewportWidth,
    viewportHeight: options.viewportHeight,
  );

  late final CssLengthContext parentLengths = CssLengthContext(
    fontSize: parent?.fontSize ?? options.rootFontSize,
    rootFontSize: options.rootFontSize,
    viewportWidth: options.viewportWidth,
    viewportHeight: options.viewportHeight,
  );

  double _fontSize() {
    final value = _value('font-size');
    final parentSize = parent?.fontSize ?? options.rootFontSize;
    switch (value) {
      case null:
        return parentSize;
      case CssLengthValue(:final length):
        return length.toPx(parentLengths, percentOf: parentSize);
      case CssKeyword(:final name):
        final medium = options.rootFontSize;
        return switch (name) {
          'xx-small' => medium * 9 / 16,
          'x-small' => medium * 10 / 16,
          'small' => medium * 13 / 16,
          'medium' => medium,
          'large' => medium * 18 / 16,
          'x-large' => medium * 24 / 16,
          'xx-large' => medium * 32 / 16,
          'xxx-large' => medium * 48 / 16,
          'larger' => parentSize * 1.2,
          'smaller' => parentSize / 1.2,
          _ => medium,
        };
      default:
        return parentSize;
    }
  }

  T _keyword<T extends Enum>(
    String name,
    List<T> values,
    T Function(String) map, {
    required T Function(ComputedStyle) inherited,
  }) {
    final value = _value(name);
    if (value == null) return inherited(parent!);
    return value is CssKeyword ? map(value.name) : values.first;
  }

  /// A length in px (relative units resolved) or a kept percentage;
  /// null for the keyword [nullKeyword].
  CssLength? _length(
    String name, {
    String? nullKeyword,
    required CssLength? Function(ComputedStyle) inherited,
  }) {
    final value = _value(name);
    if (value == null) return inherited(parent!);
    return switch (value) {
      CssLengthValue(:final length) =>
        length.isPercent ? length : CssLength.px(length.toPx(lengths)),
      CssKeyword(:final name) when name == nullKeyword => null,
      _ => CssLength.zero,
    };
  }

  int _color(
    String name, {
    required int Function(ComputedStyle) inherited,
    required int current,
  }) {
    final value = _value(name);
    if (value == null) return inherited(parent!);
    if (value is! CssColorValue) return 0;
    return value.color.isCurrentColor ? current : value.color.argb;
  }

  ComputedStyle build() {
    final fontFamily = switch (_value('font-family')) {
      null => parent!.fontFamily,
      CssFontFamilyValue(:final families) => families,
      _ => const ['serif'],
    };
    final fontWeight = _fontWeight();
    final fontStyle = _keyword(
      'font-style',
      CssFontStyle.values,
      (k) => switch (k) {
        'italic' => CssFontStyle.italic,
        'oblique' => CssFontStyle.oblique,
        _ => CssFontStyle.normal,
      },
      inherited: (p) => p.fontStyle,
    );
    final smallCaps = switch (_value('font-variant')) {
      null => parent!.smallCaps,
      CssKeyword(name: 'small-caps') => true,
      _ => false,
    };
    final color = _color(
      'color',
      inherited: (p) => p.color,
      current: parent?.color ?? 0xFF000000,
    );
    final backgroundColor = _color(
      'background-color',
      inherited: (p) => p.backgroundColor,
      current: color,
    );
    final lineHeight = switch (_value('line-height')) {
      null => parent!.lineHeight,
      CssNumberValue(:final value) => CssLineHeight.factor(value),
      CssLengthValue(:final length) => CssLineHeight.px(
        length.toPx(lengths, percentOf: fontSize),
      ),
      _ => CssLineHeight.normal,
    };
    final margin = CssEdges(
      _length(
        'margin-top',
        nullKeyword: 'auto',
        inherited: (p) => p.margin.top,
      ),
      _length(
        'margin-right',
        nullKeyword: 'auto',
        inherited: (p) => p.margin.right,
      ),
      _length(
        'margin-bottom',
        nullKeyword: 'auto',
        inherited: (p) => p.margin.bottom,
      ),
      _length(
        'margin-left',
        nullKeyword: 'auto',
        inherited: (p) => p.margin.left,
      ),
    );
    final paddingEdges = CssEdges(
      _length('padding-top', inherited: (p) => p.padding.top),
      _length('padding-right', inherited: (p) => p.padding.right),
      _length('padding-bottom', inherited: (p) => p.padding.bottom),
      _length('padding-left', inherited: (p) => p.padding.left),
    );
    final padding = CssEdges(
      paddingEdges.top ?? CssLength.zero,
      paddingEdges.right ?? CssLength.zero,
      paddingEdges.bottom ?? CssLength.zero,
      paddingEdges.left ?? CssLength.zero,
    );
    CssBorderStyle borderStyle(String edge) =>
        switch (_value('border-$edge-style')) {
          null => _parentEdge(parent!.borderStyle, edge),
          CssKeyword(:final name) => switch (name) {
            'hidden' => CssBorderStyle.hidden,
            'dashed' => CssBorderStyle.dashed,
            'dotted' => CssBorderStyle.dotted,
            'double' => CssBorderStyle.double,
            'none' => CssBorderStyle.none,
            _ => CssBorderStyle.solid,
          },
          _ => CssBorderStyle.none,
        };
    final styles = CssEdges(
      borderStyle('top'),
      borderStyle('right'),
      borderStyle('bottom'),
      borderStyle('left'),
    );
    double borderWidth(String edge, CssBorderStyle style) {
      if (style == CssBorderStyle.none || style == CssBorderStyle.hidden) {
        return 0;
      }
      return switch (_value('border-$edge-width')) {
        null => _parentEdge(parent!.borderWidth, edge),
        CssLengthValue(:final length) => length.toPx(lengths),
        _ => 3,
      };
    }

    final widths = CssEdges(
      borderWidth('top', styles.top),
      borderWidth('right', styles.right),
      borderWidth('bottom', styles.bottom),
      borderWidth('left', styles.left),
    );
    int borderColor(String edge) => _color(
      'border-$edge-color',
      inherited: (p) => _parentEdge(p.borderColor, edge),
      current: color,
    );
    final colors = CssEdges(
      borderColor('top'),
      borderColor('right'),
      borderColor('bottom'),
      borderColor('left'),
    );
    final display = switch (_value('display')) {
      null => parent!.display,
      CssKeyword(:final name) => CssDisplay.fromKeyword(name),
      _ => CssDisplay.inline,
    };
    CssPageBreak pageBreak(String name) => switch (_value(name)) {
      null =>
        name == 'page-break-before'
            ? parent!.pageBreakBefore
            : parent!.pageBreakAfter,
      CssKeyword(:final name) => switch (name) {
        'always' => CssPageBreak.always,
        'avoid' => CssPageBreak.avoid,
        'left' => CssPageBreak.left,
        'right' => CssPageBreak.right,
        _ => CssPageBreak.auto,
      },
      _ => CssPageBreak.auto,
    };
    final avoidInside = switch (_value('page-break-inside')) {
      null => parent!.avoidPageBreakInside,
      CssKeyword(:final name) => name != 'auto',
      _ => false,
    };
    final verticalAlignValue = _value('vertical-align');
    final (verticalAlign, verticalAlignLength) = switch (verticalAlignValue) {
      null => (parent!.verticalAlign, parent!.verticalAlignLength),
      CssLengthValue(:final length) => (
        CssVerticalAlign.length,
        length.isPercent ? length : CssLength.px(length.toPx(lengths)),
      ),
      CssKeyword(:final name) => (
        switch (name) {
          'sub' => CssVerticalAlign.sub,
          'super' => CssVerticalAlign.sup,
          'text-top' => CssVerticalAlign.textTop,
          'text-bottom' => CssVerticalAlign.textBottom,
          'middle' => CssVerticalAlign.middle,
          'top' => CssVerticalAlign.top,
          'bottom' => CssVerticalAlign.bottom,
          _ => CssVerticalAlign.baseline,
        },
        null,
      ),
      _ => (CssVerticalAlign.baseline, null),
    };
    final decoration = switch (_value('text-decoration-line')) {
      null => CssTextDecorationValue(
        underline: parent!.underline,
        overline: parent!.overline,
        lineThrough: parent!.lineThrough,
      ),
      CssTextDecorationValue v => v,
      _ => const CssTextDecorationValue(),
    };
    double spacing(String name, double Function(ComputedStyle) inherited) =>
        switch (_value(name)) {
          null => inherited(parent!),
          CssLengthValue(:final length) => length.toPx(
            lengths,
            percentOf: fontSize,
          ),
          _ => 0,
        };
    final listStyleType = switch (_value('list-style-type')) {
      null => parent!.listStyleType,
      CssKeyword(:final name) => name,
      CssStringValue(:final value) => value,
      _ => 'disc',
    };
    int integer(
      String name,
      int Function(ComputedStyle) inherited,
      int fallback,
    ) => switch (_value(name)) {
      null => inherited(parent!),
      CssNumberValue(:final value) => value.toInt(),
      _ => fallback,
    };
    return ComputedStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontStyle: fontStyle,
      fontWeight: fontWeight,
      smallCaps: smallCaps,
      color: color,
      backgroundColor: backgroundColor,
      textAlign: _keyword(
        'text-align',
        CssTextAlign.values,
        (k) => switch (k) {
          'left' => CssTextAlign.left,
          'right' => CssTextAlign.right,
          'center' => CssTextAlign.center,
          'justify' => CssTextAlign.justify,
          'end' => CssTextAlign.end,
          _ => CssTextAlign.start,
        },
        inherited: (p) => p.textAlign,
      ),
      textIndent:
          _length('text-indent', inherited: (p) => p.textIndent) ??
          CssLength.zero,
      lineHeight: lineHeight,
      margin: margin,
      padding: padding,
      borderWidth: widths,
      borderStyle: styles,
      borderColor: colors,
      display: display,
      pageBreakBefore: pageBreak('page-break-before'),
      pageBreakAfter: pageBreak('page-break-after'),
      avoidPageBreakInside: avoidInside,
      width: _length('width', nullKeyword: 'auto', inherited: (p) => p.width),
      height: _length(
        'height',
        nullKeyword: 'auto',
        inherited: (p) => p.height,
      ),
      maxWidth: _length(
        'max-width',
        nullKeyword: 'none',
        inherited: (p) => p.maxWidth,
      ),
      maxHeight: _length(
        'max-height',
        nullKeyword: 'none',
        inherited: (p) => p.maxHeight,
      ),
      minWidth:
          _length(
            'min-width',
            nullKeyword: 'auto',
            inherited: (p) => p.minWidth,
          ) ??
          CssLength.zero,
      minHeight:
          _length(
            'min-height',
            nullKeyword: 'auto',
            inherited: (p) => p.minHeight,
          ) ??
          CssLength.zero,
      float: _keyword(
        'float',
        CssFloat.values,
        (k) => switch (k) {
          'left' || 'inline-start' => CssFloat.left,
          'right' || 'inline-end' => CssFloat.right,
          _ => CssFloat.none,
        },
        inherited: (p) => p.float,
      ),
      clear: _keyword(
        'clear',
        CssClear.values,
        (k) => switch (k) {
          'left' || 'inline-start' => CssClear.left,
          'right' || 'inline-end' => CssClear.right,
          'both' => CssClear.both,
          _ => CssClear.none,
        },
        inherited: (p) => p.clear,
      ),
      underline: decoration.underline,
      overline: decoration.overline,
      lineThrough: decoration.lineThrough,
      letterSpacing: spacing('letter-spacing', (p) => p.letterSpacing),
      wordSpacing: spacing('word-spacing', (p) => p.wordSpacing),
      whiteSpace: _keyword(
        'white-space',
        CssWhiteSpace.values,
        (k) => switch (k) {
          'nowrap' => CssWhiteSpace.nowrap,
          'pre' => CssWhiteSpace.pre,
          'pre-wrap' || 'break-spaces' => CssWhiteSpace.preWrap,
          'pre-line' => CssWhiteSpace.preLine,
          _ => CssWhiteSpace.normal,
        },
        inherited: (p) => p.whiteSpace,
      ),
      verticalAlign: verticalAlign,
      verticalAlignLength: verticalAlignLength,
      textTransform: _keyword(
        'text-transform',
        CssTextTransform.values,
        (k) => switch (k) {
          'capitalize' => CssTextTransform.capitalize,
          'uppercase' => CssTextTransform.uppercase,
          'lowercase' => CssTextTransform.lowercase,
          _ => CssTextTransform.none,
        },
        inherited: (p) => p.textTransform,
      ),
      hyphens: _keyword(
        'hyphens',
        CssHyphens.values,
        (k) => switch (k) {
          'none' => CssHyphens.none,
          'auto' => CssHyphens.auto,
          _ => CssHyphens.manual,
        },
        inherited: (p) => p.hyphens,
      ),
      direction: _keyword(
        'direction',
        CssDirection.values,
        (k) => k == 'rtl' ? CssDirection.rtl : CssDirection.ltr,
        inherited: (p) => p.direction,
      ),
      unicodeBidi: _keyword(
        'unicode-bidi',
        CssUnicodeBidi.values,
        (k) => switch (k) {
          'embed' => CssUnicodeBidi.embed,
          'isolate' => CssUnicodeBidi.isolate,
          'bidi-override' => CssUnicodeBidi.bidiOverride,
          'isolate-override' => CssUnicodeBidi.isolateOverride,
          'plaintext' => CssUnicodeBidi.plaintext,
          _ => CssUnicodeBidi.normal,
        },
        inherited: (p) => p.unicodeBidi,
      ),
      listStyleType: listStyleType,
      visible: switch (_value('visibility')) {
        null => parent!.visible,
        CssKeyword(name: 'visible') => true,
        _ => false,
      },
      widows: integer('widows', (p) => p.widows, 2),
      orphans: integer('orphans', (p) => p.orphans, 2),
    );
  }

  static T _parentEdge<T>(CssEdges<T> edges, String edge) => switch (edge) {
    'top' => edges.top,
    'right' => edges.right,
    'bottom' => edges.bottom,
    _ => edges.left,
  };

  int _fontWeight() {
    final value = _value('font-weight');
    final parentWeight = parent?.fontWeight ?? 400;
    return switch (value) {
      null => parentWeight,
      CssNumberValue(:final value) => value.round().clamp(1, 1000),
      CssKeyword(name: 'bold') => 700,
      CssKeyword(name: 'bolder') =>
        parentWeight < 350
            ? 400
            : parentWeight < 550
            ? 700
            : 900,
      CssKeyword(name: 'lighter') =>
        parentWeight < 100
            ? parentWeight
            : parentWeight < 550
            ? 100
            : parentWeight < 750
            ? 400
            : 700,
      _ => 400,
    };
  }
}
