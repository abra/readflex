/// The document tree of a section: what the browser's DOM was to
/// foliate-js, for the layout, CFI, search and highlight code.
///
/// The tree is an arena: every node is an index into parallel typed
/// arrays (kind, parent, first child, next sibling, name, attributes),
/// so a 100 KB chapter costs a few hundred kilobytes and a walk
/// allocates nothing. [ContentNode] views are made on demand and cached,
/// one per node at most, for callers that want objects, such as the CFI
/// code through [CfiNode].
///
/// Only elements and character data are kept, as CFI indexing sees them:
/// comments and processing instructions are dropped, namespace
/// declarations are not attributes, adjacent text and CDATA stay
/// separate nodes as the browser keeps them. Parsing applies what the
/// browser's parsers apply: line breaks fold to `\n`, XML attribute
/// values fold line breaks and tabs to spaces, and XHTML knows the HTML
/// named entities (`&nbsp;`).
library;

import 'dart:typed_data';

import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart' show XmlDefaultEntityMapping, XmlException;
import 'package:xml/xml_events.dart' as xml_events;

import '../epubcfi/cfi_node.dart';
import '../vellum_exception.dart';

part 'content_document_builder.dart';
part 'content_document_parser.dart';
part 'content_node.dart';

/// The kind of a node.
enum ContentNodeKind {
  element,

  /// A text node.
  text,

  /// A CDATA section: character data the CFI code treats as text, kept
  /// apart because the browser keeps it apart.
  cdata,
}

/// A parse failure: the markup was not well formed.
class ContentParseException extends VellumException {
  const ContentParseException(super.message);
}

/// A parsed section. See the library comment.
class ContentDocument implements CfiDocument {
  ContentDocument._({
    required Uint8List kinds,
    required Int32List parents,
    required Int32List firstChildren,
    required Int32List lastChildren,
    required Int32List nextSiblings,
    required Int32List childCounts,
    required Int32List names,
    required Int32List attributeStarts,
    required Int32List attributeCounts,
    required List<String> qualifiedNames,
    required List<String> localNames,
    required List<String> attributeNames,
    required List<String> attributeValues,
    required List<String> texts,
    required Map<String, int> ids,
  }) : _kinds = kinds,
       _parents = parents,
       _firstChildren = firstChildren,
       _lastChildren = lastChildren,
       _nextSiblings = nextSiblings,
       _childCounts = childCounts,
       _names = names,
       _attributeStarts = attributeStarts,
       _attributeCounts = attributeCounts,
       _qualifiedNames = qualifiedNames,
       _localNames = localNames,
       _attributeNames = attributeNames,
       _attributeValues = attributeValues,
       _texts = texts,
       _ids = ids,
       _views = List<ContentNode?>.filled(kinds.length, null);

  /// Parses XML (XHTML sections, FB2 output, package documents). Throws
  /// [ContentParseException] when it is not well formed.
  factory ContentDocument.parseXml(String source) => _parseXml(source);

  /// Parses HTML with the HTML5 algorithm, as the browser parses
  /// `text/html` sections and MOBI 6 text: the tree gains the implied
  /// `html`, `head` and `body`, and never fails.
  factory ContentDocument.parseHtml(String source) => _parseHtml(source);

  /// Parses by [mediaType]: `text/html` with the HTML parser, anything
  /// else as XML.
  factory ContentDocument.parse(String source, {String? mediaType}) =>
      mediaType == 'text/html'
      ? ContentDocument.parseHtml(source)
      : ContentDocument.parseXml(source);

  /// The index that means "no node": no parent, child or sibling.
  static const int none = -1;

  final Uint8List _kinds;
  final Int32List _parents;
  final Int32List _firstChildren;
  final Int32List _lastChildren;
  final Int32List _nextSiblings;
  final Int32List _childCounts;

  /// Elements: an index into [_qualifiedNames]; text: into [_texts].
  final Int32List _names;
  final Int32List _attributeStarts;
  final Int32List _attributeCounts;
  final List<String> _qualifiedNames;
  final List<String> _localNames;
  final List<String> _attributeNames;
  final List<String> _attributeValues;
  final List<String> _texts;
  final Map<String, int> _ids;
  final List<ContentNode?> _views;

  /// The root element's index: always 0.
  static const int rootIndex = 0;

  int get nodeCount => _kinds.length;

  ContentNodeKind kindOf(int node) => ContentNodeKind.values[_kinds[node]];

  bool isElement(int node) => _kinds[node] == 0;

  /// Text or CDATA.
  bool isText(int node) => _kinds[node] != 0;

  int parentOf(int node) => _parents[node];

  int firstChildOf(int node) => _firstChildren[node];

  int lastChildOf(int node) => _lastChildren[node];

  int nextSiblingOf(int node) => _nextSiblings[node];

  int childCountOf(int node) => _childCounts[node];

  /// The [index]th child of [node]; a walk along the siblings.
  int childAt(int node, int index) {
    var child = _firstChildren[node];
    for (var i = 0; i < index && child != none; i++) {
      child = _nextSiblings[child];
    }
    return child;
  }

  /// The children of [node], in order.
  Iterable<int> childrenOf(int node) sync* {
    for (var c = _firstChildren[node]; c != none; c = _nextSiblings[c]) {
      yield c;
    }
  }

  /// [node] and everything below it, in document order.
  Iterable<int> descendantsOf(int node) sync* {
    yield node;
    for (var c = _firstChildren[node]; c != none; c = _nextSiblings[c]) {
      yield* descendantsOf(c);
    }
  }

  /// The element's name as written, with its prefix (`svg:rect`).
  String qualifiedNameOf(int node) => _qualifiedNames[_names[node]];

  /// The element's name without a prefix: what CSS selectors match.
  String localNameOf(int node) => _localNames[_names[node]];

  /// The character data of a text or CDATA node.
  String textOf(int node) => _texts[_names[node]];

  int attributeCountOf(int node) => _attributeCounts[node];

  /// The element's attribute [name] (qualified, as written: `epub:type`),
  /// or null when absent or on text.
  String? attributeOf(int node, String name) {
    final start = _attributeStarts[node];
    final end = start + _attributeCounts[node];
    for (var i = start; i < end; i++) {
      if (_attributeNames[i] == name) return _attributeValues[i];
    }
    return null;
  }

  /// The element's attributes in document order.
  Iterable<(String name, String value)> attributesOf(int node) sync* {
    final start = _attributeStarts[node];
    final end = start + _attributeCounts[node];
    for (var i = start; i < end; i++) {
      yield (_attributeNames[i], _attributeValues[i]);
    }
  }

  String? idOf(int node) => attributeOf(node, 'id');

  /// The first element with [id], or [none].
  int elementIndexById(String id) => _ids[id] ?? none;

  /// The concatenated character data below [node].
  String textContentOf(int node) {
    final buffer = StringBuffer();
    for (final n in descendantsOf(node)) {
      if (_kinds[n] != 0) buffer.write(_texts[_names[n]]);
    }
    return buffer.toString();
  }

  /// The object view of [node], the same object every time.
  ContentNode node(int index) => _views[index] ??= ContentNode._(this, index);

  @override
  ContentNode get root => node(rootIndex);

  @override
  ContentNode? elementById(String id) {
    final index = _ids[id];
    return index == null ? null : node(index);
  }
}
