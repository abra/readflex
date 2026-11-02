import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:reader_native_benchmark/reader_native.dart' as native;
import 'package:pagecraft/src/container/zip_archive.dart';
import 'package:pagecraft/src/container/zip_entry.dart';
import 'package:pagecraft/src/document/content_document.dart';
import 'package:pagecraft/src/formats/fb2/fb2_book.dart' show decodeFb2Text;
import 'package:pagecraft/src/formats/mobi/mobi_container.dart';
import 'package:pagecraft/src/formats/mobi/pdb.dart';
import 'package:xml/xml.dart';

const protocol = 'reader-parts-v1';

Future<void> main(List<String> args) async {
  try {
    if (!const bool.fromEnvironment('dart.vm.product')) {
      throw StateError('Build an AOT executable with dart build cli');
    }
    if (args.length != 4) {
      throw ArgumentError('Expected dataset.json, case ID, dart|rust, samples');
    }
    final dataset = jsonDecode(await File(args[0]).readAsString()) as Map;
    if (dataset['protocol'] != protocol) throw StateError('Protocol differs');
    final job = (dataset['cases'] as List).cast<Map>().singleWhere(
      (item) => item['id'] == args[1],
    );
    final rust = switch (args[2]) {
      'dart' => false,
      'rust' => true,
      _ => throw ArgumentError('Expected dart or rust'),
    };
    final samples = int.parse(args[3]);
    if (samples < 20) throw ArgumentError('Use at least 20 samples');
    if (rust && !(job['kind'] as String).startsWith('mobi-')) {
      await native.ensureReaderNative();
    }
    final base = File(args[0]).absolute.parent.path;
    final inputs = (job['inputs'] as List).cast<String>();
    final texts = <String>[];
    if (const {'xml', 'html', 'fb2-dom'}.contains(job['kind'])) {
      for (final input in inputs) {
        final bytes = await File('$base/$input').readAsBytes();
        texts.add(
          job['kind'] == 'fb2-dom'
              ? decodeFb2Text(bytes)
              : utf8.decode(bytes, allowMalformed: true),
        );
      }
    }
    final timer = Stopwatch()..start();
    final session = await Session.open(job, '$base/${inputs.first}', rust);
    timer.stop();
    final setupUs = timer.elapsedMicroseconds;
    Future<int> measure() async {
      timer.reset();
      timer.start();
      final output = await session.run(texts);
      timer.stop();
      final elapsed = timer.elapsedMicroseconds;
      final digest = fingerprint(output);
      if (digest != job['expected']) {
        throw StateError('${job['id']}: output differs: $digest');
      }
      return elapsed;
    }

    try {
      final firstUs = await measure();
      for (var i = 0; i < 3; i++) {
        await measure();
      }
      final times = <int>[];
      for (var i = 0; i < samples; i++) {
        times.add(await measure());
      }
      final ordered = [...times]..sort();
      stdout.writeln(
        jsonEncode({
          'protocol': protocol,
          'caseId': job['id'],
          'implementation': args[2],
          'runtime': Platform.version,
          'setupUs': setupUs,
          'firstUs': firstUs,
          'samplesUs': times,
          'medianUs': ordered[ordered.length ~/ 2],
          'p95Us': ordered[(ordered.length * .95).ceil() - 1],
          'maxRssBytes': ProcessInfo.maxRss,
          'outputSha256': job['expected'],
        }),
      );
    } finally {
      await session.close();
    }
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}

class Session {
  Session(this.kind, this.path, this.rust, this.names);

  final String kind;
  final String path;
  final bool rust;
  final List<String> names;
  ZipArchive? dartArchive;
  native.NativeArchive? rustArchive;
  List<native.ArchiveEntry> rustEntries = [];
  MobiContainer? dartMobi;
  List<int> recordIndices = [];

  static Future<Session> open(Map job, String path, bool rust) async {
    final session = Session(
      job['kind'] as String,
      path,
      rust,
      (job['entries'] as List? ?? []).cast<String>(),
    );
    if (session.kind.startsWith('mobi-')) {
      session.recordIndices = (job['indices'] as List? ?? []).cast<int>();
      final pdb = await PdbFile.open(path);
      try {
        session.dartMobi = await MobiContainer.open(
          pdb,
          useDartTextReader: !rust,
        );
      } catch (_) {
        await pdb.close();
        rethrow;
      }
    } else if (session.kind == 'zip-read') {
      if (rust) {
        session.rustArchive = await native.NativeArchive.open(path: path);
        session.rustEntries = await session.rustArchive!.entries();
      } else {
        session.dartArchive = await ZipArchive.open(path);
      }
    }
    return session;
  }

  Future<List<Object>> run(List<String> texts) async {
    if (kind == 'mobi-records') {
      return [await dartMobi!.loadAllText()];
    }
    if (kind == 'mobi-sequence') {
      return [
        for (final index in recordIndices) await dartMobi!.loadText(index),
      ];
    }
    if (kind == 'zip-open') {
      if (rust) {
        final archive = await native.NativeArchive.open(path: path);
        try {
          return [(await archive.entries()).map(zipEntry).toList()];
        } finally {
          archive.dispose();
        }
      }
      final archive = await ZipArchive.open(path);
      try {
        return [archive.entries];
      } finally {
        await archive.close();
      }
    }
    if (kind == 'zip-read') {
      final output = <Object>[];
      for (final name in names) {
        if (rust) {
          final entry = rustEntries.firstWhere((item) => item.name == name);
          output.add(
            await rustArchive!.readEntry(
              offset: entry.localHeaderOffset,
              maxBytes: BigInt.from(512 * 1024 * 1024),
            ),
          );
        } else {
          output.add(await dartArchive!.read(dartArchive!.entry(name)!));
        }
      }
      return output;
    }
    final output = <Object>[];
    for (final text in texts) {
      if (kind == 'fb2-dom') {
        output.add(
          rust
              ? xmlDocument(
                  await native.parseXmlAsync(text: text, namespaces: true),
                )
              : XmlDocument.parse(text),
        );
      } else if (rust) {
        output.add(
          ArenaOutput(
            kind == 'html'
                ? await native.parseHtmlAsync(text: text)
                : await native.parseXmlAsync(text: text, namespaces: false),
          ),
        );
      } else {
        output.add(
          kind == 'html'
              ? ContentDocument.parseHtml(text)
              : ContentDocument.parseXml(text),
        );
      }
    }
    return output;
  }

  Future<void> close() async {
    await dartArchive?.close();
    rustArchive?.dispose();
    await dartMobi?.close();
  }
}

ZipEntry zipEntry(native.ArchiveEntry entry) => ZipEntry(
  name: entry.name,
  compression: switch (entry.method) {
    0 => ZipCompression.stored,
    8 => ZipCompression.deflate,
    _ => ZipCompression.unsupported,
  },
  compressedSize: entry.compressedSize.toInt(),
  uncompressedSize: entry.uncompressedSize.toInt(),
  localHeaderOffset: entry.localHeaderOffset.toInt(),
  crc32: entry.crc32,
  isEncrypted: entry.encrypted,
);

/// Include the indexes and view slots that Dart's arena eagerly builds.
/// This is a benchmark output, not a replacement for ContentDocument.
class ArenaOutput {
  ArenaOutput(this.data)
    : localNames = data.qualifiedNames.map((n) => n.split(':').last).toList(),
      views = List<Object?>.filled(data.kinds.length, null) {
    for (var node = 0; node < data.kinds.length; node++) {
      if (data.kinds[node] != 0) continue;
      for (
        var a = data.attributeStarts[node];
        a < data.attributeStarts[node] + data.attributeCounts[node];
        a++
      ) {
        final name = data.attributeNames[a];
        if (name == 'id') {
          ids.putIfAbsent(data.attributeValues[a], () => node);
        }
      }
    }
  }

  final native.NativeDocument data;
  final List<String> localNames;
  final Map<String, int> ids = {};
  final List<Object?> views;
}

XmlDocument xmlDocument(native.NativeDocument arena) {
  final document = XmlDocument();
  final nodes = <XmlNode>[];
  for (var i = 0; i < arena.kinds.length; i++) {
    final XmlNode node;
    if (arena.kinds[i] == 0) {
      final start = arena.attributeStarts[i];
      node = XmlElement(
        XmlName.fromString(arena.qualifiedNames[arena.names[i]]),
        [
          for (var a = start; a < start + arena.attributeCounts[i]; a++)
            XmlAttribute(
              XmlName.fromString(arena.attributeNames[a]),
              arena.attributeValues[a],
            ),
        ],
      );
    } else {
      final text = arena.texts[arena.names[i]];
      node = arena.kinds[i] == 2 ? XmlCDATA(text) : XmlText(text);
    }
    nodes.add(node);
    final parent = arena.parents[i];
    (parent < 0 ? document.children : nodes[parent].children).add(node);
  }
  return document;
}

String fingerprint(List<Object> outputs) {
  final canonical = <Object>[];
  for (final output in outputs) {
    if (output is Uint8List) {
      canonical.add([output.length, sha256.convert(output).toString()]);
    } else if (output is List<ZipEntry>) {
      canonical.add([
        for (final e in output)
          [
            e.name,
            e.compression.name,
            e.compressedSize,
            e.uncompressedSize,
            e.localHeaderOffset,
            e.crc32,
            e.isEncrypted,
          ],
      ]);
    } else if (output is ContentDocument) {
      canonical.add([
        for (var i = 0; i < output.nodeCount; i++)
          [
            output.kindOf(i).index,
            output.parentOf(i),
            output.firstChildOf(i),
            output.lastChildOf(i),
            output.previousSiblingOf(i),
            output.nextSiblingOf(i),
            if (output.isElement(i)) ...[
              output.qualifiedNameOf(i),
              sortedAttributes({
                for (final a in output.attributesOf(i)) a.$1: a.$2,
              }),
            ] else
              output.textOf(i),
          ],
      ]);
    } else if (output is ArenaOutput) {
      final d = output.data;
      canonical.add([
        for (var i = 0; i < d.kinds.length; i++)
          [
            d.kinds[i],
            d.parents[i],
            d.firstChildren[i],
            d.lastChildren[i],
            d.previousSiblings[i],
            d.nextSiblings[i],
            if (d.kinds[i] == 0) ...[
              d.qualifiedNames[d.names[i]],
              sortedAttributes({
                for (
                  var a = d.attributeStarts[i];
                  a < d.attributeStarts[i] + d.attributeCounts[i];
                  a++
                )
                  d.attributeNames[a]: d.attributeValues[a],
              }),
            ] else
              d.texts[d.names[i]],
          ],
      ]);
    } else if (output is XmlDocument) {
      Object tree(XmlNode node) => node is XmlElement
          ? [
              node.name.qualified,
              sortedAttributes({
                for (final a in node.attributes) a.name.qualified: a.value,
              }),
              node.children
                  .where(
                    (n) => n is XmlElement || n is XmlText || n is XmlCDATA,
                  )
                  .map(tree)
                  .toList(),
            ]
          : [node is XmlCDATA ? 'cdata' : 'text', node.value];
      canonical.add(tree(output.rootElement));
    } else {
      throw StateError('Unexpected output: ${output.runtimeType}');
    }
  }
  return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
}

List<List<String>> sortedAttributes(Map<String, String> attributes) => [
  for (final key in attributes.keys.toList()..sort()) [key, attributes[key]!],
];
