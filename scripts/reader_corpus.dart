import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/tool_support.dart';

const readerCorpusLimits = {
  'epub': 12,
  'mobi': 8,
  'azw3': 4,
  'fb2': 4,
  'fb2.zip': 4,
  'cbz': 4,
};

final _formatPattern = RegExp(
  r'\.(fb2\.zip|epub|mobi|azw3|fb2|cbz|cbr|pdf|djvu)$',
);

class ReaderCorpusFile {
  const ReaderCorpusFile({required this.path, required this.bytes});

  final String path;
  final int bytes;
}

class ReaderCorpusSelection {
  const ReaderCorpusSelection({
    required this.available,
    required this.files,
  });

  final Map<String, int> available;
  final List<Map<String, Object?>> files;

  Map<String, int> get selected {
    final counts = <String, int>{};
    for (final file in files) {
      final format = file['format']! as String;
      counts.update(format, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}

/// Selects the same size-quantile workloads as the reader benchmark.
///
/// Equal-sized paths use code-unit ordering, independent of host locale.
/// Hidden entries, device System directories and symbolic links are skipped.
Future<ReaderCorpusSelection> selectReaderCorpus(
  Directory source, {
  Map<String, int> limits = readerCorpusLimits,
}) async {
  for (final entry in limits.entries) {
    if (entry.value < 1) {
      throw ArgumentError.value(entry.value, entry.key, 'must be positive');
    }
  }
  final formats = <String, List<ReaderCorpusFile>>{};

  Future<void> scan(Directory directory) async {
    final entries = await directory.list(followLinks: false).toList();
    entries.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    for (final entry in entries) {
      final name = p.basename(entry.path);
      if (name == 'System' || name.startsWith('.')) continue;
      if (entry is Directory) {
        await scan(entry);
      } else if (entry is File) {
        final format = _formatPattern.firstMatch(name.toLowerCase())?.group(1);
        if (format == null) continue;
        formats
            .putIfAbsent(format, () => [])
            .add(
              ReaderCorpusFile(
                path: p.normalize(p.absolute(entry.path)),
                bytes: await entry.length(),
              ),
            );
      }
    }
  }

  await scan(Directory(p.normalize(p.absolute(source.path))));
  final selection = <Map<String, Object?>>[];
  for (final MapEntry(key: format, value: limit) in limits.entries) {
    final candidates = [...?formats[format]]
      ..sort((a, b) {
        final size = a.bytes.compareTo(b.bytes);
        return size == 0 ? a.path.compareTo(b.path) : size;
      });
    // Preserve one representative of each size before choosing quantiles.
    final bySize = <int, ReaderCorpusFile>{
      for (final candidate in candidates) candidate.bytes: candidate,
    };
    final uniqueSizes = bySize.values.toList();
    final count = limit < uniqueSizes.length ? limit : uniqueSizes.length;
    final indexes = [
      for (var index = 0; index < count; index++)
        count == 1
            ? 0
            : (index * (uniqueSizes.length - 1) / (count - 1)).round(),
    ];
    final hashes = <String>{};
    var accepted = 0;
    for (final index in [...indexes, ...uniqueSizes.asMap().keys]) {
      if (accepted == count) break;
      final item = uniqueSizes[index];
      final hash = await hashFile(item.path);
      if (!hashes.add(hash)) continue;
      accepted++;
      selection.add({
        'path': item.path,
        'bytes': item.bytes,
        'format': format,
        'sha256': hash,
        'id':
            '${format.replaceFirst('.', '-')}-'
            '${accepted.toString().padLeft(2, '0')}',
      });
    }
  }
  return ReaderCorpusSelection(
    available: {
      for (final entry in formats.entries) entry.key: entry.value.length,
    },
    files: selection,
  );
}

Future<void> main(List<String> arguments) async {
  try {
    if (arguments.length != 2) {
      throw ArgumentError(
        'Use dart scripts/reader_corpus.dart '
        '<book directory> <selection.json>',
      );
    }
    final selection = await selectReaderCorpus(Directory(arguments[0]));
    final output = File(p.normalize(p.absolute(arguments[1])));
    await output.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await output.writeAsString(encoder.convert(selection.files));
    stdout.writeln(
      encoder.convert({
        'available': selection.available,
        'selected': selection.selected,
        'output': output.path,
      }),
    );
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  }
}
