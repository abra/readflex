import 'dart:io';
import 'dart:typed_data';

import 'package:reader_native_benchmark/reader_native.dart' as native;
import 'package:test/test.dart';
import 'package:pagecraft/src/container/zip_archive.dart';
import 'package:pagecraft/src/document/content_document.dart';
import 'package:pagecraft/src/formats/mobi/mobi_container.dart';
import 'package:pagecraft/src/formats/mobi/pdb.dart';
import 'package:pagecraft/src/testing/zip_builder.dart';
import 'package:xml/xml.dart';

import '../bin/reader_parts_benchmark.dart' as benchmark;

void main() {
  setUpAll(
    () => native.ensureReaderNative(
      libraryPath: File(
        'rust/target/release/${Platform.isMacOS
            ? 'libpagecraft_reader_benchmark.dylib'
            : Platform.isWindows
            ? 'pagecraft_reader_benchmark.dll'
            : 'libpagecraft_reader_benchmark.so'}',
      ).absolute.path,
    ),
  );

  for (final source in [
    '<html xmlns="urn:x"><body id="a">a<![CDATA[b]]>c</body></html>',
    '<a t="x\r\ny\t&#10;">A\r\nB &amp; &nbsp; &#x1F642;</a>',
    '<x:a xmlns:x="urn:x" xml:lang="ru"><b id="same"/><b id="same"/></x:a>',
  ]) {
    test('XML arena parity: $source', () async {
      final dart = ContentDocument.parseXml(source);
      final rust = benchmark.ArenaOutput(
        await native.parseXmlAsync(text: source, namespaces: false),
      );
      expect(benchmark.fingerprint([rust]), benchmark.fingerprint([dart]));
    });
  }

  for (final source in [
    '<p>Hello &amp; мир<b>bold',
    '<table>loose<tr><td>x</table><p>end',
    '<svg viewBox="0 0 2 2"><text>x</text></svg>',
    '<p>a<!-- ignored -->b<script>if (a < b) c()</script>',
  ]) {
    test('HTML arena parity: $source', () async {
      final dart = ContentDocument.parseHtml(source);
      final rust = benchmark.ArenaOutput(
        await native.parseHtmlAsync(text: source),
      );
      expect(benchmark.fingerprint([rust]), benchmark.fingerprint([dart]));
    });
  }

  test('XML DOM conversion keeps namespaces, attributes and CDATA', () async {
    const source =
        '<FictionBook xmlns="urn:fb2" xmlns:l="urn:link">'
        '<body><p id="a" t="x\r\ny\tz">x\r\n<![CDATA[y\r\nz]]><image l:href="#x"/></p></body>'
        '</FictionBook>';
    final rust = benchmark.xmlDocument(
      await native.parseXmlAsync(text: source, namespaces: true),
    );
    expect(
      benchmark.fingerprint([rust]),
      benchmark.fingerprint([XmlDocument.parse(source)]),
    );
    expect(rust.rootElement.namespaceUri, 'urn:fb2');
  });

  test('malformed XML fails across the bridge', () async {
    for (final source in ['<a><b></a>', '<a x="1" x="2"/>', '<a>']) {
      await expectLater(
        native.parseXmlAsync(text: source, namespaces: false),
        throwsA(anything),
      );
    }
  });

  for (final zip64 in [false, true]) {
    test(
      'stored/deflated ZIP metadata and byte parity, ZIP64=$zip64',
      () async {
        final temporary = await Directory.systemTemp.createTemp('reader-zip-');
        try {
          final builder = ZipBuilder(comment: 'comment', zip64Eocd: zip64)
            ..add('stored.txt', [0, 1, 2, 255])
            ..addEntry(
              ZipBuilderEntry(
                'текст.txt',
                List.filled(8192, 65),
                deflate: true,
                utf8Flag: true,
                zip64: zip64,
              ),
            )
            ..add('caf\x82.txt', [3]);
          final path = '${temporary.path}/book.zip';
          await File(path).writeAsBytes(builder.build());
          final dart = await ZipArchive.open(path);
          final rust = await native.NativeArchive.open(path: path);
          try {
            final entries = await rust.entries();
            expect(entries.map(benchmark.zipEntry).toList(), dart.entries);
            for (var i = 0; i < entries.length; i++) {
              expect(
                await rust.readEntry(
                  offset: entries[i].localHeaderOffset,
                  maxBytes: BigInt.from(10000),
                ),
                await dart.read(dart.entries[i]),
              );
            }
            await expectLater(
              rust.readEntry(
                offset: entries[1].localHeaderOffset,
                maxBytes: BigInt.from(10),
              ),
              throwsA(anything),
            );
          } finally {
            rust.dispose();
            await dart.close();
          }
        } finally {
          await temporary.delete(recursive: true);
        }
      },
    );
  }

  test('native ZIP enforces actual inflated size', () async {
    final temporary = await Directory.systemTemp.createTemp('reader-limit-');
    try {
      final builder = ZipBuilder()
        ..addEntry(
          ZipBuilderEntry(
            'large',
            List.filled(100000, 65),
            deflate: true,
            declaredUncompressedSize: 1,
          ),
        );
      final path = '${temporary.path}/book.zip';
      await File(path).writeAsBytes(builder.build());
      final archive = await native.NativeArchive.open(path: path);
      try {
        final entry = (await archive.entries()).single;
        await expectLater(
          archive.readEntry(
            offset: entry.localHeaderOffset,
            maxBytes: BigInt.from(1024),
          ),
          throwsA(anything),
        );
      } finally {
        archive.dispose();
      }
    } finally {
      await temporary.delete(recursive: true);
    }
  });

  for (final name in ['six.mobi', 'eight.azw3']) {
    test('MOBI/KF8 text record I/O and decoding match Dart: $name', () async {
      final path = File(
        '../../packages/pagecraft/test/fixtures/mobi/$name',
      ).absolute.path;
      final bytes = await File(path).readAsBytes();
      final data = ByteData.sublistView(bytes);
      final count = data.getUint16(76);
      final offsets = [
        for (var i = 0; i < count; i++) data.getUint32(78 + i * 8),
        bytes.length,
      ];
      final dart = await MobiContainer.open(await PdbFile.open(path));
      final rust = await native.NativeFile.open(path: path);
      try {
        final headers = dart.headers;
        final ranges = [
          for (var i = 0; i < headers.palmdoc.numTextRecords; i++)
            native.ByteRange(
              offset: BigInt.from(offsets[i + 1]),
              length: BigInt.from(offsets[i + 2] - offsets[i + 1]),
            ),
        ];
        await rust.configureMobi(
          compression: headers.palmdoc.compression,
          dictionaryRanges: [],
          trailingFlags: headers.mobi.trailingFlags,
        );
        final expected = BytesBuilder(copy: false);
        for (var i = 0; i < ranges.length; i++) {
          final record = await dart.loadText(i);
          expect(await rust.readMobiRecord(range: ranges[i]), record);
          expected.add(record);
        }
        expect(await rust.readMobiStream(ranges: ranges), expected.takeBytes());
      } finally {
        rust.dispose();
        await dart.close();
      }
    });
  }
}
