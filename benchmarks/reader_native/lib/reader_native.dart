import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

import 'src/rust/api.dart';
import 'src/rust/frb_generated.dart';

export 'src/rust/api.dart';
export 'src/rust/archive.dart';
export 'src/rust/file.dart';
export 'src/rust/markup.dart';

Future<void>? _initialization;

/// One bridge per Dart isolate; native libraries are shared by the process.
Future<void> ensureReaderNative({String? libraryPath}) =>
    _initialization ??= _initialize(libraryPath);

Future<void> _initialize(String? libraryPath) async {
  final path = libraryPath ?? Platform.environment['READER_BENCHMARK_LIBRARY'];
  if (path == null) throw StateError('READER_BENCHMARK_LIBRARY is required');
  await ReaderRustLib.init(externalLibrary: ExternalLibrary.open(path));
  if (!isReleaseBuild()) throw StateError('Use a release Rust library');
}
