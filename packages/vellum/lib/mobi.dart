/// MOBI 6 and KF8 (AZW3) on the vellum core: the Palm database, headers,
/// indexes, both book kinds as `TextBookSource`s and import metadata.
/// Production text-record I/O and decompression use Vellum's internal Rust backend;
/// the Dart decoders remain exported for reference and parity checks.
library;

export 'vellum.dart';
export 'src/formats/mobi/kf8_book.dart';
export 'src/formats/mobi/mobi6_book.dart';
export 'src/formats/mobi/mobi_book.dart';
export 'src/formats/mobi/mobi_book_metadata.dart';
export 'src/formats/mobi/mobi_compression.dart';
export 'src/formats/mobi/mobi_container.dart';
export 'src/formats/mobi/mobi_headers.dart';
export 'src/formats/mobi/mobi_index.dart';
export 'src/formats/mobi/mobi_text_source.dart';
export 'src/formats/mobi/pdb.dart';
