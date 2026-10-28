/// The MOBI container (`class MOBI` in `mobi.js`): record 0's headers,
/// the KF8 part of a combined file, text record decoding and resources.
/// `MobiBook.open` turns it into a `Mobi6Book` or a `Kf8Book`.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../text/charsets.dart';
import '../../text/html_entities.dart';
import '../../vellum_exception.dart';
import 'mobi_compression.dart';
import 'mobi_headers.dart';
import 'mobi_index.dart';
import 'pdb.dart';

/// What `mobi.js` reports as `book.metadata` for MOBI and KF8.
@immutable
class MobiMetadata {
  const MobiMetadata({
    required this.identifier,
    required this.title,
    required this.authors,
    required this.publisher,
    required this.language,
    required this.published,
    required this.description,
    required this.subjects,
    required this.rights,
    required this.contributors,
  });

  final String identifier;
  final String title;
  final List<String>? authors;
  final String publisher;
  final List<String>? language;
  final String? published;
  final String description;
  final List<String>? subjects;
  final String rights;
  final List<String>? contributors;
}

/// Cover bytes; the format is whatever the resource holds (JPEG, GIF).
@immutable
class MobiCover {
  const MobiCover(this.bytes);

  final Uint8List bytes;
}

/// A MOBI file's records with their headers.
class MobiContainer {
  MobiContainer._(
    this.pdb,
    this.headers,
    this._start,
    this._resourceStart,
    this._decompress,
  );

  /// Opens [pdb]: reads record 0, switches to the KF8 part of a combined
  /// file when there is one, and sets up decompression.
  static Future<MobiContainer> open(PdbFile pdb) async {
    var headers = MobiHeaders.read(await pdb.readRecord(0));
    // Resources are counted from the first header's resource start even
    // when the KF8 part's header is used for everything else, as
    // mobi.js keeps `#resourceStart` from before the switch.
    final resourceStart = headers.mobi.resourceStart;
    var start = 0;
    if (headers.mobi.version < 8) {
      final boundary = headers.exth?.boundary;
      if (boundary != null &&
          boundary < 0xFFFFFFFF &&
          boundary < pdb.numRecords) {
        try {
          // A combined MOBI/KF8 file: prefer the KF8 part.
          headers = MobiHeaders.read(await pdb.readRecord(boundary));
          start = boundary;
        } on FormatException {
          headers = MobiHeaders.read(await pdb.readRecord(0));
        } on RangeError {
          headers = MobiHeaders.read(await pdb.readRecord(0));
        }
      }
    }
    final Uint8List Function(Uint8List) decompress;
    switch (headers.palmdoc.compression) {
      case 1:
        decompress = (bytes) => bytes;
      case 2:
        decompress = decompressPalmDoc;
      case 17480:
        final decoder = await HuffCdicDecoder.load(
          headers.mobi,
          (index) => pdb.readRecord(start + index),
        );
        decompress = decoder.decompress;
      default:
        throw const VellumException('Unknown compression type');
    }
    return MobiContainer._(pdb, headers, start, resourceStart, decompress);
  }

  final PdbFile pdb;
  final MobiHeaders headers;

  /// The record index the (KF8) part starts at: 0 for a plain file.
  final int _start;

  /// The absolute record index of resource 0.
  final int _resourceStart;
  final Uint8List Function(Uint8List) _decompress;

  bool get isKf8 => headers.mobi.version >= 8;

  String get charset => headers.mobi.charset;

  /// Decodes text bytes in the book's charset.
  String decode(Uint8List bytes) => decodeCharset(bytes, charset);

  /// Record [index] of this part.
  Future<Uint8List> loadRecord(int index) => pdb.readRecord(_start + index);

  Future<String> loadMagic(int index) => pdb.readMagic(_start + index);

  /// Text record [index], trailing entries stripped and decompressed.
  Future<Uint8List> loadText(int index) async {
    final record = await loadRecord(index + 1);
    return _decompress(
      removeTrailingEntries(record, headers.mobi.trailingFlags),
    );
  }

  /// Resource [index] (counted from the resource start): fonts are
  /// deobfuscated and inflated, video and audio lose their 12-byte
  /// header, anything else comes as stored.
  Future<Uint8List> loadResource(int index) async {
    final record = await pdb.readRecord(_resourceStart + index);
    final magic = String.fromCharCodes(
      record,
      0,
      record.length < 4 ? record.length : 4,
    );
    if (magic == 'FONT') return _font(record);
    if (magic == 'VIDE' || magic == 'AUDI') {
      return Uint8List.sublistView(
        record,
        record.length < 12 ? record.length : 12,
      );
    }
    return record;
  }

  static Uint8List _font(Uint8List record) {
    final b = MobiBytes(record);
    final flags = b.u32(8);
    final dataStart = b.u32(12);
    final keyLength = b.u32(16);
    final keyStart = b.u32(20);
    var bytes = Uint8List.fromList(b.slice(dataStart));
    if (flags & 0x2 != 0 && keyLength > 0) {
      final count = keyLength == 16 ? 1024 : 1040;
      final key = b.slice(keyStart, keyStart + keyLength);
      final length = count < bytes.length ? count : bytes.length;
      for (var i = 0; i < length; i++) {
        bytes[i] ^= key[i % key.length];
      }
    }
    if (flags & 0x1 != 0) {
      try {
        bytes = Uint8List.fromList(zlib.decode(bytes));
      } on FormatException {
        // A font that does not inflate is served as it is, as mobi.js
        // warns and goes on.
      }
    }
    return bytes;
  }

  /// The NCX tree, or null without an index.
  Future<List<MobiNcxItem>?> readNcx() {
    final index = headers.mobi.indx;
    if (index >= 0xFFFFFFFF) return Future.value(null);
    return readMobiNcx(index, loadRecord);
  }

  MobiMetadata get metadata {
    final mobi = headers.mobi;
    final exth = headers.exth;
    final exthTitle = exth?.title;
    return MobiMetadata(
      identifier: mobi.uid.toString(),
      title: unescapeHtml(
        exthTitle != null && exthTitle.isNotEmpty
            ? exthTitle
            : decode(mobi.title),
      ),
      authors: exth?.creator?.map(unescapeHtml).toList(),
      publisher: unescapeHtml(exth?.publisher),
      language:
          exth?.language ?? (mobi.language == null ? null : [mobi.language!]),
      published: exth?.date,
      description: unescapeHtml(exth?.description),
      subjects: exth?.subject?.map(unescapeHtml).toList(),
      rights: unescapeHtml(exth?.rights),
      contributors: exth?.contributor,
    );
  }

  /// The cover resource (`getCover`), or null.
  Future<MobiCover?> readCover() async {
    final exth = headers.exth;
    final coverOffset = exth?.coverOffset;
    final thumbnailOffset = exth?.thumbnailOffset;
    final offset = coverOffset != null && coverOffset < 0xFFFFFFFF
        ? coverOffset
        : thumbnailOffset != null && thumbnailOffset < 0xFFFFFFFF
        ? thumbnailOffset
        : null;
    if (offset == null) return null;
    return MobiCover(await loadResource(offset));
  }

  Future<void> close() => pdb.close();
}
