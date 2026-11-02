import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pagecraft/src/formats/mobi/mobi_compression.dart';
import 'package:pagecraft/src/formats/mobi/mobi_container.dart';
import 'package:pagecraft/src/formats/mobi/mobi_headers.dart';
import 'package:pagecraft/src/formats/mobi/pdb.dart';
import 'package:pagecraft/src/testing/mobi_builder.dart';

import 'mobi_huff_fixture.dart';

const mobiBenchmarkProtocol = 'mobi-decoder-batch-v1';

/// A candidate worker supplies this adapter and reuses the measurement loop.
abstract interface class MobiBenchmarkBackend {
  String get name;
  Future<MobiBenchmarkSession> open(MobiBenchmarkCase input);
}

abstract interface class MobiBenchmarkSession {
  FutureOr<List<Uint8List>> decodeBatch(List<Uint8List> records);
  FutureOr<void> close();
}

class MobiBenchmarkCase {
  MobiBenchmarkCase(Map<String, dynamic> json)
    : id = json['id'] as String,
      compression = json['compression'] as int,
      header = json['header'] == null
          ? null
          : base64Decode(json['header'] as String),
      dictionary = {
        for (final entry
            in (json['dictionary'] as Map<String, dynamic>).entries)
          int.parse(entry.key): base64Decode(entry.value as String),
      },
      records = (json['records'] as List)
          .cast<String>()
          .map(base64Decode)
          .toList(),
      expected = (json['expected'] as List)
          .cast<String>()
          .map(base64Decode)
          .toList();

  final String id;
  final int compression;
  final Uint8List? header;
  final Map<int, Uint8List> dictionary;
  final List<Uint8List> records;
  final List<Uint8List> expected;

  void verify(List<Uint8List> actual) {
    if (actual.length != expected.length) {
      throw StateError('$id: record count differs');
    }
    for (var i = 0; i < actual.length; i++) {
      if (actual[i].length != expected[i].length) {
        throw StateError('$id: output length differs at record $i');
      }
      for (var j = 0; j < actual[i].length; j++) {
        if (actual[i][j] != expected[i][j]) {
          throw StateError('$id: output differs at record $i, byte $j');
        }
      }
    }
  }
}

class DartMobiBenchmarkBackend implements MobiBenchmarkBackend {
  @override
  String get name => 'dart';

  @override
  Future<MobiBenchmarkSession> open(MobiBenchmarkCase input) async {
    if (input.compression == 2) return _DartSession(decompressPalmDoc);
    if (input.compression == 17480) {
      final decoder = await HuffCdicDecoder.load(
        MobiHeaders.read(input.header!).mobi,
        (index) async => input.dictionary[index]!,
      );
      return _DartSession(decoder.decompress);
    }
    throw UnsupportedError(
      'Compression ${input.compression} is not benchmarked',
    );
  }
}

class _DartSession implements MobiBenchmarkSession {
  _DartSession(this.decode);
  final Uint8List Function(Uint8List) decode;

  @override
  List<Uint8List> decodeBatch(List<Uint8List> records) =>
      records.map(decode).toList();

  @override
  void close() {
    // Dart sessions own no native resources.
  }
}

Future<void> main(List<String> args) async {
  try {
    if (args.firstOrNull == 'prepare') {
      await _prepare(args[1], args.skip(2).toList());
    } else {
      await runMobiBenchmarkWorker(args, DartMobiBenchmarkBackend());
    }
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}

/// Measures the Dart-facing call, including bridge dispatch and returned buffers.
/// Candidate Rust adapters must return an asynchronous FRB call here.
Future<void> runMobiBenchmarkWorker(
  List<String> args,
  MobiBenchmarkBackend backend,
) async {
  if (!const bool.fromEnvironment('dart.vm.product')) {
    throw StateError('Compile this worker in AOT through make benchmark-mobi');
  }
  if (args.length != 4) {
    throw ArgumentError('Expected dataset, case ID, samples, warmups');
  }
  final json =
      jsonDecode(await File(args[0]).readAsString()) as Map<String, dynamic>;
  if (json['protocol'] != mobiBenchmarkProtocol) {
    throw StateError('Dataset protocol differs');
  }
  final input = MobiBenchmarkCase(
    (json['cases'] as List).cast<Map<String, dynamic>>().singleWhere(
      (c) => c['id'] == args[1],
    ),
  );
  final samples = int.parse(args[2]);
  final warmups = int.parse(args[3]);
  if (samples < 20 || warmups < 1) {
    throw ArgumentError('Use at least 20 samples and one warmup');
  }
  final timer = Stopwatch()..start();
  final session = await backend.open(input);
  timer.stop();
  final setupUs = timer.elapsedMicroseconds;
  try {
    Future<int> batch() async {
      timer.reset();
      timer.start();
      final output = await session.decodeBatch(input.records);
      timer.stop();
      final elapsed = timer.elapsedMicroseconds;
      // Full byte comparison and disk I/O are outside the measured interval.
      input.verify(output);
      return elapsed;
    }

    final firstBatchUs = await batch();
    for (var i = 0; i < warmups; i++) {
      await batch();
    }
    final times = <int>[];
    for (var i = 0; i < samples; i++) {
      times.add(await batch());
    }
    stdout.writeln(
      jsonEncode({
        'protocol': mobiBenchmarkProtocol,
        'implementation': backend.name,
        'runtime': Platform.version,
        'mode': 'aot',
        'caseId': input.id,
        'records': input.records.length,
        'inputBytes': input.records.fold(0, (n, b) => n + b.length),
        'outputBytes': input.expected.fold(0, (n, b) => n + b.length),
        'verified': true,
        'setupUs': setupUs,
        'firstBatchUs': firstBatchUs,
        'samplesUs': times,
        'processPeakRssBytes': ProcessInfo.maxRss,
      }),
    );
  } finally {
    await session.close();
  }
}

Future<void> _prepare(String output, List<String> books) async {
  Map<String, Object?> data(
    String id,
    String source,
    List<Uint8List> records,
    List<Uint8List> expected,
  ) => {
    'id': id,
    'source': source,
    'compression': 2,
    'header': null,
    'dictionary': <String, String>{},
    'records': records.map(base64Encode).toList(),
    'expected': expected.map(base64Encode).toList(),
  };
  final plain = <Uint8List>[];
  final packed = <Uint8List>[];
  for (var i = 0; i < 8; i++) {
    final text = utf8.encode(
      '<p id="$i">A book with words, links &amp; markup. '
      'Книга с русским текстом. Ein Buch mit Umlauten: äöü. 日本語の本。</p>',
    );
    final bytes = Uint8List.fromList(
      List.generate(4096, (j) => text[j % text.length]),
    );
    plain.add(bytes);
    packed.add(compressPalmDoc(bytes));
  }
  List<Uint8List> repeat(List<Uint8List> pool, int count) =>
      List.generate(count, (i) => pool[i % pool.length]);
  final random = Random(7);
  final literal = Uint8List.fromList(
    List.generate(4096, (_) => random.nextInt(256)),
  );
  final literalEncoded = BytesBuilder();
  for (var i = 0; i < literal.length; i += 8) {
    literalEncoded.addByte(8);
    literalEncoded.add(Uint8List.sublistView(literal, i, i + 8));
  }
  final cases = <Map<String, Object?>>[
    data(
      'palmdoc-mixed-64k',
      'synthetic multilingual text',
      repeat(packed, 16),
      repeat(plain, 16),
    ),
    data(
      'palmdoc-mixed-1m',
      'synthetic multilingual text',
      repeat(packed, 256),
      repeat(plain, 256),
    ),
    data(
      'palmdoc-literals-512k',
      'synthetic binary literal runs',
      repeat([literalEncoded.toBytes()], 128),
      repeat([literal], 128),
    ),
    MobiHuffFixture().datasetCase(16),
    MobiHuffFixture().datasetCase(256),
  ];
  for (final (index, path) in books.indexed) {
    final pdb = await PdbFile.open(path);
    try {
      final container = await MobiContainer.open(pdb, useDartTextReader: true);
      final compression = container.headers.palmdoc.compression;
      if (compression != 2 && compression != 17480) {
        throw ArgumentError('$path is not PalmDOC- or HUFF/CDIC-compressed');
      }
      final records = <Uint8List>[];
      final expected = <Uint8List>[];
      for (var i = 0; i < container.headers.palmdoc.numTextRecords; i++) {
        records.add(
          removeTrailingEntries(
            await container.loadRecord(i + 1),
            container.headers.mobi.trailingFlags,
          ),
        );
        expected.add(await container.loadText(i));
      }
      final huff = container.headers.mobi;
      cases.add({
        ...data(
          'book-$index',
          path.split(Platform.pathSeparator).last,
          records,
          expected,
        ),
        'compression': compression,
        'header': base64Encode(await container.loadRecord(0)),
        'dictionary': {
          if (compression == 17480)
            for (var i = 0; i < huff.numHuffcdic; i++)
              '${huff.huffcdic + i}': base64Encode(
                await container.loadRecord(huff.huffcdic + i),
              ),
        },
      });
    } finally {
      await pdb.close();
    }
  }
  if (await File(output).exists()) {
    throw StateError('Dataset already exists: $output');
  }
  await File(output).writeAsString(
    jsonEncode({'protocol': mobiBenchmarkProtocol, 'cases': cases}),
  );
}
