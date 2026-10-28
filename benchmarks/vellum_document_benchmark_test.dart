import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

/// How long `ContentDocument` takes to build from XHTML chapters of
/// typical and large sizes, and how many nodes they hold. Host/JIT
/// numbers to compare before and after a parser change, not a budget.
void main() {
  test('measures ContentDocument parsing at increasing chapter sizes', () {
    final measurements = <Map<String, Object>>[];
    for (final paragraphs in [100, 400, 1600]) {
      final source = _chapter(paragraphs);
      final sizeBytes = utf8.encode(source).length;
      final samples = <int>[];
      late ContentDocument document;
      for (var run = 0; run < 4; run++) {
        final stopwatch = Stopwatch()..start();
        document = ContentDocument.parseXml(source);
        stopwatch.stop();
        if (run > 0) samples.add(stopwatch.elapsedMicroseconds);
      }
      samples.sort();
      final walk = Stopwatch()..start();
      var textLength = 0;
      for (final node in document.descendantsOf(ContentDocument.rootIndex)) {
        if (document.isText(node)) textLength += document.textOf(node).length;
      }
      walk.stop();
      expect(document.nodeCount, greaterThan(paragraphs * 4));
      // Style resolution with the user-agent sheet and a book-like sheet.
      final resolver = StyleResolver([
        CssSheetSource(
          CssStyleSheet.parse(cssUserAgentStyleSheet),
          CssOrigin.userAgent,
        ),
        CssSheetSource(CssStyleSheet.parse(_authorCss), CssOrigin.author),
      ]);
      final styleSamples = <int>[];
      late ComputedStyles styles;
      for (var run = 0; run < 4; run++) {
        final stopwatch = Stopwatch()..start();
        styles = resolver.resolve(document);
        stopwatch.stop();
        if (run > 0) styleSamples.add(stopwatch.elapsedMicroseconds);
      }
      styleSamples.sort();
      measurements.add({
        'paragraphs': paragraphs,
        'sourceBytes': sizeBytes,
        'nodes': document.nodeCount,
        'textLength': textLength,
        'parseMedianMicroseconds': samples[1],
        'parseSamplesMicroseconds': samples,
        'walkMicroseconds': walk.elapsedMicroseconds,
        'styleMedianMicroseconds': styleSamples[1],
        'styleSamplesMicroseconds': styleSamples,
        'distinctStyles': styles.distinctStyleCount,
      });
    }
    final out = File('.local/performance/vellum-document.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'measurements': measurements,
      }),
    );
    // ignore: avoid_print
    print(measurements.map((m) => m.toString()).join('\n'));
  });
}

const _authorCss = '''
body { margin: 0 5%; font-family: "Book", Georgia, serif; line-height: 1.4; color: #222; }
h1 { font-size: 1.6em; font-weight: bold; margin: 1.5em 0 0.5em; page-break-after: avoid; text-align: center; }
p { margin: 0; text-indent: 1.5em; text-align: justify; }
p.body:first-of-type, h1 + p { text-indent: 0; }
em { font-style: italic; }
a { color: #336; text-decoration: none; }
a:hover { text-decoration: underline; }
.small-caps { font-variant: small-caps; letter-spacing: 0.05em; }
sup { font-size: 0.7em; vertical-align: super; line-height: 0; }
sup a[epub|type] { color: inherit; }
figure { margin: 1em 0; text-align: center; page-break-inside: avoid; }
figure img { max-width: 100%; height: auto; }
figcaption { font-size: 0.9em; font-style: italic; margin-top: 0.5em; }
section > p:nth-child(odd) { background-color: transparent; }
''';

/// A chapter of [paragraphs] paragraphs with the inline markup real
/// books carry: emphasis, links, spans with classes, an image every so
/// often, a footnote reference and a few named entities.
String _chapter(int paragraphs) {
  final buffer = StringBuffer(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">\n'
    '<head><title>Chapter</title><link rel="stylesheet" href="style.css"/></head>\n'
    '<body><section epub:type="chapter" id="ch1"><h1>Chapter One</h1>\n',
  );
  for (var i = 0; i < paragraphs; i++) {
    buffer.write('<p class="body" id="p$i">');
    for (var s = 0; s < 4; s++) {
      buffer.write(
        'Sentence $s of paragraph $i has <em>some emphasis</em>, a '
        '<a href="notes.xhtml#n$i">link</a>, a <span class="small-caps">'
        'span</span> and an&nbsp;entity &amp; a dash&mdash;then more words '
        'to make the line long enough to wrap in a column. ',
      );
    }
    buffer.write('<sup><a epub:type="noteref" href="#fn$i">$i</a></sup></p>\n');
    if (i % 20 == 19) {
      buffer.write(
        '<figure><img src="images/fig$i.jpg" alt="Figure $i"/>'
        '<figcaption>Figure $i</figcaption></figure>\n',
      );
    }
  }
  buffer.write('</section></body></html>\n');
  return buffer.toString();
}
