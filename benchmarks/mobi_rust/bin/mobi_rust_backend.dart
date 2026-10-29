import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:mobi_rust_benchmark/src/rust/api.dart';
import 'package:mobi_rust_benchmark/src/rust/frb_generated.dart';
import 'package:vellum/src/formats/mobi/mobi_headers.dart';

import '../../mobi_decoder_benchmark.dart';

/// Explicit loading keeps the experiment outside the application's build graph.
Future<void> initializeMobiRustBenchmark() async {
  final path = Platform.environment['MOBI_RUST_LIBRARY'];
  if (path == null || path.isEmpty) {
    throw StateError(
      'Set MOBI_RUST_LIBRARY to the release library built by make build-mobi-rust',
    );
  }
  await MobiRustLib.init(
    externalLibrary: ExternalLibrary.open(File(path).absolute.path),
  );
  if (!isReleaseBuild()) {
    MobiRustLib.dispose();
    throw StateError('The MOBI benchmark requires a release Rust library');
  }
}

void disposeMobiRustBenchmark() => MobiRustLib.dispose();

class RustMobiBenchmarkBackend implements MobiBenchmarkBackend {
  @override
  String get name => 'rust-frb';

  @override
  Future<MobiBenchmarkSession> open(MobiBenchmarkCase input) async {
    final dictionary = <Uint8List>[];
    if (input.compression == 17480) {
      final header = MobiHeaders.read(input.header!).mobi;
      for (var i = 0; i < header.numHuffcdic; i++) {
        final record = input.dictionary[header.huffcdic + i];
        if (record == null) {
          throw const FormatException('Missing HUFF/CDIC record');
        }
        dictionary.add(record);
      }
    }
    return _RustSession(
      await MobiDecoder.newInstance(
        compression: input.compression,
        dictionaryRecords: dictionary,
      ),
    );
  }
}

class _RustSession implements MobiBenchmarkSession {
  _RustSession(this._decoder);

  final MobiDecoder _decoder;
  bool _closed = false;

  @override
  Future<List<Uint8List>> decodeBatch(List<Uint8List> records) {
    if (_closed) throw StateError('MOBI decoder session is closed');
    return _decoder.decodeBatch(records: records);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _decoder.dispose();
  }
}
