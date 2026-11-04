@Tags(['tooling'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../../scripts/apk_size.dart';

void main() {
  late Directory temporary;
  late File apk;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('apk size with spaces-');
    apk = File(p.join(temporary.path, 'release app.apk'));
  });
  tearDown(() => temporary.delete(recursive: true));

  Future<void> writeApk({
    List<String> abis = const ['arm64-v8a'],
    String? extraPluginAbi,
  }) async {
    final archive = Archive()
      ..addFile(ArchiveFile.string('AndroidManifest.xml', '<manifest/>'))
      ..addFile(ArchiveFile('classes.dex', 1000, List.filled(1000, 42)))
      ..addFile(
        ArchiveFile(
          'assets/flutter_assets/fonts/Reader.ttf',
          2000,
          List.filled(2000, 7),
        ),
      );
    for (final abi in abis) {
      archive.addFile(ArchiveFile.directory('lib/$abi/'));
      for (final library in [
        'libapp.so',
        'libflutter.so',
        'libpdfium.so',
        'libpagecraft_mobi_native.so',
      ]) {
        archive.addFile(
          ArchiveFile('lib/$abi/$library', 300, List.filled(300, 17))
            ..compression = CompressionType.none,
        );
      }
    }
    if (extraPluginAbi != null) {
      archive.addFile(
        ArchiveFile(
          'lib/$extraPluginAbi/libtranslate_jni.so',
          400,
          List.filled(400, 29),
        )..compression = CompressionType.none,
      );
    }
    await apk.writeAsBytes(ZipEncoder().encode(archive));
  }

  test(
    'accounts for archive bytes and preserves compressed font sizes',
    () async {
      await writeApk();
      final before = await apk.readAsBytes();
      final report = await inspectApk(apk, expectedAbi: 'arm64-v8a');

      expect(report.apkBytes, before.length);
      expect(report.abis, ['arm64-v8a']);
      expect(report.libraries.map((entry) => p.basename(entry.path)), [
        'libapp.so',
        'libflutter.so',
        'libpagecraft_mobi_native.so',
        'libpdfium.so',
      ]);
      expect(
        report.libraries.every((entry) => entry.compressedBytes == 300),
        isTrue,
      );
      expect(report.fonts.single.uncompressedBytes, 2000);
      expect(report.fonts.single.compressedBytes, lessThan(2000));
      expect(report.compressedEntryBytes, lessThan(report.apkBytes));
      expect(report.uncompressedEntryBytes, 11 + 1000 + 2000 + 4 * 300);
      expect(
        report.groups.fold<int>(
          0,
          (sum, group) => sum + (group['compressedBytes']! as int),
        ),
        report.compressedEntryBytes,
      );
      expect(await apk.readAsBytes(), before);
      expect(
        (await temporary.list().toList()).map((file) => p.basename(file.path)),
        ['release app.apk'],
      );
    },
  );

  test(
    'rejects plugin-only extra ABI even when Flutter itself is arm64',
    () async {
      await writeApk(extraPluginAbi: 'x86_64');
      final report = await inspectApk(apk);
      expect(report.abis, ['arm64-v8a', 'x86_64']);
      expect(
        report.libraries.where((entry) => entry.abi == 'x86_64').single.path,
        'lib/x86_64/libtranslate_jni.so',
      );
      await expectLater(
        inspectApk(apk, expectedAbi: 'arm64-v8a'),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'ABI mismatch',
            contains('x86_64'),
          ),
        ),
      );
    },
  );

  test(
    'can inventory a universal APK without requiring a single ABI',
    () async {
      await writeApk(abis: ['x86_64', 'arm64-v8a', 'armeabi-v7a']);
      final report = await inspectApk(apk);
      expect(report.abis, ['arm64-v8a', 'armeabi-v7a', 'x86_64']);
      expect(report.libraries, hasLength(12));
    },
  );

  test(
    'rejects non-ZIP, truncated ZIP and ZIP without an APK manifest',
    () async {
      await apk.writeAsString('not an APK');
      await expectLater(inspectApk(apk), throwsFormatException);
      await writeApk();
      final bytes = await apk.readAsBytes();
      await apk.writeAsBytes(bytes.sublist(0, bytes.length - 8));
      await expectLater(inspectApk(apk), throwsFormatException);
      await apk.writeAsBytes(ZipEncoder().encode(Archive()));
      await expectLater(inspectApk(apk), throwsFormatException);
    },
  );

  test(
    'CLI reports missing files and rejects unknown or incomplete arguments',
    () async {
      for (final args in [
        <String>[],
        ['app.apk', '--unknown'],
        ['app.apk', '--output'],
        ['app.apk', '--expect-abi', '--output', 'report.json'],
        ['one.apk', 'two.apk'],
      ]) {
        final error = StringBuffer();
        expect(await runApkSize(args, errorOutput: error), 64);
        expect(error.toString(), contains('Usage:'));
      }
      final error = StringBuffer();
      expect(await runApkSize([apk.path], errorOutput: error), 1);
      expect(error.toString(), contains('release app.apk'));
      final help = StringBuffer();
      expect(await runApkSize(['--help'], output: help), 0);
      expect(help.toString(), contains('--expect-abi'));
    },
  );

  test('CLI saves JSON only after the expected ABI passes', () async {
    final reportFile = File(p.join(temporary.path, 'reports', 'size.json'));
    await writeApk(extraPluginAbi: 'x86_64');
    expect(
      await runApkSize([
        apk.path,
        '--output',
        reportFile.path,
        '--expect-abi',
        'arm64-v8a',
      ], errorOutput: StringBuffer()),
      1,
    );
    expect(await reportFile.exists(), isFalse);

    await writeApk();
    final output = StringBuffer();
    expect(
      await runApkSize([
        apk.path,
        '--output',
        reportFile.path,
        '--expect-abi',
        'arm64-v8a',
      ], output: output),
      0,
    );
    final json =
        jsonDecode(await reportFile.readAsString()) as Map<String, Object?>;
    expect(json['apkBytes'], await apk.length());
    expect(json['abis'], ['arm64-v8a']);
    expect(json['libraries'], hasLength(4));
    expect(json['fonts'], hasLength(1));
    expect(output.toString(), contains('Native ABIs: arm64-v8a'));
  });

  test('CLI refuses to overwrite its APK with the JSON report', () async {
    await writeApk();
    final original = await apk.readAsBytes();
    final error = StringBuffer();
    expect(
      await runApkSize([apk.path, '--output', apk.path], errorOutput: error),
      1,
    );
    expect(error.toString(), contains('must not overwrite'));
    expect(await apk.readAsBytes(), original);
  });
}
