import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vellum/vellum.dart';

import 'corpus_canonical.dart';
import 'corpus_report.dart';

/// Parity with foliate-js on a whole folder of real books.
///
/// `packages/reader_webview/test_browser/corpus_snapshot.mjs` records what
/// the old reader made of every EPUB, FB2 and MOBI in `VELLUM_CORPUS`;
/// this test opens the same files with vellum and compares metadata, the
/// cover, each section's size, flags and canonical document tree (as a
/// hash, or the tree itself when the snapshot carries one), navigation
/// and link targets. It also times every open and section load and
/// records the process memory growth; `VELLUM_CORPUS_REPORT=<file>`
/// writes the table as Markdown.
///
///     VELLUM_CORPUS=~/Books VELLUM_SNAPSHOT=~/Books/vellum-parity.json \
///         fvm flutter test test/corpus
///
/// Skipped when `VELLUM_CORPUS` is not set: the corpus is not in the repo.
void main() {
  final corpus = Platform.environment['VELLUM_CORPUS'];
  if (corpus == null || corpus.isEmpty) {
    test(
      'corpus parity',
      () {},
      skip: 'set VELLUM_CORPUS (and VELLUM_SNAPSHOT) to run on real books',
    );
    return;
  }
  final snapshotPath =
      Platform.environment['VELLUM_SNAPSHOT'] ?? '$corpus/vellum-parity.json';
  final snapshot =
      jsonDecode(File(snapshotPath).readAsStringSync()) as Map<String, dynamic>;
  final books = snapshot['books'] as Map<String, dynamic>;
  final report = CorpusReport();

  tearDownAll(() {
    final markdown = report.toMarkdown();
    // ignore: avoid_print
    print(markdown);
    final out = Platform.environment['VELLUM_CORPUS_REPORT'];
    if (out != null && out.isNotEmpty) File(out).writeAsStringSync(markdown);
  });

  for (final entry in books.entries) {
    final name = entry.key;
    final data = entry.value as Map<String, dynamic>;
    final path = '$corpus/$name';

    group(name, () {
      if (data['error'] != null) {
        test('foliate-js failed too: ${data['error']}', () async {
          Object? failure;
          try {
            final book = await openForParity(path);
            await book.close();
          } on Exception catch (e) {
            failure = e;
          }
          report.add(
            CorpusRow(
              name: name,
              kind: 'error',
              bytes: File(path).lengthSync(),
              note: failure == null
                  ? 'vellum opens what foliate-js refused'
                  : 'both refuse',
            ),
          );
          expect(
            failure,
            isA<VellumException>(),
            reason: 'foliate-js refused this file; vellum should too',
          );
        });
        return;
      }

      late ParityBook book;
      late CorpusRow row;

      setUpAll(() async {
        final bytes = File(path).lengthSync();
        final rssBefore = ProcessInfo.currentRss;
        final watch = Stopwatch()..start();
        book = await openForParity(path);
        final openMs = watch.elapsedMilliseconds;
        watch.reset();
        final loaded = await book.loadAllSections();
        row = CorpusRow(
          name: name,
          kind: book.kind,
          bytes: bytes,
          jsOpenMs: data['openMs'] as int,
          openMs: openMs,
          sectionsMs: watch.elapsedMilliseconds,
          jsSectionsMs: data['sectionsMs'] as int,
          sectionCount: loaded.length,
          textBytes: loaded.fold<int>(0, (sum, s) => sum + s.bytes),
          rssGrowthBytes: ProcessInfo.currentRss - rssBefore,
        );
        report.add(row);
      });

      tearDownAll(() => book.close());

      test('is the kind foliate-js opened', () {
        expect(book.kind, data['kind']);
      });

      test('metadata matches', () {
        final recorded = data['metadata'] as Map<String, dynamic>;
        expect(book.metadata(), equalsMetadata(recorded));
      });

      test('cover matches', () async {
        final recorded = data['cover'] as Map<String, dynamic>?;
        final cover = await book.readCover();
        if (recorded == null || recorded['error'] != null) {
          expect(cover, isNull, reason: 'foliate-js found no cover');
        } else {
          expect(cover?.length, recorded['size']);
        }
      });

      test('sections match, document for document', () async {
        final recorded = data['sections'] as List;
        expect(book.sectionCount, recorded.length);
        final mismatches = <String>[];
        for (var i = 0; i < recorded.length; i++) {
          final s = recorded[i] as Map<String, dynamic>;
          final section = book.section(i);
          void check(String what, Object? actual, Object? expected) {
            if (jsonEncode(actual) != jsonEncode(expected)) {
              mismatches.add('section $i $what: vellum $actual, js $expected');
            }
          }

          check('id', section.id, s['id']);
          // fb2.js sizes its sections with a stylesheet link whose blob URL
          // vellum does not carry, and the two serializers escape a little
          // differently; sizes only weight progress, so 1% plus the link.
          final sizeEnvelope = book.kind == 'fb2'
              ? 200 + (s['size'] as int? ?? 0) ~/ 100
              : 0;
          final size = section.size;
          final recordedSize = s['size'] as int?;
          if (size == null ||
              recordedSize == null ||
              (size - recordedSize).abs() > sizeEnvelope) {
            check('size', size, recordedSize);
          }
          // epub.js keeps the itemref's `linear` attribute as written.
          check('linear', section.linear, s['linear'] == 'no' ? 'no' : null);
          check('pageSpread', section.pageSpread, s['pageSpread']);
          check('cfi', section.cfi, s['cfi']);
          if (s['hash'] == null) continue;
          // The browser could not parse this section (foliate-js shows
          // its parser error page); there is nothing to match.
          if (s['parserError'] == true) continue;
          final canonical = await section.canonical();
          if (canonical == null) {
            mismatches.add('section $i: vellum could not parse the document');
            continue;
          }
          final tree = s['tree'] as String?;
          String differs(String what, String actual) => tree == null
              ? 'section $i: $what differs (record with VELLUM_TREES=1 '
                    'to see where)'
              : 'section $i: $what ${describeFirstDifference(actual, tree)}';
          if (sha256Hex(canonical) != s['hash']) {
            mismatches.add(differs('document', canonical));
          }
          final watch = Stopwatch()..start();
          final content = await section.canonicalTree();
          report.addTreeTime(name, watch.elapsedMilliseconds);
          if (content == null) {
            mismatches.add('section $i: ContentDocument could not parse it');
          } else if (sha256Hex(content) != s['hash']) {
            mismatches.add(differs('ContentDocument', content));
          }
        }
        expect(mismatches, isEmpty, reason: mismatches.join('\n'));
      });

      test('styles resolve for every section', () async {
        // Not parity (the browser's computed styles are not recorded):
        // the CSS engine must take every real stylesheet and document
        // without failing, in reasonable time, with few distinct styles.
        final ua = CssSheetSource(
          CssStyleSheet.parse(cssUserAgentStyleSheet),
          CssOrigin.userAgent,
        );
        var sheets = 0;
        var rules = 0;
        var distinct = 0;
        var elements = 0;
        // Sections sharing a sheet set share a resolver, as a reader would.
        final resolvers = <String, StyleResolver>{};
        final watch = Stopwatch()..start();
        for (var i = 0; i < book.sectionCount; i++) {
          final doc = await book.contentDocument(i);
          if (doc == null) continue;
          final loaded = await book.styleSheets(i, doc);
          sheets += loaded.length;
          rules += loaded.fold<int>(0, (n, s) => n + s.rules.length);
          final key = loaded.map((s) => identityHashCode(s)).join(',');
          final resolver = resolvers.putIfAbsent(
            key,
            () => StyleResolver([
              ua,
              for (final sheet in loaded)
                CssSheetSource(sheet, CssOrigin.author),
            ]),
          );
          final styles = resolver.resolve(doc);
          distinct += styles.distinctStyleCount;
          elements += doc.nodeCount;
        }
        report.addStyleStats(
          name,
          ms: watch.elapsedMilliseconds,
          sheets: sheets,
          rules: rules,
          distinctStyles: distinct,
          nodes: elements,
        );
      });

      test('navigation matches', () {
        expect(book.toc(), data['toc']);
        expect(book.landmarks(), data['landmarks']);
        expect(book.pageList(), data['pageList']);
      });

      test('link targets resolve to the same sections', () async {
        final recorded = data['resolveHref'] as Map<String, dynamic>;
        final mismatches = <String>[];
        for (final target in recorded.entries) {
          final expected = target.value as Map<String, dynamic>?;
          if (expected != null && expected['error'] != null) continue;
          final index = await book.resolveHrefIndex(target.key);
          final expectedIndex = expected?['index'] as int?;
          if (index != expectedIndex) {
            mismatches.add('${target.key}: vellum $index, js $expectedIndex');
          }
        }
        expect(mismatches, isEmpty, reason: mismatches.join('\n'));
      });
    });
  }
}
