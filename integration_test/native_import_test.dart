import 'dart:convert';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:import_flow/import_flow.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vellum/testing.dart';
import 'package:vellum/vellum.dart';

import '../test/support/ui_test_app.dart';
import '../test/support/ui_test_driver.dart';

/// Book import through `vellum` on a real device: the platform image
/// codecs decode each format's cover and the Library shows the results.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EPUB, FB2 and MOBI import natively with their covers', (
    tester,
  ) async {
    final app = await UiTestApp.create(withBook: false);
    addTearDown(app.dispose);
    final cover = encodeSolidPng(600, 900, rgba: 0x8A2B3CFF);

    final epub = ZipBuilder()
      ..add('mimetype', ascii.encode('application/epub+zip'), deflate: false)
      ..add(
        'META-INF/container.xml',
        utf8.encode(
          '<?xml version="1.0"?><container version="1.0" '
          'xmlns="urn:oasis:names:tc:opendocument:xmlns:container">'
          '<rootfiles><rootfile full-path="OEBPS/content.opf" '
          'media-type="application/oebps-package+xml"/></rootfiles></container>',
        ),
      )
      ..add(
        'OEBPS/content.opf',
        utf8.encode(
          '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" '
          'version="3.0" unique-identifier="id">'
          '<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">'
          '<dc:identifier id="id">native-import</dc:identifier>'
          '<dc:title>Native Import EPUB</dc:title>'
          '<dc:creator>Ada Lovelace</dc:creator>'
          '<dc:language>en</dc:language></metadata>'
          '<manifest><item id="c" href="cover.png" media-type="image/png" '
          'properties="cover-image"/>'
          '<item id="ch" href="ch1.xhtml" media-type="application/xhtml+xml"/>'
          '</manifest><spine><itemref idref="ch"/></spine></package>',
        ),
      )
      ..add('OEBPS/cover.png', cover)
      ..add(
        'OEBPS/ch1.xhtml',
        utf8.encode(
          '<html xmlns="http://www.w3.org/1999/xhtml"><body><p>Hi</p></body></html>',
        ),
      );
    final fb2 = utf8.encode(
      '<FictionBook xmlns:l="http://www.w3.org/1999/xlink"><description>'
      '<title-info><author><first-name>Иван</first-name>'
      '<last-name>Сидоров</last-name></author>'
      '<book-title>Нативный импорт FB2</book-title>'
      '<coverpage><image l:href="#c.png"/></coverpage></title-info>'
      '</description><body><section><p>x</p></section></body>'
      '<binary id="c.png" content-type="image/png">${base64Encode(cover)}'
      '</binary></FictionBook>',
    );
    final mobi = MobiBuilder(
      title: 'Native Import MOBI',
      exth: [
        MobiExthRecord.string(100, 'Alan Turing'),
        MobiExthRecord.uint(201, 0),
      ],
    )..addText(utf8.encode('<html><body><p>Hello</p></body></html>'));
    mobi.addResource(cover);

    final expected = {
      'novel.epub': (epub.build(), 'Native Import EPUB', 'Ada Lovelace'),
      'story.fb2': (fb2, 'Нативный импорт FB2', 'Иван Сидоров'),
      'guide.mobi': (mobi.build(), 'Native Import MOBI', 'Alan Turing'),
    };
    final imported = <Book>[];
    for (final entry in expected.entries) {
      final (bytes, title, author) = entry.value;
      final file = File('${app.directory.path}/${entry.key}');
      await file.writeAsBytes(bytes);
      final started = DateTime.now();
      final book = await importBookFile(
        sourceFile: file,
        bookRepository: app.bookRepository,
        logger: app.logger,
      );
      final elapsed = DateTime.now().difference(started);
      expect(book, isNotNull, reason: entry.key);
      expect(book!.title, title);
      expect(book.author, author);
      final coverFile = File(book.coverImagePath!);
      expect(coverFile.existsSync(), isTrue, reason: '${entry.key} cover');
      expect(
        probeImageDimensions(await coverFile.readAsBytes()),
        const ImageDimensions(480, 720),
        reason: '${entry.key} cover decoded by the platform and scaled',
      );
      expect(
        elapsed,
        lessThan(const Duration(seconds: 5)),
        reason: '${entry.key} import time',
      );
      imported.add(book);
    }

    tester.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);
    await tester.pumpWidget(app.widget);
    for (final book in imported) {
      await waitForUi(
        tester,
        () => find
            .byKey(ValueKey('library-grid-${book.id}'))
            .evaluate()
            .isNotEmpty,
        description: '${book.title} in the Library',
      );
    }
    await tester.pump(const Duration(seconds: 1));
    await binding.takeScreenshot('native-import-library');
  });
}
