/// Where an EPUB's files come from: the `loadText`/`loadBlob`/`getSize`
/// trio `epub.js` takes, as one contract over the ZIP container or, in
/// tests, over memory.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../container/zip_archive.dart';

/// Read access to the files of a container by path.
abstract interface class EpubFiles {
  /// The text of [path] as UTF-8 (a byte order mark dropped), or null
  /// when the container has no such file.
  Future<String?> readText(String path);

  /// The bytes of [path], or null when missing.
  Future<Uint8List?> readBytes(String path);

  /// The uncompressed size of [path], or null when missing.
  int? sizeOf(String path);

  Future<void> close();
}

/// [EpubFiles] over a ZIP container on disk.
class ZipEpubFiles implements EpubFiles {
  ZipEpubFiles(this.archive);

  static Future<ZipEpubFiles> open(String path) async =>
      ZipEpubFiles(await ZipArchive.open(path));

  final ZipArchive archive;

  @override
  Future<String?> readText(String path) async {
    final bytes = await readBytes(path);
    return bytes == null ? null : decodeEpubText(bytes);
  }

  @override
  Future<Uint8List?> readBytes(String path) {
    final entry = archive.entry(path);
    if (entry == null) return Future.value(null);
    return archive.read(entry);
  }

  @override
  int? sizeOf(String path) => archive.entry(path)?.uncompressedSize;

  @override
  Future<void> close() => archive.close();
}

/// [EpubFiles] over an in-memory map, for tests and fixtures.
class MemoryEpubFiles implements EpubFiles {
  MemoryEpubFiles(Map<String, List<int>> files)
    : _files = {
        for (final entry in files.entries)
          entry.key: Uint8List.fromList(entry.value),
      };

  /// Text files, encoded as UTF-8.
  MemoryEpubFiles.text(Map<String, String> files)
    : this({
        for (final entry in files.entries) entry.key: utf8.encode(entry.value),
      });

  final Map<String, Uint8List> _files;

  @override
  Future<String?> readText(String path) async {
    final bytes = _files[path];
    return bytes == null ? null : decodeEpubText(bytes);
  }

  @override
  Future<Uint8List?> readBytes(String path) async {
    final bytes = _files[path];
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  @override
  int? sizeOf(String path) => _files[path]?.length;

  @override
  Future<void> close() async {}
}

/// UTF-8 text with a byte order mark dropped; malformed bytes become
/// U+FFFD rather than failing the whole file.
String decodeEpubText(Uint8List bytes) {
  final hasBom =
      bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF;
  return utf8.decode(
    hasBom ? Uint8List.sublistView(bytes, 3) : bytes,
    allowMalformed: true,
  );
}
