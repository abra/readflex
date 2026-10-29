import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:vellum/src/container/zip_archive.dart';
import 'package:vellum/src/formats/fb2/fb2_book.dart' show decodeFb2Text;
import 'package:vellum/src/formats/mobi/mobi6_book.dart';
import 'package:vellum/src/formats/mobi/mobi_container.dart';
import 'package:vellum/src/formats/mobi/mobi_headers.dart';
import 'package:vellum/src/formats/mobi/pdb.dart';
import 'package:vellum/src/testing/zip_builder.dart';

import 'reader_parts_benchmark.dart' show Session, fingerprint, protocol;

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected selection.json, output directory');
  }
  final selection = (jsonDecode(await File(args[0]).readAsString()) as List)
      .cast<Map>();
  final directory = await Directory(args[1]).absolute.create(recursive: true);
  final files = <String, String>{};
  final cases = <Map<String, Object>>[];
  final failures = <Map<String, String>>[];
  final images = <Uint8List>[];
  Future<void> save(String name, List<int> bytes) async {
    await File('${directory.path}/$name').writeAsBytes(bytes);
    files[name] = sha256.convert(bytes).toString();
  }

  for (final item in selection) {
    final id = item['id'] as String;
    final path = item['path'] as String;
    final format = item['format'] as String;
    try {
      final bytes = await File(path).readAsBytes();
      final file = '$id.$format';
      await save(file, bytes);
      if (format == 'epub' || format == 'cbz' || format == 'fb2.zip') {
        final archive = await ZipArchive.open('${directory.path}/$file');
        try {
          final entries = archive.entries.where((e) => !e.isDirectory).toList();
          cases.add({
            'id': '$id/open',
            'kind': 'zip-open',
            'inputs': [file],
          });
          final selected = entries.take(24).toList();
          cases.add({
            'id': '$id/read-${selected.length}',
            'kind': 'zip-read',
            'inputs': [file],
            'entries': selected.map((e) => e.name).toList(),
          });
          final chapters =
              entries
                  .where(
                    (e) => RegExp(
                      r'\.(xhtml|html|htm)$',
                      caseSensitive: false,
                    ).hasMatch(e.name),
                  )
                  .toList()
                ..sort(
                  (a, b) => b.uncompressedSize.compareTo(a.uncompressedSize),
                );
          final names = <String>[];
          for (var i = 0; i < chapters.length && i < 2; i++) {
            final name = '$id-chapter-$i.xhtml';
            await save(name, await archive.read(chapters[i]));
            names.add(name);
          }
          if (names.isNotEmpty) {
            cases.add({
              'id': '$id/xml-largest-2',
              'kind': 'xml',
              'inputs': names,
            });
          }
          if (images.length < 24) {
            for (final entry in entries.where(
              (e) => RegExp(
                r'\.(png|jpe?g)$',
                caseSensitive: false,
              ).hasMatch(e.name),
            )) {
              images.add(await archive.read(entry));
              if (images.length == 24) break;
            }
          }
        } finally {
          await archive.close();
        }
      } else if (format == 'fb2') {
        cases.add({
          'id': '$id/xml-dom',
          'kind': 'fb2-dom',
          'inputs': [file],
        });
      } else if (format == 'mobi' || format == 'azw3') {
        final container = await MobiContainer.open(
          await PdbFile.open('${directory.path}/$file'),
          useDartTextReader: true,
        );
        try {
          final data = ByteData.sublistView(bytes);
          final count = data.getUint16(76);
          final offsets = [
            for (var i = 0; i < count; i++) data.getUint32(78 + i * 8),
            bytes.length,
          ];
          final first = MobiHeaders.read(
            Uint8List.sublistView(bytes, offsets[0], offsets[1]),
          );
          final start = first.mobi.version < 8 && container.isKf8
              ? first.exth!.boundary!
              : 0;
          List<int> range(int record) => [
            offsets[record],
            offsets[record + 1] - offsets[record],
          ];
          final headers = container.headers;
          final textCount = headers.palmdoc.numTextRecords;
          if (textCount > 0) {
            cases.add({
              'id': '$id/first-next-middle-last',
              'kind': 'mobi-sequence',
              'inputs': [file],
              'indices': [
                0,
                if (textCount > 1) 1,
                textCount ~/ 2,
                textCount - 1,
              ],
            });
          }
          cases.add({
            'id': '$id/text-records',
            'kind': 'mobi-records',
            'inputs': [file],
            'compression': headers.palmdoc.compression,
            'mobiVersion': headers.mobi.version,
            'trailingFlags': headers.mobi.trailingFlags,
            'records': [
              for (var i = 0; i < headers.palmdoc.numTextRecords; i++)
                range(start + i + 1),
            ],
            'dictionary': headers.palmdoc.compression == 17480
                ? [
                    for (var i = 0; i < headers.mobi.numHuffcdic; i++)
                      range(start + headers.mobi.huffcdic + i),
                  ]
                : <List<int>>[],
          });
          if (!container.isKf8) {
            final book = await Mobi6Book.load(container);
            final sections = [...book.sections]
              ..sort((a, b) => b.size.compareTo(a.size));
            final names = <String>[];
            for (var i = 0; i < sections.length && i < 2; i++) {
              final name = '$id-chapter-$i.html';
              await save(name, utf8.encode(book.loadText(sections[i].index)));
              names.add(name);
            }
            cases.add({
              'id': '$id/html-largest-2',
              'kind': 'html',
              'inputs': names,
            });
          }
        } finally {
          await container.close();
        }
      }
      stdout.writeln('Prepared $id ($format)');
    } catch (error) {
      failures.add({'id': id, 'path': path, 'error': '$error'});
      stderr.writeln('Dart preparation failed for $id: $error');
    }
  }
  if (images.isNotEmpty) {
    for (final deflate in [false, true]) {
      final builder = ZipBuilder();
      final names = <String>[];
      for (var i = 0; i < images.length; i++) {
        final name =
            '${i.toString().padLeft(3, '0')}.${images[i].first == 137 ? 'png' : 'jpg'}';
        builder.add(name, images[i], deflate: deflate);
        names.add(name);
      }
      final id = 'synthetic-cbz-${deflate ? 'deflate' : 'stored'}';
      final name = '$id.cbz';
      await save(name, builder.build());
      cases.add({
        'id': '$id/read-${names.length}',
        'kind': 'zip-read',
        'inputs': [name],
        'entries': names,
      });
    }
  }
  final valid = <Map<String, Object>>[];
  for (final job in cases) {
    final inputs = (job['inputs']! as List).cast<String>();
    try {
      final session = await Session.open(
        job,
        '${directory.path}/${inputs.first}',
        false,
      );
      try {
        final texts = <String>[];
        if (job['kind'] == 'xml' ||
            job['kind'] == 'html' ||
            job['kind'] == 'fb2-dom') {
          for (final name in inputs) {
            final bytes = await File('${directory.path}/$name').readAsBytes();
            texts.add(
              job['kind'] == 'fb2-dom'
                  ? decodeFb2Text(bytes)
                  : utf8.decode(bytes, allowMalformed: true),
            );
          }
        }
        job['expected'] = fingerprint(await session.run(texts));
        valid.add(job);
      } finally {
        await session.close();
      }
    } catch (error) {
      failures.add({'id': job['id']! as String, 'error': '$error'});
    }
  }
  await File('${directory.path}/dataset.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'protocol': protocol,
      'files': files,
      'cases': valid,
      'selection': selection,
      'preparationFailures': failures,
    }),
  );
  stdout.writeln(
    'Prepared ${valid.length} cases; ${failures.length} Dart preparation failures',
  );
}
