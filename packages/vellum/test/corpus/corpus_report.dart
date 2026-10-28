/// One book's timings in the corpus run.
class CorpusRow {
  CorpusRow({
    required this.name,
    required this.kind,
    required this.bytes,
    this.jsOpenMs,
    this.openMs,
    this.jsSectionsMs,
    this.sectionsMs,
    this.sectionCount,
    this.textBytes,
    this.rssGrowthBytes,
    this.note,
  });

  final String name;
  final String kind;
  final int bytes;
  final int? jsOpenMs;
  final int? openMs;
  final int? jsSectionsMs;
  final int? sectionsMs;
  final int? sectionCount;
  final int? textBytes;

  /// Resident set growth across opening the book and loading every
  /// section: an upper bound on what the parsers keep.
  final int? rssGrowthBytes;
  final String? note;

  /// Building a [ContentDocument] for every section, summed; includes
  /// the canonical walk the parity check makes.
  int treeMs = 0;

  /// Loading and parsing every section's stylesheets and resolving the
  /// styles of every element, summed.
  int styleMs = 0;
  int sheets = 0;
  int rules = 0;
  int distinctStyles = 0;
  int styledNodes = 0;
}

/// The timing table of a corpus run, as Markdown.
class CorpusReport {
  final List<CorpusRow> rows = [];

  void add(CorpusRow row) => rows.add(row);

  void addTreeTime(String name, int ms) {
    for (final row in rows) {
      if (row.name == name) row.treeMs += ms;
    }
  }

  void addStyleStats(
    String name, {
    required int ms,
    required int sheets,
    required int rules,
    required int distinctStyles,
    required int nodes,
  }) {
    for (final row in rows) {
      if (row.name != name) continue;
      row.styleMs += ms;
      row.sheets += sheets;
      row.rules += rules;
      row.distinctStyles += distinctStyles;
      row.styledNodes += nodes;
    }
  }

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln(
        '| Book | Kind | MB | Open js/vellum ms | Sections | '
        'Sections js/vellum ms | Tree ms | Style ms | Sheets/rules | '
        'Styles/nodes | Text MB | RSS +MB | Note |',
      )
      ..writeln(
        '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|',
      );
    String mb(int? bytes) =>
        bytes == null ? '' : (bytes / (1024 * 1024)).toStringAsFixed(1);
    for (final row in rows) {
      buffer.writeln(
        '| ${row.name} | ${row.kind} | ${mb(row.bytes)} | '
        '${row.jsOpenMs ?? ''}/${row.openMs ?? ''} | ${row.sectionCount ?? ''} | '
        '${row.jsSectionsMs ?? ''}/${row.sectionsMs ?? ''} | ${row.treeMs} | '
        '${row.styleMs} | ${row.sheets}/${row.rules} | '
        '${row.distinctStyles}/${row.styledNodes} | '
        '${mb(row.textBytes)} | ${mb(row.rssGrowthBytes)} | ${row.note ?? ''} |',
      );
    }
    final timed = rows.where((r) => r.openMs != null).toList();
    if (timed.isNotEmpty) {
      int max(Iterable<int> values) => values.reduce((a, b) => a > b ? a : b);
      int sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);
      buffer
        ..writeln()
        ..writeln(
          '${timed.length} books; open max ${max(timed.map((r) => r.openMs!))} ms '
          '(js ${max(timed.map((r) => r.jsOpenMs ?? 0))} ms), total '
          '${sum(timed.map((r) => r.openMs!))} ms (js '
          '${sum(timed.map((r) => r.jsOpenMs ?? 0))} ms); sections max '
          '${max(timed.map((r) => r.sectionsMs!))} ms (js '
          '${max(timed.map((r) => r.jsSectionsMs ?? 0))} ms); tree max '
          '${max(timed.map((r) => r.treeMs))} ms, total '
          '${sum(timed.map((r) => r.treeMs))} ms; style max '
          '${max(timed.map((r) => r.styleMs))} ms, total '
          '${sum(timed.map((r) => r.styleMs))} ms over '
          '${sum(timed.map((r) => r.rules))} rules; RSS growth max '
          '${mb(max(timed.map((r) => r.rssGrowthBytes ?? 0)))} MB.',
        );
    }
    return buffer.toString();
  }
}
