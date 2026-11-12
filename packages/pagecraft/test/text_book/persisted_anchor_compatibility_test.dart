import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagecraft/all_formats.dart';

// Recorded on Flutter 3.44.9 before the framework migration. Keep these
// persisted anchors independent of whichever SDK runs this test.
const _fixturePath = 'test/fixtures/compatibility/flutter_3_44_9_anchors.json';

Future<EpubTextSource> _book(
  Map<String, dynamic> fixture,
) async => EpubTextSource(
  await EpubBook.load(
    MemoryEpubFiles({
      'META-INF/container.xml': utf8.encode(
        '<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">'
        '<rootfiles><rootfile full-path="content.opf" media-type="application/oebps-package+xml"/>'
        '</rootfiles></container>',
      ),
      'content.opf': utf8.encode(
        '<package xmlns="http://www.idpf.org/2007/opf" version="3.0">'
        '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
        '<dc:language>${fixture['language']}</dc:language></metadata>'
        '<manifest><item id="chapter" href="chapter.xhtml" '
        'media-type="application/xhtml+xml"/></manifest>'
        '<spine><itemref idref="chapter"/></spine></package>',
      ),
      'chapter.xhtml': utf8.encode(fixture['document'] as String),
    }),
  ),
);

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 400 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ready(), isTrue, reason: 'reader did not finish opening');
}

void main() {
  final recorded =
      jsonDecode(File(_fixturePath).readAsStringSync()) as Map<String, dynamic>;
  for (final value in recorded['cases'] as List) {
    final fixture = value as Map<String, dynamic>;
    for (final size in [const Size(220, 150), const Size(320, 240)]) {
      test('restores 3.44.9 ${fixture['name']} anchors at $size', () async {
        final source = await _book(fixture);
        addTearDown(source.close);
        final images = BookImageCache(read: (_) async => null);
        addTearDown(images.dispose);
        final positionCfi = fixture['positionCfi'] as String;
        final controller = TextPagesController(
          source: source,
          style: const BookStyle(
            fontScale: 10 / 16,
            lineHeight: 1.5,
            hyphenate: true,
          ),
          fonts: const BookFonts(),
          images: images,
          settings: const TextPageSettings(
            sideMarginPercent: 0,
            topMargin: 10,
            bottomMargin: 10,
          ),
          initialCfi: positionCfi,
        )..setViewport(size);
        addTearDown(controller.dispose);
        await _until(() => controller.isReady);
        expect(controller.rtl, fixture['rtl']);
        final spread = controller.spreadAt(0)!;
        final layout = spread.layout..complete();
        final prepared = layout.prepared;
        final doc = prepared.document;
        final position = doc.textRangeOf(
          cfiToRange(doc, Cfi.parse(positionCfi)),
        );
        expect(doc.textOfRange(position), fixture['positionText']);
        final positionY = layout.locator.yOfCfi(positionCfi)!;
        expect(
          spread.pages.any((page) => page.contains(positionY)),
          isTrue,
          reason: 'the recorded text must be on the restored page',
        );

        final highlightCfi = fixture['highlightCfi'] as String;
        final highlightText = fixture['highlightText'] as String;
        final highlightRange = doc.textRangeOf(
          cfiToRange(doc, Cfi.parse(highlightCfi)),
        );
        expect(doc.textOfRange(highlightRange), highlightText);
        final placed = placeHighlights(
          doc,
          layout.column,
          ColumnPage(0, layout.column.height),
          [
            TextHighlight(
              id: 'saved-before-migration',
              range: highlightRange,
              color: const Color(0x66FFCC00),
            ),
          ],
        );
        expect(placed, isNotEmpty);
        expect(placed.expand((part) => part.rects), isNotEmpty);
        expect(
          placed
              .map(
                (part) => part.item.paragraph.box.plainText(
                  part.start,
                  part.end,
                ),
              )
              .join(),
          highlightText.replaceAll('\u00AD', ''),
          reason: 'layout offsets must still select the saved source text',
        );
        final details = TextSelectionDetails.of(
          prepared,
          highlightRange,
          sectionCfi: source.sectionCfi(0),
          text: highlightText,
        );
        expect(details.cfi, highlightCfi);
        expect(await controller.goToCfi(highlightCfi), isTrue);
        final highlightedPage = controller.spreadAt(0)!;
        expect(
          highlightedPage.pages.any(
            (page) => page.contains(layout.locator.yOfCfi(highlightCfi)!),
          ),
          isTrue,
        );
      });
    }
  }
}
