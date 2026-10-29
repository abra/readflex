import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:vellum/src/formats/mobi/mobi_compression.dart';
import 'package:vellum/src/formats/mobi/mobi_container.dart';
import 'package:vellum/src/formats/mobi/pdb.dart';
import 'package:vellum/src/testing/mobi_builder.dart';

import '../../mobi_decoder_benchmark.dart';
import '../../mobi_huff_fixture.dart';
import '../bin/mobi_rust_backend.dart';

void main() {
  setUpAll(initializeMobiRustBenchmark);
  tearDownAll(disposeMobiRustBenchmark);

  test('measurement worker rejects this JIT test process', () async {
    await expectLater(
      runMobiBenchmarkWorker([], DartMobiBenchmarkBackend()),
      throwsStateError,
    );
  });

  test(
    'PalmDOC matches Dart for every two-byte input and seeded records',
    () async {
      final random = Random(114);
      final records = [
        Uint8List(0),
        for (var i = 0; i < 65536; i++) Uint8List.fromList([i >> 8, i & 255]),
        for (var i = 0; i < 5000; i++)
          Uint8List.fromList(
            List.generate(random.nextInt(257), (_) => random.nextInt(256)),
          ),
      ];
      final session = await RustMobiBenchmarkBackend().open(_palmDocCase());
      try {
        expect(
          await session.decodeBatch(records),
          records.map(decompressPalmDoc).toList(),
        );
      } finally {
        await session.close();
      }
    },
  );

  test(
    'PalmDOC decodes compressed multilingual records to their originals',
    () async {
      final records = List.generate(
        32,
        (i) => Uint8List.fromList(
          utf8.encode(
            List.filled(i + 1, 'A book. Книга. 日本語の本。 ÄÖÜ.\n').join(),
          ),
        ),
      );
      final session = await RustMobiBenchmarkBackend().open(_palmDocCase());
      try {
        expect(
          await session.decodeBatch(records.map(compressPalmDoc).toList()),
          records,
        );
      } finally {
        await session.close();
      }
    },
  );

  test('committed MOBI fixture matches the production container', () async {
    final pdb = await PdbFile.open(
      '../../packages/vellum/test/fixtures/mobi/six.mobi',
    );
    try {
      final container = await MobiContainer.open(pdb);
      final session = await RustMobiBenchmarkBackend().open(_palmDocCase());
      try {
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
        expect(await session.decodeBatch(records), expected);
      } finally {
        await session.close();
      }
    } finally {
      await pdb.close();
    }
  });

  test(
    'HUFF prefixes, two CDIC records and cached recursive phrases match Dart',
    () async {
      final fixture = MobiHuffFixture();
      final input = MobiBenchmarkCase(fixture.datasetCase(1));
      final dart = await DartMobiBenchmarkBackend().open(input);
      final rust = await RustMobiBenchmarkBackend().open(input);
      final random = Random(83);
      final records = [
        fixture.record,
        Uint8List.fromList([128, 128, 129]),
        Uint8List(0),
        for (var i = 0; i < 500; i++)
          Uint8List.fromList(
            List.generate(random.nextInt(129), (_) => random.nextInt(256)),
          ),
      ];
      try {
        final expected = await dart.decodeBatch(records);
        expect(expected.first, fixture.expected);
        expect(await rust.decodeBatch(records), expected);
        // Reuse the native cache and exercise FRB's exclusive mutable borrow.
        final repeated = await Future.wait(
          List.generate(4, (_) async => rust.decodeBatch(records)),
        );
        for (final output in repeated) {
          expect(output, expected);
        }
      } finally {
        await dart.close();
        await rust.close();
      }
    },
  );

  test('HUFF dictionary truncation fails in both backends', () async {
    final fixture = MobiHuffFixture();
    for (final (index, length) in [(1, 10), (1, 100), (2, 100), (3, 100)]) {
      final json = fixture.datasetCase(1);
      json['dictionary'] = {
        for (final e in fixture.dictionary.entries)
          '${e.key}': base64Encode(
            e.key == index
                ? Uint8List.sublistView(e.value, 0, length)
                : e.value,
          ),
      };
      final input = MobiBenchmarkCase(json);
      await expectLater(
        DartMobiBenchmarkBackend().open(input),
        throwsA(isA<Error>()),
      );
      await expectLater(
        RustMobiBenchmarkBackend().open(input),
        throwsA(isA<Exception>()),
      );
    }
  });

  test(
    'HUFF codes from one to 32 bits match Dart across byte boundaries',
    () async {
      for (final width in [1, 2, 3, 7, 9, 16, 24, 31, 32]) {
        final input = _fixedWidthHuffCase(width);
        final dart = await DartMobiBenchmarkBackend().open(input);
        final rust = await RustMobiBenchmarkBackend().open(input);
        try {
          input.verify(await dart.decodeBatch(input.records));
          input.verify(await rust.decodeBatch(input.records));
        } finally {
          await dart.close();
          await rust.close();
        }
      }
    },
  );

  test('sessions release explicitly and reject use after close', () async {
    final session = await RustMobiBenchmarkBackend().open(_palmDocCase());
    await session.close();
    await session.close();
    expect(() => session.decodeBatch([Uint8List(0)]), throwsStateError);
  });

  test('unsupported compression fails without creating a session', () async {
    final input = _palmDocCase(compression: 1);
    await expectLater(
      RustMobiBenchmarkBackend().open(input),
      throwsA(isA<Exception>()),
    );
  });
}

MobiBenchmarkCase _palmDocCase({int compression = 2}) => MobiBenchmarkCase({
  'id': 'test',
  'compression': compression,
  'header': null,
  'dictionary': <String, String>{},
  'records': <String>[],
  'expected': <String>[],
});

MobiBenchmarkCase _fixedWidthHuffCase(int width) {
  final fixture = MobiHuffFixture();
  final huff = Uint8List(24 + 256 * 4 + 32 * 8);
  final table = ByteData.sublistView(huff)
    ..setUint32(0, 0x48554646)
    ..setUint32(8, 24)
    ..setUint32(12, 24 + 256 * 4);
  for (var i = 0; i < 256; i++) {
    table.setUint32(24 + i * 4, min(width, 31));
  }
  for (var length = 1; length <= 32; length++) {
    table
      ..setUint32(
        24 + 256 * 4 + (length - 1) * 8,
        length < width ? 1 << length : 0,
      )
      ..setUint32(24 + 256 * 4 + (length - 1) * 8 + 4, (1 << width) - 1);
  }
  final cdic = Uint8List(16 + 256 * 2 + 256 * 3);
  final dictionary = ByteData.sublistView(cdic)
    ..setUint32(0, 0x43444943)
    ..setUint32(4, 16)
    ..setUint32(8, 256)
    ..setUint32(12, 8);
  for (var i = 0; i < 256; i++) {
    dictionary
      ..setUint16(16 + i * 2, 512 + i * 3)
      ..setUint16(16 + 512 + i * 3, 0x8001);
    cdic[16 + 512 + i * 3 + 2] = i;
  }
  final expected = Uint8List.fromList(
    List.generate(257, (i) => i % min(256, 1 << width)),
  );
  final encoded = Uint8List((expected.length * width + 7) ~/ 8);
  var position = 0;
  for (final index in expected) {
    final code = (1 << width) - 1 - index;
    for (var bit = width - 1; bit >= 0; bit--) {
      encoded[position >> 3] |= ((code >> bit) & 1) << (7 - (position & 7));
      position++;
    }
  }
  ByteData.sublistView(fixture.header).setUint32(116, 2);
  return MobiBenchmarkCase({
    'id': 'huff-$width-bit',
    'compression': 17480,
    'header': base64Encode(fixture.header),
    'dictionary': {'1': base64Encode(huff), '2': base64Encode(cdic)},
    'records': [base64Encode(encoded)],
    // Sub-byte codes also decode the zero padding, as the Dart decoder does.
    'expected': [
      base64Encode(
        Uint8List.fromList([
          ...expected,
          for (var i = 0; i < (encoded.length * 8 - position) ~/ width; i++)
            (1 << width) - 1,
        ]),
      ),
    ],
  });
}
