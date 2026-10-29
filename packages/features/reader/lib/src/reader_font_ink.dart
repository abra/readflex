import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart' show FlutterError, SynchronousFuture;
import 'package:flutter/services.dart';
import 'package:vellum/vellum.dart';

/// How far a line of text inks in each of the reader's fonts, read once
/// from their files: what WebKit's line boxes held in the iOS WebView reader
/// (`BookStyle.glyphLineBoxes`).
/// A font that cannot be read is left out; its lines keep their CSS
/// height.
///
/// The map, not the first read's future, is kept: a completed future
/// still delivers through the zone it was created in, which a widget
/// test that has ended no longer runs.
Future<Map<String, FontInk>> readerFontInk() {
  final ink = _ink;
  if (ink != null) return SynchronousFuture(ink);
  return _reading ??= _read().then((ink) {
    _reading = null;
    return _ink = ink;
  });
}

Map<String, FontInk>? _ink;
Future<Map<String, FontInk>>? _reading;

Future<Map<String, FontInk>> _read() async {
  final out = <String, FontInk>{};
  for (final preset in ReaderFontPreset.values) {
    try {
      final data = await rootBundle.load(
        'packages/component_library/fonts/${preset.fontFile}',
      );
      final ink = fontInkOf(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      if (ink != null) out[preset.fontFamily] = ink;
    } on FlutterError {
      // Not in this bundle.
    }
  }
  return Map.unmodifiable(out);
}
