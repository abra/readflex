import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;
import 'package:vellum/vellum.dart';
import 'package:xml/xml.dart';

/// The canonical form of a document, byte for byte what
/// `corpus_snapshot.mjs` builds in the browser: element names, attributes
/// in name order without namespace declarations, text with CRLF folded,
/// every string length-prefixed (UTF-16 units, as JavaScript counts).
String _s(String text) => '${text.length}:$text';

String _text(String data) => 't${_s(data.replaceAll(RegExp(r'\r\n?'), '\n'))}';

/// Attribute whitespace folded, as the browser side folds it: XML
/// attribute-value normalization folds a literal line break (CRLF first
/// becoming one LF) but keeps one written as a character reference, and
/// after parsing the two are the same string.
String _attributeValue(String value) =>
    value.replaceAll(RegExp(r'\r\n|[\r\n\t]'), ' ');

String _element(
  String localName,
  Map<String, String> attributes,
  Iterable<String> children,
) {
  final names = attributes.keys.toList()..sort();
  final buffer = StringBuffer('e${_s(localName)}a${names.length}');
  for (final name in names) {
    buffer
      ..write(_s(name))
      ..write(_s(attributes[name]!));
  }
  final kept = children.where((c) => c.isNotEmpty).toList();
  buffer.write('c${kept.length}');
  kept.forEach(buffer.write);
  return buffer.toString();
}

bool _keepAttribute(String element, String name, {required bool fb2}) {
  if (name == 'xmlns' || name.startsWith('xmlns:')) return false;
  // fb2.js assigns `el.alt`/`el.title` on elements its document does not
  // reflect to attributes; vellum keeps both.
  if (fb2 && element == 'img' && (name == 'alt' || name == 'title')) {
    return false;
  }
  return true;
}

String canonicalXml(XmlNode node, {bool fb2 = false}) {
  switch (node) {
    case XmlElement():
      final local = node.name.local;
      return _element(
        local,
        {
          for (final a in node.attributes)
            if (_keepAttribute(local, a.name.qualified, fb2: fb2))
              a.name.qualified: _attributeValue(a.value),
        },
        node.children.map((c) => canonicalXml(c, fb2: fb2)),
      );
    case XmlText() || XmlCDATA():
      return _text(node.value ?? '');
    default:
      return '';
  }
}

/// The canonical form of a [ContentDocument] subtree: must equal the
/// browser's for the same markup, which is what makes the tree usable.
String canonicalContent(ContentDocument doc, int node, {bool fb2 = false}) {
  if (doc.isText(node)) return _text(doc.textOf(node));
  final local = doc.localNameOf(node);
  return _element(
    local,
    {
      for (final (name, value) in doc.attributesOf(node))
        if (_keepAttribute(local, name, fb2: fb2)) name: value,
    },
    doc.childrenOf(node).map((c) => canonicalContent(doc, c, fb2: fb2)),
  );
}

String canonicalHtml(dom.Node node) {
  switch (node) {
    case dom.Element():
      final local = node.localName ?? '';
      return _element(
        local,
        {
          for (final entry in node.attributes.entries)
            if (_keepAttribute(local, entry.key.toString(), fb2: false))
              entry.key.toString(): _attributeValue(entry.value),
        },
        node.nodes.map(canonicalHtml),
      );
    case dom.Text():
      return _text(node.data);
    default:
      return '';
  }
}

/// An XHTML section's canonical form, or null when it does not parse.
/// Browsers know the XHTML DTD's named entities (`&nbsp;`, `&mdash;`);
/// the HTML5 mapping covers the same names.
String? parseXhtmlCanonical(String text) {
  try {
    return canonicalXml(
      XmlDocument.parse(
        text,
        entityMapping: const XmlDefaultEntityMapping.html5(),
      ).rootElement,
    );
  } on XmlException {
    return null;
  }
}

String sha256Hex(String canonical) =>
    sha256.convert(utf8.encode(canonical)).toString();

/// Where two canonical strings part: the index and a window of each.
String describeFirstDifference(String actual, String expected) {
  var i = 0;
  while (i < actual.length && i < expected.length && actual[i] == expected[i]) {
    i++;
  }
  String window(String s) =>
      s.substring(i > 80 ? i - 80 : 0, i + 120 < s.length ? i + 120 : s.length);
  return 'documents differ at char $i\n'
      '    vellum: …${window(actual)}…\n'
      '    js:     …${window(expected)}…';
}

/// A section as the parity test reads it, whatever the format.
class ParitySection {
  const ParitySection({
    required this.id,
    required this.size,
    required this.linear,
    required this.pageSpread,
    required this.cfi,
    required this.canonical,
    required this.canonicalTree,
  });

  /// foliate-js's `section.id`: the href for EPUB, the index for FB2.
  final Object? id;
  final int? size;
  final String? linear;
  final String? pageSpread;
  final String? cfi;

  /// The canonical document, or null when it does not parse.
  final Future<String?> Function() canonical;

  /// The same through [ContentDocument], or null when it does not parse.
  final Future<String?> Function() canonicalTree;
}

typedef LoadedSection = ({int bytes});

/// One opened book behind a format-neutral face, so the parity test reads
/// EPUB, FB2 and MOBI alike. Each method maps to the field foliate-js
/// exposes under the same name.
abstract class ParityBook {
  String get kind;

  /// The stylesheets of section [index], when the format has any.
  Future<List<CssStyleSheet>> styleSheets(
    int index,
    ContentDocument doc,
  ) async => const [];

  /// Section [index] as a [ContentDocument], or null when it has no
  /// document or does not parse.
  Future<ContentDocument?> contentDocument(int index);
  int get sectionCount;
  ParitySection section(int index);
  Map<String, Object?> metadata();
  Future<Uint8List?> readCover();
  List<Map<String, Object?>>? toc();
  List<Map<String, Object?>>? landmarks();
  List<Map<String, Object?>>? pageList();
  Future<int?> resolveHrefIndex(String href);

  /// Loads every section's text once, for timing and memory.
  Future<List<LoadedSection>> loadAllSections();
  Future<void> close();
}

Future<ParityBook> openForParity(String path) async {
  final lower = path.toLowerCase();
  if (lower.endsWith('.epub')) return _EpubParity(await EpubBook.open(path));
  if (lower.endsWith('.fb2') ||
      lower.endsWith('.fb2.zip') ||
      lower.endsWith('.fbz')) {
    return _Fb2Parity(await Fb2Book.open(path));
  }
  return _MobiParity(await MobiBook.open(path));
}

Map<String, Object?> _navItem(BookNavItem item) => {
  'label': item.label,
  'href': item.href,
  'subitems': item.subitems?.map(_navItem).toList(),
  if (item.type != null) 'type': item.type,
};

List<Map<String, Object?>>? _nav(List<BookNavItem>? items) =>
    items?.map(_navItem).toList();

/// Matches a recorded foliate-js metadata object field by field, only on
/// the keys vellum carries, with the normalizations both sides agree on.
Matcher equalsMetadata(Map<String, dynamic> recorded) =>
    _MetadataMatcher(recorded);

class _MetadataMatcher extends Matcher {
  const _MetadataMatcher(this.recorded);

  final Map<String, dynamic> recorded;

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    final actual = item! as Map<String, Object?>;
    final differences = <String>[];
    for (final entry in actual.entries) {
      final expected = _normalize(recorded[entry.key], key: entry.key);
      final got = _normalize(entry.value, key: entry.key);
      if (jsonEncode(got) != jsonEncode(expected)) {
        differences.add('${entry.key}: vellum $got, js $expected');
      }
    }
    matchState['differences'] = differences;
    return differences.isEmpty;
  }

  /// An empty string or list where foliate-js has none, a null field
  /// where it has no key at all; languages are a list on both sides
  /// (mobi.js gives the header's locale language as a bare string).
  static Object? _normalize(Object? value, {String? key}) => switch (value) {
    String s when key == 'language' && s.isNotEmpty => [s],
    null => null,
    String s when s.isEmpty => null,
    List l when l.isEmpty => null,
    List l => l.map(_normalize).toList(),
    Map m => {for (final e in m.entries) e.key: ?_normalize(e.value)},
    _ => value,
  };

  @override
  Description describe(Description description) =>
      description.add('the metadata foliate-js recorded');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) => mismatchDescription.add(
    (matchState['differences'] as List<String>).join('\n'),
  );
}

class _EpubParity extends ParityBook {
  _EpubParity(this.book);

  final EpubBook book;

  @override
  String get kind => 'epub';

  @override
  int get sectionCount => book.sections.length;

  @override
  ParitySection section(int index) {
    final s = book.sections[index];
    return ParitySection(
      id: s.href,
      size: s.size,
      linear: s.isLinear ? null : 'no',
      pageSpread: s.pageSpread?.name,
      cfi: s.cfi.toString(),
      canonical: () async {
        final text = await book.readSectionText(index);
        final mediaType = s.item.mediaType;
        if (mediaType == 'text/html') {
          return canonicalHtml(html.parse(text).documentElement!);
        }
        return parseXhtmlCanonical(text);
      },
      canonicalTree: () async {
        final text = await book.readSectionText(index);
        try {
          final doc = ContentDocument.parse(text, mediaType: s.item.mediaType);
          return canonicalContent(doc, ContentDocument.rootIndex);
        } on ContentParseException {
          return null;
        }
      },
    );
  }

  @override
  Map<String, Object?> metadata() {
    final m = book.metadata;
    return {
      'title': m.title,
      'subtitle': m.subtitle,
      'sortAs': m.sortAs,
      'language': m.language,
      'identifier': m.identifier,
      'description': m.description,
      'publisher': m.publisher,
      'published': m.published,
      'modified': m.modified,
      'rights': m.rights,
      'subject': [
        for (final s in m.subjects)
          {'name': s.name, 'code': s.code, 'scheme': s.scheme},
      ],
      for (final role in m.contributors.entries)
        role.key: [
          for (final c in role.value) {'name': c.name, 'sortAs': c.sortAs},
        ],
    };
  }

  @override
  Future<Uint8List?> readCover() async => (await book.readCover())?.bytes;

  @override
  List<Map<String, Object?>>? toc() => _nav(book.toc);

  @override
  List<Map<String, Object?>>? landmarks() => _nav(book.landmarks);

  @override
  List<Map<String, Object?>>? pageList() => _nav(book.pageList);

  @override
  Future<int?> resolveHrefIndex(String href) async =>
      book.resolveHref(href)?.index;

  @override
  Future<List<LoadedSection>> loadAllSections() async => [
    for (var i = 0; i < book.sections.length; i++)
      (bytes: utf8.encode(await book.readSectionText(i)).length),
  ];

  @override
  Future<ContentDocument?> contentDocument(int index) async {
    final text = await book.readSectionText(index);
    try {
      return ContentDocument.parse(
        text,
        mediaType: book.sections[index].item.mediaType,
      );
    } on ContentParseException {
      return null;
    }
  }

  final _sheetCache = StyleSheetCache();

  @override
  Future<List<CssStyleSheet>> styleSheets(int index, ContentDocument doc) =>
      loadDocumentStyleSheets(
        doc,
        documentHref: book.sections[index].href,
        cache: _sheetCache,
        read: (href) async {
          final bytes = await book.readResource(href);
          return bytes == null
              ? null
              : utf8.decode(bytes, allowMalformed: true);
        },
      );

  @override
  Future<void> close() => book.close();
}

class _Fb2Parity extends ParityBook {
  _Fb2Parity(this.book);

  final Fb2Book book;

  @override
  String get kind => 'fb2';

  @override
  int get sectionCount => book.sections.length;

  @override
  ParitySection section(int index) {
    final s = book.sections[index];
    return ParitySection(
      id: index,
      size: s.size,
      linear: s.isLinear ? null : 'no',
      pageSpread: null,
      cfi: null,
      canonical: () async {
        final document = XmlDocument.parse(s.xhtml);
        final body = document.rootElement.findElements('body').first;
        return body.children.map((c) => canonicalXml(c, fb2: true)).join();
      },
      canonicalTree: () async {
        final doc = ContentDocument.parseXml(s.xhtml);
        final body = doc
            .childrenOf(ContentDocument.rootIndex)
            .firstWhere((n) => doc.localNameOf(n) == 'body');
        return doc
            .childrenOf(body)
            .map((c) => canonicalContent(doc, c, fb2: true))
            .join();
      },
    );
  }

  @override
  Map<String, Object?> metadata() {
    final m = book.metadata;
    Map<String, Object?> person(Fb2Person p) => {
      'name': p.name,
      'sortAs': p.sortAs,
      if (p.role != null) 'role': p.role,
    };
    return {
      'title': m.title,
      'identifier': m.identifier,
      'language': m.language,
      'author': m.authors.map(person).toList(),
      'translator': m.translators.map(person).toList(),
      'contributor': m.contributors.map(person).toList(),
      'publisher': m.publisher,
      'published': m.published,
      'modified': m.modified,
      'subject': m.subjects,
    };
  }

  @override
  Future<Uint8List?> readCover() async => book.readCover()?.bytes;

  @override
  List<Map<String, Object?>>? toc() => _nav(book.toc);

  @override
  List<Map<String, Object?>>? landmarks() => null;

  @override
  List<Map<String, Object?>>? pageList() => null;

  @override
  Future<int?> resolveHrefIndex(String href) async {
    final index = book.resolveHref(href).index;
    return index < 0 ? null : index;
  }

  @override
  Future<List<LoadedSection>> loadAllSections() async => [
    for (final s in book.sections) (bytes: utf8.encode(s.xhtml).length),
  ];

  @override
  Future<ContentDocument?> contentDocument(int index) async =>
      ContentDocument.parseXml(book.sections[index].xhtml);

  @override
  Future<void> close() async {}
}

class _MobiParity extends ParityBook {
  _MobiParity(this.book);

  final MobiBook book;

  @override
  String get kind => book is MobiKf8 ? 'kf8' : 'mobi6';

  @override
  int get sectionCount => switch (book) {
    MobiKf8(:final book) => book.sections.length,
    MobiLegacy(:final book) => book.sections.length,
  };

  @override
  ParitySection section(int index) => switch (book) {
    MobiLegacy(:final book) => ParitySection(
      id: index,
      size: book.sections[index].size,
      linear: null,
      pageSpread: null,
      cfi: null,
      canonical: () async =>
          canonicalHtml(book.createDocument(index).documentElement!),
      canonicalTree: () async => canonicalContent(
        ContentDocument.parseHtml(book.loadText(index)),
        ContentDocument.rootIndex,
      ),
    ),
    MobiKf8(:final book) => ParitySection(
      id: index,
      size: book.sections[index].isLinear ? book.sections[index].size : null,
      linear: book.sections[index].isLinear ? null : 'no',
      pageSpread: book.sections[index].pageSpread?.name,
      cfi: null,
      canonical: () async {
        if (!book.sections[index].isLinear) return null;
        return parseXhtmlCanonical(await book.loadText(index));
      },
      canonicalTree: () async {
        if (!book.sections[index].isLinear) return null;
        try {
          final doc = ContentDocument.parseXml(await book.loadText(index));
          return canonicalContent(doc, ContentDocument.rootIndex);
        } on ContentParseException {
          return null;
        }
      },
    ),
  };

  @override
  Map<String, Object?> metadata() {
    final m = switch (book) {
      MobiKf8(:final book) => book.metadata,
      MobiLegacy(:final book) => book.metadata,
    };
    return {
      'identifier': m.identifier,
      'title': m.title,
      'author': m.authors,
      'publisher': m.publisher,
      'language': m.language,
      'published': m.published,
      'description': m.description,
      'subject': m.subjects,
      'rights': m.rights,
      'contributor': m.contributors,
    };
  }

  @override
  Future<Uint8List?> readCover() async {
    final cover = await switch (book) {
      MobiKf8(:final book) => book.readCover(),
      MobiLegacy(:final book) => book.readCover(),
    };
    return cover?.bytes;
  }

  @override
  List<Map<String, Object?>>? toc() => switch (book) {
    MobiKf8(:final book) => _nav(book.toc),
    MobiLegacy(:final book) => _nav(book.toc),
  };

  @override
  List<Map<String, Object?>>? landmarks() => switch (book) {
    MobiKf8(:final book) => _nav(book.landmarks),
    MobiLegacy(:final book) => _nav(book.landmarks),
  };

  @override
  List<Map<String, Object?>>? pageList() => null;

  @override
  Future<int?> resolveHrefIndex(String href) async => switch (book) {
    MobiKf8(:final book) => (await book.resolveHref(href))?.index,
    MobiLegacy(:final book) => book.resolveHref(href).index,
  };

  @override
  Future<List<LoadedSection>> loadAllSections() async => switch (book) {
    MobiLegacy(:final book) => [
      for (var i = 0; i < book.sections.length; i++)
        (bytes: book.createDocument(i).outerHtml.length),
    ],
    MobiKf8(:final book) => [
      for (var i = 0; i < book.sections.length; i++)
        if (book.sections[i].isLinear)
          (bytes: utf8.encode(await book.loadText(i)).length),
    ],
  };

  @override
  Future<ContentDocument?> contentDocument(int index) async {
    switch (book) {
      case MobiLegacy(:final book):
        return ContentDocument.parseHtml(book.loadText(index));
      case MobiKf8(:final book):
        if (!book.sections[index].isLinear) return null;
        try {
          return ContentDocument.parseXml(await book.loadText(index));
        } on ContentParseException {
          return null;
        }
    }
  }

  @override
  Future<void> close() => book.close();
}
