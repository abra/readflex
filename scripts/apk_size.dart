import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

const _usage = '''Usage: dart scripts/apk_size.dart <apk> [options]

  --expect-abi <abi>   Fail unless the APK contains only this native ABI.
  --output <json>      Write the size report as JSON.
  --help              Show this help.

Reads ZIP metadata without extracting files. Sizes describe the APK archive,
not its Play Store download size, installed size, or downloaded language models.
''';

final _nativeLibrary = RegExp(r'^lib/([^/]+)/([^/]+\.so)$');
final _fontExtension = RegExp(r'\.(ttf|otf|woff2?)$', caseSensitive: false);

class ApkEntrySize {
  const ApkEntrySize({
    required this.path,
    required this.compressedBytes,
    required this.uncompressedBytes,
  });

  final String path;
  final int compressedBytes;
  final int uncompressedBytes;

  String? get abi => _nativeLibrary.firstMatch(path)?.group(1);

  Map<String, Object> toJson() => {
    'path': path,
    if (abi case final String abi) 'abi': abi,
    'compressedBytes': compressedBytes,
    'uncompressedBytes': uncompressedBytes,
  };
}

class ApkSizeReport {
  ApkSizeReport({
    required this.apkPath,
    required this.apkBytes,
    required Iterable<ApkEntrySize> entries,
  }) : entries = List.unmodifiable(entries);

  final String apkPath;
  final int apkBytes;
  final List<ApkEntrySize> entries;

  List<String> get abis =>
      entries.map((entry) => entry.abi).nonNulls.toSet().toList()..sort();

  List<ApkEntrySize> get libraries => _largestFirst(
    entries.where((entry) => entry.abi != null),
  );

  List<ApkEntrySize> get fonts => _largestFirst(
    entries.where((entry) => _fontExtension.hasMatch(entry.path)),
  );

  int get compressedEntryBytes =>
      entries.fold(0, (sum, entry) => sum + entry.compressedBytes);

  int get uncompressedEntryBytes =>
      entries.fold(0, (sum, entry) => sum + entry.uncompressedBytes);

  List<Map<String, Object>> get groups {
    final grouped = <String, List<ApkEntrySize>>{};
    for (final entry in entries) {
      final group = switch (entry) {
        ApkEntrySize(abi: final String abi) => 'lib/$abi',
        _ when _fontExtension.hasMatch(entry.path) => 'fonts',
        _ when entry.path.endsWith('.dex') => 'dex',
        _ when entry.path.startsWith('assets/') => 'assets',
        _
            when entry.path.startsWith('res/') ||
                entry.path == 'resources.arsc' =>
          'android resources',
        _ => 'other',
      };
      grouped.putIfAbsent(group, () => []).add(entry);
    }
    final totals = [
      for (final MapEntry(key: name, value: files) in grouped.entries)
        <String, Object>{
          'name': name,
          'entries': files.length,
          'compressedBytes': files.fold<int>(
            0,
            (sum, entry) => sum + entry.compressedBytes,
          ),
          'uncompressedBytes': files.fold<int>(
            0,
            (sum, entry) => sum + entry.uncompressedBytes,
          ),
        },
    ];
    totals.sort((a, b) {
      final size = (b['compressedBytes']! as int).compareTo(
        a['compressedBytes']! as int,
      );
      return size == 0
          ? (a['name']! as String).compareTo(b['name']! as String)
          : size;
    });
    return totals;
  }

  Map<String, Object> toJson() => {
    'apk': apkPath,
    'apkBytes': apkBytes,
    'compressedEntryBytes': compressedEntryBytes,
    'uncompressedEntryBytes': uncompressedEntryBytes,
    'archiveOverheadBytes': apkBytes - compressedEntryBytes,
    'abis': abis,
    'groups': groups,
    'libraries': libraries.map((entry) => entry.toJson()).toList(),
    'fonts': fonts.map((entry) => entry.toJson()).toList(),
  };
}

List<ApkEntrySize> _largestFirst(Iterable<ApkEntrySize> entries) =>
    entries.toList()..sort((a, b) {
      final size = b.compressedBytes.compareTo(a.compressedBytes);
      return size == 0 ? a.path.compareTo(b.path) : size;
    });

/// Inventories ZIP entries without loading their uncompressed contents.
Future<ApkSizeReport> inspectApk(File apk, {String? expectedAbi}) async {
  final apkBytes = await apk.length();
  final input = InputFileStream(apk.path);
  try {
    final directory = ZipDirectory()..read(input);
    if (directory.filePosition < 0 ||
        directory.numberOfThisDisk != 0 ||
        directory.diskWithTheStartOfTheCentralDirectory != 0 ||
        directory.fileHeaders.length !=
            directory.totalCentralDirectoryEntries ||
        directory.totalCentralDirectoryEntriesOnThisDisk !=
            directory.totalCentralDirectoryEntries ||
        directory.centralDirectoryOffset + directory.centralDirectorySize >
            directory.filePosition) {
      throw const FormatException('Invalid or incomplete APK ZIP directory');
    }
    final paths = <String>{};
    final entries = <ApkEntrySize>[];
    for (final header in directory.fileHeaders) {
      if (!paths.add(header.filename)) {
        throw FormatException('Duplicate APK entry: ${header.filename}');
      }
      if (header.filename.endsWith('/')) continue;
      entries.add(
        ApkEntrySize(
          path: header.filename,
          compressedBytes: header.compressedSize,
          uncompressedBytes: header.uncompressedSize,
        ),
      );
    }
    if (!paths.contains('AndroidManifest.xml')) {
      throw const FormatException('Not an APK: AndroidManifest.xml is missing');
    }
    final report = ApkSizeReport(
      apkPath: p.normalize(apk.absolute.path),
      apkBytes: apkBytes,
      entries: entries,
    );
    if (report.compressedEntryBytes > apkBytes) {
      throw const FormatException('APK entry sizes exceed the archive size');
    }
    if (expectedAbi != null &&
        (report.abis.length != 1 || report.abis.single != expectedAbi)) {
      throw FormatException(
        'Expected only ABI $expectedAbi; found: ${report.abis.join(', ')}',
      );
    }
    return report;
  } on ArchiveException catch (error) {
    throw FormatException('Invalid APK ZIP: $error');
  } on RangeError {
    throw const FormatException('Invalid or truncated APK ZIP');
  } finally {
    await input.close();
  }
}

class _Options {
  const _Options(this.apk, this.output, this.expectedAbi);

  final String apk;
  final String? output;
  final String? expectedAbi;

  factory _Options.parse(List<String> arguments) {
    String? apk;
    String? output;
    String? expectedAbi;
    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument == '--output' || argument == '--expect-abi') {
        if (++i == arguments.length || arguments[i].startsWith('--')) {
          throw FormatException('Missing value for $argument');
        }
        if (argument == '--output' && output == null) {
          output = arguments[i];
        } else if (argument == '--expect-abi' && expectedAbi == null) {
          expectedAbi = arguments[i];
        } else {
          throw FormatException('Repeated option: $argument');
        }
      } else if (argument.startsWith('-')) {
        throw FormatException('Unknown option: $argument');
      } else if (apk == null) {
        apk = argument;
      } else {
        throw FormatException('Unexpected argument: $argument');
      }
    }
    if (apk == null) throw const FormatException('Missing APK path');
    return _Options(apk, output, expectedAbi);
  }
}

Future<int> runApkSize(
  List<String> arguments, {
  StringSink? output,
  StringSink? errorOutput,
}) async {
  final out = output ?? stdout;
  final err = errorOutput ?? stderr;
  if (arguments.length == 1 && arguments.single == '--help') {
    out.write(_usage);
    return 0;
  }
  late _Options options;
  try {
    options = _Options.parse(arguments);
  } on FormatException catch (error) {
    err.writeln(error.message);
    err.write(_usage);
    return 64;
  }
  try {
    final apk = File(options.apk);
    final report = await inspectApk(apk, expectedAbi: options.expectedAbi);
    if (options.output case final String path) {
      final destination = File(path);
      final inputPath = await apk.resolveSymbolicLinks();
      final outputPath = await destination.exists()
          ? await destination.resolveSymbolicLinks()
          : p.normalize(destination.absolute.path);
      if (p.equals(inputPath, outputPath)) {
        throw const FormatException('The report must not overwrite the APK');
      }
      await destination.parent.create(recursive: true);
      await destination.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(report.toJson())}\n',
      );
    }
    out.writeln('APK: ${report.apkPath}');
    out.writeln(
      'Size: ${(report.apkBytes / 1000000).toStringAsFixed(2)} MB '
      '(${report.apkBytes} bytes)',
    );
    out.writeln('Native ABIs: ${report.abis.join(', ')}');
    out.writeln('Archive groups: compressed MB / uncompressed MB');
    for (final group in report.groups) {
      final compressed = (group['compressedBytes']! as int) / 1000000;
      final uncompressed = (group['uncompressedBytes']! as int) / 1000000;
      out.writeln(
        '  ${group['name']}: ${compressed.toStringAsFixed(2)} / '
        '${uncompressed.toStringAsFixed(2)}',
      );
    }
    return 0;
  } on FileSystemException catch (error) {
    err.writeln(error);
  } on FormatException catch (error) {
    err.writeln(error.message);
  }
  return 1;
}

Future<void> main(List<String> arguments) async {
  exitCode = await runApkSize(arguments);
}
