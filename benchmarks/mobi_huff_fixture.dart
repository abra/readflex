import 'dart:convert';
import 'dart:typed_data';

/// Deterministic HUFF/CDIC data; this is a format fixture, not a real book.
/// Covers direct prefixes, table-2 lookup, two CDIC records and lazy phrases.
class MobiHuffFixture {
  MobiHuffFixture() {
    header = Uint8List(280);
    final fields = ByteData.sublistView(header);
    header.setRange(16, 20, ascii.encode('MOBI'));
    fields
      ..setUint16(0, 17480)
      ..setUint32(20, 264)
      ..setUint32(28, 65001)
      ..setUint32(36, 6)
      ..setUint32(112, 1)
      ..setUint32(116, 3);

    final huff = Uint8List(24 + 256 * 4 + 32 * 8);
    huff.setRange(0, 4, ascii.encode('HUFF'));
    final table = ByteData.sublistView(huff);
    table
      ..setUint32(4, 24)
      ..setUint32(8, 24)
      ..setUint32(12, 24 + 256 * 4);
    for (var i = 0; i < 256; i++) {
      table.setUint32(24 + i * 4, i < 128 ? (255 << 8) | 0x80 | 8 : 7);
    }
    final ranges = 24 + 256 * 4;
    table
      ..setUint32(ranges + 6 * 8, 128)
      ..setUint32(ranges + 7 * 8 + 4, 255);

    final entries = List.generate(256, (index) {
      final code = 255 - index;
      if (code < 128) return (decoded: true, bytes: Uint8List.fromList([code]));
      if (code == 128) {
        return (decoded: false, bytes: Uint8List.fromList([129, 130]));
      }
      final text = 'Chapter $code: words in a book. '
          .padRight(32)
          .substring(0, 32);
      return (decoded: false, bytes: Uint8List.fromList(ascii.encode(text)));
    });
    dictionary = {
      1: huff,
      2: _cdic(entries.sublist(0, 128)),
      3: _cdic(entries.sublist(128)),
    };
    record = Uint8List.fromList(List.generate(128, (i) => 129 + i % 127));
    expected = Uint8List.fromList([
      for (final code in record) ...entries[255 - code].bytes,
    ]);
  }

  late final Uint8List header;
  late final Map<int, Uint8List> dictionary;
  late final Uint8List record;
  late final Uint8List expected;

  Map<String, Object?> datasetCase(int records) => {
    'id': 'huff-phrases-${records * 4}k',
    'source': 'synthetic HUFF/CDIC phrases; no real book',
    'compression': 17480,
    'header': base64Encode(header),
    'dictionary': {
      for (final e in dictionary.entries) '${e.key}': base64Encode(e.value),
    },
    'records': List.filled(records, base64Encode(record)),
    'expected': List.filled(records, base64Encode(expected)),
  };

  static Uint8List _cdic(List<({bool decoded, Uint8List bytes})> entries) {
    final output = BytesBuilder();
    final offsets = Uint8List(entries.length * 2);
    final view = ByteData.sublistView(offsets);
    for (final (index, entry) in entries.indexed) {
      view.setUint16(index * 2, offsets.length + output.length);
      final length = ByteData(2)
        ..setUint16(0, entry.bytes.length | (entry.decoded ? 0x8000 : 0));
      output
        ..add(length.buffer.asUint8List())
        ..add(entry.bytes);
    }
    final header = ByteData(16)
      ..setUint32(0, 0x43444943)
      ..setUint32(4, 16)
      ..setUint32(8, 256)
      ..setUint32(12, 7);
    return (BytesBuilder()
          ..add(header.buffer.asUint8List())
          ..add(offsets)
          ..add(output.takeBytes()))
        .takeBytes();
  }
}
