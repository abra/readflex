import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:vellum/src/formats/mobi/mobi_container.dart';
import 'package:vellum/src/formats/mobi/pdb.dart';

/// Validates the runtime backend against Dart without timing preparation/hash work.
Future<void> main(List<String> args) async {
  if (args.length != 2) {
    throw ArgumentError('Expected inventory.json and report.json');
  }
  final inventory = jsonDecode(await File(args[0]).readAsString()) as Map;
  final hashes = <String>{};
  final results = <Map<String, Object>>[];
  var duplicates = 0;
  for (final item in [
    ...(inventory['mobi'] as List? ?? []),
    ...(inventory['azw3'] as List? ?? []),
  ]) {
    final path = (item as Map)['path'] as String;
    final hash = (await sha256.bind(File(path).openRead()).first).toString();
    if (!hashes.add(hash)) {
      duplicates++;
      continue;
    }
    MobiContainer? dart;
    MobiContainer? native;
    try {
      dart = await open(path, useDart: true);
      native = await open(path, useDart: false);
      final count = dart.headers.palmdoc.numTextRecords;
      var outputBytes = 0;
      for (var index = 0; index < count; index++) {
        final expected = await dart.loadText(index);
        final actual = await native.loadText(index);
        verify(expected, actual, '$path record $index');
        outputBytes += actual.length;
      }
      verify(
        await dart.loadAllText(),
        await native.loadAllText(),
        '$path stream',
      );
      if (count > 0) {
        for (final index in [count - 1, 0, count ~/ 2]) {
          verify(
            await dart.loadText(index),
            await native.loadText(index),
            '$path seek $index',
          );
        }
      }
      results.add({
        'path': path,
        'sha256': hash,
        'status': 'passed',
        'version': dart.headers.mobi.version,
        'compression': dart.headers.palmdoc.compression,
        'records': count,
        'textBytes': outputBytes,
      });
      stdout.writeln(
        'Verified ${results.length}: $count records, ${dart.isKf8 ? 'KF8' : 'MOBI'}',
      );
    } catch (error) {
      if (dart == null) {
        try {
          native = await open(path, useDart: false);
        } catch (nativeError) {
          results.add({
            'path': path,
            'sha256': hash,
            'status': 'rejected-by-both',
            'dartError': '$error',
            'nativeError': '$nativeError',
          });
          continue;
        }
      }
      results.add({
        'path': path,
        'sha256': hash,
        'status': 'failed',
        'error': '$error',
      });
      stderr.writeln('Validation failed: $path: $error');
    } finally {
      await native?.close();
      await dart?.close();
    }
  }
  final failures = results.where((item) => item['status'] == 'failed').length;
  final rejected = results
      .where((item) => item['status'] == 'rejected-by-both')
      .length;
  await File(args[1]).absolute.parent.create(recursive: true);
  await File(args[1]).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'runtime': Platform.version,
      'duplicates': duplicates,
      'uniqueBooks': results.length,
      'failures': failures,
      'rejectedByBoth': rejected,
      'books': results,
    }),
  );
  stdout.writeln(
    '${results.length} unique books, $duplicates duplicates, $failures failures',
  );
  if (failures != 0) exitCode = 1;
}

Future<MobiContainer> open(String path, {required bool useDart}) async {
  final pdb = await PdbFile.open(path);
  try {
    return await MobiContainer.open(pdb, useDartTextReader: useDart);
  } catch (_) {
    await pdb.close();
    rethrow;
  }
}

void verify(Uint8List expected, Uint8List actual, String label) {
  if (expected.length != actual.length) {
    throw StateError('$label: length differs');
  }
  for (var index = 0; index < expected.length; index++) {
    if (expected[index] != actual[index]) {
      throw StateError('$label: byte $index differs');
    }
  }
}
