import 'dart:io';

import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    final crate = Directory.fromUri(input.packageRoot.resolve('rust/'));
    final compiler = await Process.run('rustup', [
      'which',
      'rustc',
    ], workingDirectory: crate.path);
    if (compiler.exitCode != 0) {
      throw StateError(
        'Cannot resolve the pinned Rust compiler: ${compiler.stderr}',
      );
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoBuildArgs: ['--locked'],
      // Homebrew rustc can precede rustup proxies in PATH on macOS.
      extraCargoEnvironmentVariables: {
        'RUSTC': (compiler.stdout as String).trim(),
      },
    ).run(input: input, output: output);
  });
}
