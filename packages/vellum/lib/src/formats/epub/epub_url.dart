/// Paths inside an EPUB container, resolved the way `epub.js` resolves
/// them: a manifest href is relative to the package document, a link in
/// a section relative to that section, and the result is a plain container
/// path (no scheme, no query, percent-escapes decoded).
library;

/// Resolves [url] against [relativeTo], a container path (`resolveURL`).
///
/// An absolute URL (with a scheme) is returned resolved as a URL. Calibre
/// percent-encodes `,` and `:` that are expected raw, so those are put
/// back first; `OEBPS:` is a known false scheme in old files.
String resolveEpubUrl(String url, String relativeTo) {
  final fixed = url
      .replaceAll(RegExp('%2c', caseSensitive: false), ',')
      .replaceAll(RegExp('%3a', caseSensitive: false), ':');
  try {
    if (relativeTo.contains(':') && !relativeTo.startsWith('OEBPS')) {
      return Uri.parse(relativeTo).resolve(fixed).toString();
    }
    // The base must be a valid URL: use one and strip it again.
    const root = 'https://invalid.invalid/';
    final resolved = Uri.parse(root + relativeTo).resolve(fixed);
    // Drop the query (`obj.search = ''`), keep the fragment as written.
    final withoutQuery = resolved.toString().replaceFirst(
      RegExp(r'\?[^#]*'),
      '',
    );
    return decodeEpubUri(withoutQuery.replaceFirst(root, ''));
  } on FormatException {
    return url;
  }
}

/// Percent-decodes [text] the way JavaScript's `decodeURI` does: every
/// escape except the reserved characters `;/?:@&=+\$,#`, which stay
/// encoded. Manifest paths are compared after this decoding, so a link
/// written `ch%2C1.html` does not find `ch,1.html` (`epub.js` parity).
String decodeEpubUri(String text) {
  if (!text.contains('%')) return text;
  final out = StringBuffer();
  final bytes = <int>[];
  void flush() {
    if (bytes.isEmpty) return;
    out.write(
      String.fromCharCodes(
        Uri.decodeComponent(
          bytes.map((b) => '%${b.toRadixString(16).padLeft(2, '0')}').join(),
        ).runes,
      ),
    );
    bytes.clear();
  }

  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == '%' && i + 2 < text.length + 0 && _isHex(text, i + 1)) {
      final byte = int.parse(text.substring(i + 1, i + 3), radix: 16);
      final char = String.fromCharCode(byte);
      if (byte < 0x80 && _reservedUri.contains(char)) {
        flush();
        out.write(text.substring(i, i + 3));
      } else {
        bytes.add(byte);
      }
      i += 3;
      continue;
    }
    flush();
    out.write(c);
    i++;
  }
  flush();
  return out.toString();
}

const _reservedUri = r';/?:@&=+$,#';

bool _isHex(String text, int at) {
  if (at + 1 >= text.length) return false;
  return int.tryParse(text.substring(at, at + 2), radix: 16) != null;
}

/// Whether [uri] points outside the container (`isExternal`): it has a
/// scheme, other than a blob URL.
bool isExternalEpubUri(String uri) => _external.hasMatch(uri);

final _external = RegExp(r'^(?!blob)\w+:', caseSensitive: false);

/// The directory part of [path], with its trailing slash (`pathDirname`).
String epubPathDirname(String path) =>
    path.substring(0, path.lastIndexOf('/') + 1);

/// The relative path from [from] to [to], like Node's `path.relative`.
String epubPathRelative(String from, String to) {
  if (from.isEmpty) return to;
  final as = from.replaceFirst(RegExp(r'/$'), '').split('/');
  final bs = to.replaceFirst(RegExp(r'/$'), '').split('/');
  final longer = as.length > bs.length ? as : bs;
  var i = 0;
  while (i < longer.length &&
      i < as.length &&
      i < bs.length &&
      as[i] == bs[i]) {
    i++;
  }
  if (i == longer.length) return '';
  return [
    for (var k = i; k < as.length; k++) '..',
    ...bs.skip(i),
  ].join('/');
}
