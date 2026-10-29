import 'dart:io';

import '../../mobi_decoder_benchmark.dart';
import 'mobi_rust_backend.dart';

Future<void> main(List<String> args) async {
  try {
    await initializeMobiRustBenchmark();
    try {
      await runMobiBenchmarkWorker(args, RustMobiBenchmarkBackend());
    } finally {
      disposeMobiRustBenchmark();
    }
  } catch (error, stack) {
    stderr.writeln('$error\n$stack');
    exitCode = 1;
  }
}
